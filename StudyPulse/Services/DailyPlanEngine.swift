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
// MARK: - 今日计划上下文 / Daily plan context

/// 「今日计划」生成上下文。所有输入由调用方(HomeViewModel)提供,
/// engine 自身不做 IO / 不依赖环境。
/// `DailyPlan` generation context. All inputs are supplied by the caller
/// (e.g. `HomeViewModel`); the engine itself does no I/O and has no
/// environment dependencies.
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

// MARK: - Minimal completion plan

struct MinimalPlanContext {
    let mistakeSets: [MistakeNote]
    let examSets: [Exam]
    let taskItems: [TaskItem]
    let routineInstances: [RoutineInstance]
    let hrvReadiness: HRVReadiness?
    let hrvBodyStatus: BodyStatus?
    let now: Date
    let availableMinutes: Int

    init(mistakeSets: [MistakeNote], examSets: [Exam], taskItems: [TaskItem],
         routineInstances: [RoutineInstance], hrvReadiness: HRVReadiness?,
         hrvBodyStatus: BodyStatus?, now: Date = Date(), availableMinutes: Int? = nil) {
        self.mistakeSets = mistakeSets
        self.examSets = examSets
        self.taskItems = taskItems
        self.routineInstances = routineInstances
        self.hrvReadiness = hrvReadiness
        self.hrvBodyStatus = hrvBodyStatus
        self.now = now
        if let availableMinutes {
            self.availableMinutes = Swift.max(30, availableMinutes)
        } else {
            let endOfStudyDay = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: now) ?? now
            self.availableMinutes = Swift.max(30, Int(endOfStudyDay.timeIntervalSince(now) / 60))
        }
    }
}

nonisolated struct MinimalPlanItem: Identifiable, Equatable, Hashable {
    let id: UUID
    let kind: Kind
    let title: String
    let reason: String
    let estimatedMinutes: Int
    let priorityScore: Double
    let sourceRef: DailyPlanItem.SourceRef

    enum Kind: Equatable, Hashable { case exam, homework, mistake, focus }

    init(kind: Kind, title: String, reason: String, estimatedMinutes: Int,
         priorityScore: Double, sourceRef: DailyPlanItem.SourceRef) {
        self.id = UUID()
        self.kind = kind
        self.title = title
        self.reason = reason
        self.estimatedMinutes = estimatedMinutes
        self.priorityScore = priorityScore
        self.sourceRef = sourceRef
    }

    var icon: String {
        switch kind {
        case .exam: return "calendar.badge.exclamationmark"
        case .homework: return "checklist"
        case .mistake: return "rectangle.stack.fill"
        case .focus: return "timer"
        }
    }

    var color: Color {
        switch kind {
        case .exam: return .red
        case .homework: return .orange
        case .mistake: return .purple
        case .focus: return .blue
        }
    }
}

struct MinimalPlanResult: Equatable {
    let isActive: Bool
    let reason: String
    let items: [MinimalPlanItem]
    let totalMinutes: Int
}

