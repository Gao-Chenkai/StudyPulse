//
//  DailyPlanEngine.swift
//  StudyPulse
//
//  「今日重点」生成器。从考试 / HRV 状态 / SRS 错题 / 待办 / 例程 综合排序出
//  前 N 条 "今日 3 件最重要的事"。纯函数,无副作用。
//
//  Created for Plans & Routines spec (2026-07-09).
//

import Foundation
import SwiftUI

// MARK: - Daily Plan Context

/// 「今日计划」生成上下文。所有输入由调用方(HomeViewModel)提供,
/// engine 自身不做 IO / 不依赖环境。
struct DailyPlanContext {
    let grades: [Grade]
    let mistakeSets: [MistakeNote]
    let examSets: [Exam]
    let taskItems: [TaskItem]
    let routineInstances: [RoutineInstance]
    /// HRV 评估结果(可空)
    let hrvReadiness: HRVReadiness?
    /// 身体状态摘要(可空)
    let hrvBodyStatus: BodyStatus?
    /// 当前日期(便于测试固定时间)
    let now: Date

    init(
        grades: [Grade],
        mistakeSets: [MistakeNote],
        examSets: [Exam],
        taskItems: [TaskItem],
        routineInstances: [RoutineInstance],
        hrvReadiness: HRVReadiness?,
        hrvBodyStatus: BodyStatus?,
        now: Date = Date()
    ) {
        self.grades = grades
        self.mistakeSets = mistakeSets
        self.examSets = examSets
        self.taskItems = taskItems
        self.routineInstances = routineInstances
        self.hrvReadiness = hrvReadiness
        self.hrvBodyStatus = hrvBodyStatus
        self.now = now
    }
}

// MARK: - Daily Plan Item

/// 今日计划中的一条建议项。View 层根据 `kind` 决定图标 / 颜色 / 跳转目标。
nonisolated struct DailyPlanItem: Identifiable, Equatable, Hashable {
    let id: UUID
    let kind: Kind
    let title: String
    let reason: String
    let score: Double
    let sourceRef: SourceRef

    /// 排序/分类用
    enum Kind: Equatable, Hashable {
        case urgentExam           // 今天/明天有考试
        case srsReview            // SRS 到期错题
        case overdueTask          // 已过期未完成待办
        case todayTask            // 今日到期待办
        case routineActive        // 当前进行中的例程
        case routineUpcoming      // 即将开始的例程
        case recovery             // HRV 低/恢复建议
        case strongSubject        // 强势科建议(数据少时的兜底)
        case placeholder          // 全部为空时的占位
    }

    /// 跳转目标(给 View 层用)
    enum SourceRef: Equatable, Hashable {
        case exam(id: UUID)
        case mistake(id: UUID)
        case task(id: UUID)
        case routineInstance(id: UUID)
        case routineTemplate(id: UUID)
        case none
    }

    init(
        kind: Kind,
        title: String,
        reason: String,
        score: Double,
        sourceRef: SourceRef
    ) {
        self.id = UUID()
        self.kind = kind
        self.title = title
        self.reason = reason
        self.score = score
        self.sourceRef = sourceRef
    }

    /// View 层用的图标
    var icon: String {
        switch kind {
        case .urgentExam:      return "calendar.badge.exclamationmark"
        case .srsReview:       return "rectangle.stack.fill"
        case .overdueTask:     return "exclamationmark.circle.fill"
        case .todayTask:       return "checklist"
        case .routineActive:   return "repeat.circle.fill"
        case .routineUpcoming: return "repeat.circle"
        case .recovery:        return "leaf.fill"
        case .strongSubject:   return "hand.thumbsup.fill"
        case .placeholder:     return "sparkles"
        }
    }

    /// View 层用的颜色
    var color: Color {
        switch kind {
        case .urgentExam:      return .red
        case .srsReview:       return .purple
        case .overdueTask:     return .orange
        case .todayTask:       return .blue
        case .routineActive:   return .indigo
        case .routineUpcoming: return .indigo
        case .recovery:        return .green
        case .strongSubject:   return .mint
        case .placeholder:     return .secondary
        }
    }
}