enum MinimalCompletionPlanEngine {
    static func generate(from context: MinimalPlanContext, max: Int = 3) -> MinimalPlanResult {
        let pending = context.taskItems.filter { !$0.isCompleted }
        let calendar = Calendar.current
        let dueMistakes = context.mistakeSets.filter { $0.reviewState?.nextReviewDate ?? .distantFuture <= context.now }
        let overdue = pending.filter { $0.dueDate < calendar.startOfDay(for: context.now) }.count
        let dueSoonExams = context.examSets.filter { $0.examDate >= context.now && $0.examDate.timeIntervalSince(context.now) <= 2 * 86400 }.count
        let lowRecovery = context.hrvReadiness?.category == .low || context.hrvBodyStatus?.sleepQuality == .poor
        let estimatedDemand = pending.reduce(0) { $0 + estimatedMinutes(for: $1) } + dueMistakes.count * 10 + dueSoonExams * 25
        let insufficientTime = estimatedDemand > context.availableMinutes || (context.availableMinutes < 120 && !pending.isEmpty)
        let backlog = pending.count >= 6 || overdue >= 2
        let pressure = (lowRecovery ? 2 : 0) + (backlog ? 2 : 0) + (dueSoonExams > 0 ? 1 : 0) + (dueMistakes.count >= 8 ? 1 : 0) + (insufficientTime ? 1 : 0)
        let active = pressure >= 2 && (!pending.isEmpty || !dueMistakes.isEmpty || !context.examSets.isEmpty || !context.routineInstances.isEmpty)
        guard active else { return MinimalPlanResult(isActive: false, reason: "Your regular plan is available today.".localized(), items: [], totalMinutes: 0) }

        let reasons = [lowRecovery ? "Low recovery" : nil, backlog ? "Backlog" : nil, insufficientTime ? "Limited time" : nil, dueSoonExams > 0 ? "Exam deadline" : nil].compactMap { $0?.localized() }
        let budget = Swift.max(30, Swift.min(context.availableMinutes, lowRecovery ? 60 : 90))
        var candidates = examCandidates(context: context) + taskCandidates(context: context) + mistakeCandidates(context: context) + focusCandidates(context: context)
        candidates.sort { $0.priorityScore > $1.priorityScore }
        var selected: [MinimalPlanItem] = []
        var used = 0
        for item in candidates where selected.count < max {
            guard used + item.estimatedMinutes <= budget || selected.isEmpty else { continue }
            selected.append(item)
            used += item.estimatedMinutes
        }
        return MinimalPlanResult(isActive: true, reason: String(format: "Plan compressed: %@. Keep a small win today.".localized(), reasons.joined(separator: "Minimal plan reason separator".localized())), items: selected, totalMinutes: used)
    }

    private static func estimatedMinutes(for task: TaskItem) -> Int { task.type == .reading ? 15 : 25 }

    private static func examCandidates(context: MinimalPlanContext) -> [MinimalPlanItem] {
        context.examSets.filter { $0.examDate >= context.now && $0.examDate.timeIntervalSince(context.now) <= 7 * 86400 }.sorted { $0.examDate < $1.examDate }.prefix(1).map { exam in
            let days = max(0, Int(exam.examDate.timeIntervalSince(context.now) / 86400))
            return MinimalPlanItem(kind: .exam, title: exam.name, reason: String(format: "Exam in %d day(s); secure the essentials.".localized(), days), estimatedMinutes: 25, priorityScore: 150 - Double(days * 15) + Double(exam.importance * 8), sourceRef: .exam(id: exam.id))
        }
    }

    private static func taskCandidates(context: MinimalPlanContext) -> [MinimalPlanItem] {
        let start = Calendar.current.startOfDay(for: context.now)
        return context.taskItems.filter { !$0.isCompleted }.sorted { $0.dueDate < $1.dueDate }.prefix(2).map { task in
            let overdue = task.dueDate < start
            return MinimalPlanItem(kind: .homework, title: task.title, reason: overdue ? "Clear one overdue task first.".localized() : "Due soon — finish the smallest complete version.".localized(), estimatedMinutes: estimatedMinutes(for: task), priorityScore: (overdue ? 125.0 : 95.0) + Double(task.importance * 6), sourceRef: .task(id: task.id))
        }
    }

    private static func mistakeCandidates(context: MinimalPlanContext) -> [MinimalPlanItem] {
        context.mistakeSets.filter { $0.reviewState?.nextReviewDate ?? .distantFuture <= context.now }.sorted {
            if $0.difficulty != $1.difficulty { return $0.difficulty > $1.difficulty }
            return $0.masteryScore < $1.masteryScore
        }.prefix(1).map { mistake in
            MinimalPlanItem(kind: .mistake, title: mistake.title, reason: "Review the highest-risk mistake briefly.".localized(), estimatedMinutes: 15, priorityScore: 110 + Double(mistake.difficulty * 5) + (1 - mistake.masteryScore) * 20, sourceRef: .mistake(id: mistake.id))
        }
    }

    private static func focusCandidates(context: MinimalPlanContext) -> [MinimalPlanItem] {
        context.routineInstances.filter { !$0.isCompleted && $0.endTime > context.now }.prefix(1).map { routine in
            let minutes = Swift.max(10, Swift.min(30, Int(routine.endTime.timeIntervalSince(Swift.max(routine.startTime, context.now)) / 60)))
            return MinimalPlanItem(kind: .focus, title: routine.title, reason: "Use one short focus block, then stop.".localized(), estimatedMinutes: minutes, priorityScore: 90, sourceRef: .routineInstance(id: routine.id))
        }
    }
}