// MARK: - DailyPlanEngine

/// 今日计划生成器。纯函数,无副作用。
enum DailyPlanEngine {

    // MARK: - Score constants

    private static let baseWeightUrgentExam: Double = 100
    private static let baseWeightSrsReview: Double = 60
    private static let baseWeightOverdueTask: Double = 80
    private static let baseWeightTodayTask: Double = 50
    private static let baseWeightRoutineActive: Double = 90
    private static let baseWeightRoutineUpcoming: Double = 40
    private static let baseWeightRecovery: Double = 70
    private static let baseWeightStrongSubject: Double = 20

    // MARK: - Generate

    /// 生成按 score 降序排序的 plan 列表,最多 `max` 条。
    static func generate(
        from context: DailyPlanContext,
        max: Int = 3
    ) -> [DailyPlanItem] {
        var candidates: [DailyPlanItem] = []

        // 1) 紧急考试(今天/明天)
        candidates.append(contentsOf: urgentExams(context: context))

        // 2) SRS 到期错题
        if let item = srsReviewItem(context: context) {
            candidates.append(item)
        }

        // 3) 待办(过期 + 今日)
        candidates.append(contentsOf: pendingTasks(context: context))

        // 4) 例程(进行中 / 即将开始)
        candidates.append(contentsOf: routineItems(context: context))

        // 5) HRV 低 → 恢复建议(加权最高)
        if let rec = recoveryItem(context: context) {
            candidates.append(rec)
        }

        // 6) 强势科(无数据时的兜底)
        if let strong = strongSubjectItem(context: context, candidatesCount: candidates.count) {
            candidates.append(strong)
        }

        // 应用 HRV 因子(低恢复时下调高分项,提升低强度项)
        let hrvFactor = currentHRVFactor(context: context)
        let adjusted = candidates.map { item -> DailyPlanItem in
            let newScore = item.score * hrvFactor
            return DailyPlanItem(
                kind: item.kind,
                title: item.title,
                reason: item.reason,
                score: newScore,
                sourceRef: item.sourceRef
            )
        }

        // 排序
        let sorted = adjusted.sorted { $0.score > $1.score }

        // 全空 → 兜底占位
        if sorted.isEmpty {
            return [DailyPlanItem(
                kind: .placeholder,
                title: "All clear".localized(),
                reason: "Pick something to study or add a routine.".localized(),
                score: 0,
                sourceRef: .none
            )]
        }

        return Array(sorted.prefix(max))
    }

    // MARK: - Helpers

    /// HRV 当前因子(影响 score 缩放)
    /// - 高恢复(>= normal)→ 1.2
    /// - normal / insufficient / loading → 1.0
    /// - low → 0.6(降低硬任务权重)
    /// - 不可用(noAuthorization/queryFailed)→ 1.0
    static func currentHRVFactor(context: DailyPlanContext) -> Double {
        guard let cat = context.hrvReadiness?.category else { return 1.0 }
        switch cat {
        case .excellent: return 1.2
        case .normal:    return 1.0
        case .insufficient: return 1.0
        case .loading:   return 1.0
        case .low:       return 0.6
        case .noAuthorization: return 1.0
        case .queryFailed: return 1.0
        }
    }