// MARK: - Daily Plan Item
// MARK: - 今日计划项 / Daily plan item

/// 今日计划中的一条建议项。View 层根据 `kind` 决定图标 / 颜色 / 跳转目标。
/// One suggested item in today's plan. The view layer picks icon /
/// color / navigation target from `kind`.
nonisolated struct DailyPlanItem: Identifiable, Equatable, Hashable {
    let id: UUID
    let kind: Kind
    let title: String
    let reason: String
    let score: Double
    let sourceRef: SourceRef

    /// 排序/分类用
    /// Sort / categorize the plan item.
    enum Kind: Equatable, Hashable {
        /// 今天/明天有考试
        /// Exam in the next 1-2 days.
        case urgentExam
        /// SRS 到期错题
        /// SRS-overdue mistakes.
        case srsReview
        /// 已过期未完成待办
        /// Overdue uncompleted task.
        case overdueTask
        /// 今日到期待办
        /// Task due today.
        case todayTask
        /// 当前进行中的例程
        /// Routine currently active.
        case routineActive
        /// 即将开始的例程
        /// Routine starting soon.
        case routineUpcoming
        /// HRV 低/恢复建议
        /// Recovery suggestion (low HRV).
        case recovery
        /// 强势科建议(数据少时的兜底)
        /// Strong-subject suggestion (fallback when data is thin).
        case strongSubject
        /// 全部为空时的占位
        /// Placeholder when the list is empty.
        case placeholder
    }

    /// 跳转目标(给 View 层用)
    /// Navigation target (for the view layer).
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
// MARK: - 今日计划引擎 / Daily plan engine

/// 今日计划生成器。纯函数,无副作用。
/// Daily plan generator. Pure function, side-effect free.
enum DailyPlanEngine {

    // MARK: - Score constants
    // MARK: - 评分常量 / Score constants

    private static let baseWeightUrgentExam: Double = 100
    private static let baseWeightSrsReview: Double = 60
    private static let baseWeightOverdueTask: Double = 80
    private static let baseWeightTodayTask: Double = 50
    private static let baseWeightRoutineActive: Double = 90
    private static let baseWeightRoutineUpcoming: Double = 40
    private static let baseWeightRecovery: Double = 70
    private static let baseWeightStrongSubject: Double = 20

    // MARK: - Generate
    // MARK: - 生成 / Generate

    /// 生成按 score 降序排序的 plan 列表,最多 `max` 条。
    /// Generate the daily plan sorted by score desc, capped at `max` items.
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
    // MARK: - 工具方法 / Helpers

    /// HRV 当前因子(影响 score 缩放)
    /// Current HRV factor (multiplies the plan score).
    /// - 高恢复(>= normal)→ 1.2
    ///   High recovery (>= normal) → 1.2
    /// - normal / insufficient / loading → 1.0
    ///   normal / insufficient / loading → 1.0
    /// - low → 0.6(降低硬任务权重)
    ///   low → 0.6 (down-weights hard tasks)
    /// - 不可用(noAuthorization/queryFailed)→ 1.0
    ///   unavailable (noAuthorization / queryFailed) → 1.0
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
    /// Compute a single item's score (used by tests for verification).
    /// 公式:`baseWeight * urgencyMultiplier * hrvFactor`
    /// Formula: `baseWeight * urgencyMultiplier * hrvFactor`.
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
    // MARK: - 信号提取器 / Signal extractors

    /// 紧急考试(今天/明天,最多 3 条,合并显示)
    /// Urgent exams (today/tomorrow, up to 3, merged into one plan item).
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
    /// SRS-overdue mistakes (single summary item, no per-mistake detail).
    static func srsReviewItem(context: DailyPlanContext) -> DailyPlanItem? {
        let overview = SRSAlgorithm.overview(from: context.mistakeSets, now: context.now)
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
    /// Pending tasks: overdue + due-today (one of each, merged into the plan).
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
    /// Routines: active + starting-within-30-min, one of each.
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
    /// Recovery suggestion (only when readiness is `low`).
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
    /// Strong-subject suggestion (only when >= 2 subjects have data
    /// and the current candidate list has room for it).
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