    /// 计算单条 item 的 score(供 test 验证)
    /// 公式:`baseWeight * urgencyMultiplier * hrvFactor`
    static func scoreFor(
        kind: DailyPlanItem.Kind,
        daysFromNow: Double,
        hrvFactor: Double
    ) -> Double {
        let base: Double
        switch kind {
        case .urgentExam:        base = baseWeightUrgentExam
        case .srsReview:         base = baseWeightSrsReview
        case .overdueTask:       base = baseWeightOverdueTask
        case .todayTask:         base = baseWeightTodayTask
        case .routineActive:     base = baseWeightRoutineActive
        case .routineUpcoming:   base = baseWeightRoutineUpcoming
        case .recovery:          base = baseWeightRecovery
        case .strongSubject:     base = baseWeightStrongSubject
        case .placeholder:       base = 0
        }
        let urgency: Double
        if daysFromNow <= 1 {
            urgency = 2.0
        } else if daysFromNow <= 7 {
            urgency = 1.0
        } else if daysFromNow < 0 {
            urgency = 1.5   // 已过期任务
        } else {
            urgency = 0.5
        }
        return base * urgency * hrvFactor
    }

    // MARK: - Signal extractors

    /// 紧急考试(今天/明天,最多 3 条,合并显示)
    static func urgentExams(context: DailyPlanContext) -> [DailyPlanItem] {
        let cal = Calendar.current
        let now = context.now
        let urgent = context.examSets.filter { exam in
            for offset in 0...1 {
                let day = cal.date(byAdding: .day, value: offset, to: now) ?? now
                if cal.isDate(exam.examDate, inSameDayAs: day) { return true }
            }
            return false
        }
        guard !urgent.isEmpty else { return [] }
        // 按时间最近的优先;只取前 1 条进入 plan(避免挤占 3 个名额)
        let sorted = urgent.sorted { $0.examDate < $1.examDate }
        let first = sorted[0]
        let daysAway = cal.dateComponents([.day], from: now, to: first.examDate).day ?? 0
        let dayLabel: String
        if daysAway == 0 {
            dayLabel = "Today".localized()
        } else {
            dayLabel = "Tomorrow".localized()
        }
        let subjectName = first.subject.localized()
        let title: String
        if urgent.count == 1 {
            title = String(format: "%@ %@ — %@".localized(), dayLabel, first.name, subjectName)
        } else {
            title = String(format: "%@ %d exams today/tomorrow".localized(), dayLabel, urgent.count)
        }
        let reason = String(
            format: "Review your notes now — first exam is %@".localized(),
            first.name
        )
        return [DailyPlanItem(
            kind: .urgentExam,
            title: title,
            reason: reason,
            score: scoreFor(kind: .urgentExam, daysFromNow: Double(daysAway), hrvFactor: currentHRVFactor(context: context)),
            sourceRef: .exam(id: first.id)
        )]
    }

    /// SRS 到期错题
    static func srsReviewItem(context: DailyPlanContext) -> DailyPlanItem? {
        let overview = SRSAlgorithm.overview(from: context.mistakeSets)
        guard overview.dueCount > 0 else { return nil }
        let reason: String
        if overview.dueCount == 1 {
            reason = "1 mistake due now".localized()
        } else {
            reason = String(format: "%d mistakes due now".localized(), overview.dueCount)
        }
        return DailyPlanItem(
            kind: .srsReview,
            title: "Review your mistakes".localized(),
            reason: reason,
            score: scoreFor(kind: .srsReview, daysFromNow: 0, hrvFactor: currentHRVFactor(context: context)),
            sourceRef: .none
        )
    }

    /// 待办:过期 + 今日到期(各取 1 条,合并到一张 plan)
    static func pendingTasks(context: DailyPlanContext) -> [DailyPlanItem] {
        let cal = Calendar.current
        let now = context.now
        let todayStart = cal.startOfDay(for: now)
        let todayEnd = cal.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart
        let pending = context.taskItems.filter { !$0.isCompleted }
        let overdue = pending.filter { $0.dueDate < todayStart }
        let dueToday = pending.filter { $0.dueDate >= todayStart && $0.dueDate < todayEnd }

        var items: [DailyPlanItem] = []

        if let od = overdue.sorted(by: { $0.dueDate < $1.dueDate }).first {
            let daysOver = cal.dateComponents([.day], from: od.dueDate, to: now).day ?? 0
            let reason: String
            if daysOver <= 0 {
                reason = "1 task overdue".localized()
            } else {
                reason = String(format: "Overdue by %d day(s)".localized(), daysOver)
            }
            items.append(DailyPlanItem(
                kind: .overdueTask,
                title: od.title,
                reason: reason,
                score: scoreFor(kind: .overdueTask, daysFromNow: -Double(max(0, daysOver)), hrvFactor: currentHRVFactor(context: context)),
                sourceRef: .task(id: od.id)
            ))
        }

        if let td = dueToday.sorted(by: { $0.dueDate < $1.dueDate }).first {
            items.append(DailyPlanItem(
                kind: .todayTask,
                title: td.title,
                reason: "Due today".localized(),
                score: scoreFor(kind: .todayTask, daysFromNow: 0, hrvFactor: currentHRVFactor(context: context)),
                sourceRef: .task(id: td.id)
            ))
        }

        return items
    }

    /// 例程:进行中 / 即将开始(30 分钟内)各 1 条
    static func routineItems(context: DailyPlanContext) -> [DailyPlanItem] {
        let now = context.now
        let active = context.routineInstances.filter { $0.startTime <= now && $0.endTime > now }
        let upcoming = context.routineInstances.filter {
            $0.startTime > now && $0.startTime.timeIntervalSince(now) <= 30 * 60
        }
        var items: [DailyPlanItem] = []
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        if let a = active.first {
            items.append(DailyPlanItem(
                kind: .routineActive,
                title: a.title,
                reason: String(format: "Active routine — %@ to %@".localized(), f.string(from: a.startTime), f.string(from: a.endTime)),
                score: scoreFor(kind: .routineActive, daysFromNow: 0, hrvFactor: currentHRVFactor(context: context)),
                sourceRef: .routineInstance(id: a.id)
            ))
        }
        if let u = upcoming.sorted(by: { $0.startTime < $1.startTime }).first {
            let mins = Int(u.startTime.timeIntervalSince(now) / 60)
            items.append(DailyPlanItem(
                kind: .routineUpcoming,
                title: u.title,
                reason: String(format: "Starts in %d min".localized(), max(1, mins)),
                score: scoreFor(kind: .routineUpcoming, daysFromNow: Double(mins) / (60 * 24), hrvFactor: currentHRVFactor(context: context)),
                sourceRef: .routineInstance(id: u.id)
            ))
        }
        return items
    }

    /// HRV 恢复建议(当 readiness 为 low)
    static func recoveryItem(context: DailyPlanContext) -> DailyPlanItem? {
        guard let cat = context.hrvReadiness?.category, cat == .low else { return nil }
        return DailyPlanItem(
            kind: .recovery,
            title: "Take it easy today".localized(),
            reason: "HRV is low — go for a light review or a walk.".localized(),
            score: scoreFor(kind: .recovery, daysFromNow: 0, hrvFactor: currentHRVFactor(context: context)),
            sourceRef: .none
        )
    }

    /// 强势科建议(数据 >= 2 个 subject 时;且其他候选不足 max 时)
    static func strongSubjectItem(context: DailyPlanContext, candidatesCount: Int) -> DailyPlanItem? {
        let aggregates = SubjectAggregator.aggregate(grades: context.grades, includeRecentCount: false)
        guard let strong = SuggestionEngine.findStrongSubject(aggregates: aggregates) else { return nil }
        // 仅在候选不足时添加(避免挤占关键项)
        guard candidatesCount < 2 else { return nil }
        return DailyPlanItem(
            kind: .strongSubject,
            title: String(format: "Great at %@".localized(), strong.localized()),
            reason: "Keep up the good work".localized(),
            score: scoreFor(kind: .strongSubject, daysFromNow: 7, hrvFactor: currentHRVFactor(context: context)),
            sourceRef: .none
        )
    }
}
