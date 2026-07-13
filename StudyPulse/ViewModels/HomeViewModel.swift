//
//  HomeViewModel.swift
//  StudyPulse
//
//  首页 ViewModel。负责 4 个核心派生数据的重算 + 图表选科 + 建议生成。
//  渲染/分享(imageRenderer)是 UI 关注点,保留在 View 层。
//  Home-page VM. Recomputes 4 core derived datasets, picks the chart
//  subject, and generates study suggestions. Rendering/sharing stays in
//  the View.
//
//  Created for MVVM refactor (2026-07-05).
//  Updated for Repository pattern (2026-07-05).
//

import Foundation
import SwiftUI
import Combine

/// 学科选择规则(图表卡片的"聚焦"模式)
/// Subject-selection rule (the chart card's "focus" mode).
enum SubjectSelectionRule: Equatable {
    case lowestScore
    case mostGrades
    case recentMost
    case mostImprovement
    case random

    /// 规则的用户可见名 / User-visible, localized name.
    var displayName: String {
        switch self {
        case .lowestScore: return "Focus: Weakest".localized()
        case .mostGrades:  return "Focus: Most Data".localized()
        case .recentMost:  return "Focus: Recent".localized()
        case .mostImprovement: return "Focus: Improving".localized()
        case .random:      return "Random".localized()
        }
    }
}

/// 首页 ViewModel。负责派生数据重算、图表选科、学习建议生成
/// (不参与 UI 渲染 / 分享 sheet 控制)。
/// Home-page VM. Recomputes derived data, picks the chart subject, and
/// generates study suggestions (does NOT own UI/share-sheet state).
@MainActor
final class HomeViewModel: ObservableObject {

    // MARK: - 依赖项 / Dependencies
    private let container: RepositoryContainer
    private let hrvManager: HealthKitManager

    // MARK: - 输出状态(View 只读) / Output state (read-only for View)
    /// SRS 总览 / SRS overview.
    @Published private(set) var srsOverview: SRSOverview = .empty
    /// 最近的 5 条成绩(按时间倒序) / Most recent 5 grades (newest first).
    @Published private(set) var recentGrades: [Grade] = []
    /// 14 天内的即将到来的考试 / Upcoming exams within 14 days.
    @Published private(set) var upcomingExams: [Exam] = []
    /// 3~7 天前发生过、但还没登记的考试 / Unregistered exams (3–7 days ago).
    @Published private(set) var unregisteredExams: [Exam] = []
    /// 今日 Top-3 计划(2026-07-09) / Today's Top-3 plan (2026-07-09).
    @Published private(set) var dailyPlan: [DailyPlanItem] = []

    /// 图表卡片的当前规则 + 选中科目 / Current chart rule & subject.
    @Published private(set) var chartRule: SubjectSelectionRule = .lowestScore
    @Published private(set) var chartSelectedSubject: String? = nil

    // MARK: - 初始化 / Initialization
    init(container: RepositoryContainer, hrvManager: HealthKitManager) {
        self.container = container
        self.hrvManager = hrvManager
    }

    /// 工厂方法 / Factory.
    static func makeDefault(container: RepositoryContainer) -> HomeViewModel {
        HomeViewModel(
            container: container,
            hrvManager: HealthKitManager.shared
        )
    }

    // MARK: - 业务方法:派生数据重算 / Business: derived-data recompute
    /// 一次性刷新 4 个缓存(SRS / recent grades / upcoming / unregistered)
    /// One-shot refresh of 4 caches.
    func recompute() {
        let grades = container.gradeRepo.grades
        let mistakes = container.mistakeRepo.mistakeSets
        let filteredExams = container.examRepo.filteredExamSets

        // SRS
        srsOverview = SRSAlgorithm.overview(from: mistakes)

        // Recent grades: 按时间倒序取前 5 / Newest 5 by date desc.
        let sortedGradesDesc = grades.sorted { $0.date > $1.date }
        recentGrades = Array(sortedGradesDesc.prefix(5))

        // Upcoming exams: 14 天内 / Within 14 days.
        upcomingExams = ExamFilter.examsWithinDays(14, exams: filteredExams)

        // Unregistered exams: 已过 3-7 天 / 3–7 days ago, still ungraded.
        unregisteredExams = ExamFilter.unregisteredExams(
            startDaysAgo: -3,
            endDaysAgo: -7,
            grades: grades,
            exams: filteredExams
        )

        // 今日 Top-3 计划(2026-07-09) / Today's Top-3 plan.
        let taskItems = container.taskRepo.filteredTaskItems
        let routineInstances = container.routineInstanceRepo.allInstances
        let planContext = DailyPlanContext(
            grades: grades,
            mistakeSets: mistakes,
            examSets: filteredExams,
            taskItems: taskItems,
            routineInstances: routineInstances,
            hrvReadiness: hrvManager.readiness,
            hrvBodyStatus: hrvManager.bodyStatus
        )
        dailyPlan = DailyPlanEngine.generate(from: planContext, max: 3)

        // 图表选中科目可能因数据变化失效,刷新
        // Selected chart subject may be stale → refresh.
        applyChartRule(chartRule)
    }

    // MARK: - 业务方法:图表选择 / Business: chart subject selection
    /// 用户切换聚焦规则 / User switches the focus rule.
    func selectChartSubject(rule: SubjectSelectionRule) {
        chartRule = rule
        applyChartRule(rule)
    }

    /// 根据当前规则 + 数据重新计算选中科目
    /// Recompute the selected subject from rule + data.
    private func applyChartRule(_ rule: SubjectSelectionRule) {
        let grades = container.gradeRepo.grades
        let activeSubjects = Set(grades.map { $0.subject })
        guard !activeSubjects.isEmpty else {
            chartSelectedSubject = nil
            return
        }
        // 单次 O(n) 分组聚合 / Single-pass group + aggregate.
        let aggregates = SubjectAggregator.aggregate(
            grades: grades,
            subjects: activeSubjects
        )
        switch rule {
        case .lowestScore:
            chartSelectedSubject = aggregates.min { $0.value.average < $1.value.average }?.key
        case .mostGrades:
            chartSelectedSubject = aggregates.max { $0.value.count < $1.value.count }?.key
        case .recentMost:
            chartSelectedSubject = aggregates.max { $0.value.recentCount < $1.value.recentCount }?.key
        case .mostImprovement:
            // 改进分 = (last - first);至少 2 条成绩
            // Improvement = last - first; needs ≥ 2 grades.
            chartSelectedSubject = aggregates.compactMap { (subject, agg) -> (String, Double)? in
                guard let first = agg.sortedAsc.first,
                      let last = agg.sortedAsc.last,
                      agg.sortedAsc.count >= 2 else { return nil }
                return (subject, last.score - first.score)
            }.max { $0.1 < $1.1 }?.0
        case .random:
            chartSelectedSubject = activeSubjects.randomElement()
        }
    }

    /// 查询某科目的全部成绩(chart card 用) / All grades for a subject.
    func gradesForSubject(_ subject: String) -> [Grade]? {
        let grades = container.gradeRepo.grades.filter { $0.subject == subject }
        return grades.isEmpty ? nil : grades
    }

    // MARK: - 业务方法:学习建议 / Business: study suggestions
    /// 生成学习建议列表 / Generate study suggestions.
    func generateSuggestions(limit: Int = 3) -> [StudySuggestion] {
        let context = buildSuggestionsContext()
        return SuggestionEngine.generate(from: context, max: limit)
    }

    /// 构造学习建议上下文(供 LLM 增强使用)
    /// Build the suggestions context (also for LLM augmentation).
    func buildSuggestionsContext() -> StudySuggestionsContext {
        let body = StudyReadinessAlgorithm.recommend(
            hrvEnabled: hrvManager.hrvEnabled,
            hrvOnboardingCompleted: hrvManager.hrvOnboardingCompleted,
            isAuthorized: hrvManager.isAuthorized,
            hrv: hrvManager.readiness,
            bodyStatus: hrvManager.bodyStatus,
            baselines: hrvManager.personalBaselines,
            age: container.profileRepo.profile.age
        )
        return StudySuggestionsContext(
            grades: container.gradeRepo.grades,
            mistakeSets: container.mistakeRepo.mistakeSets,
            examSets: container.examRepo.filteredExamSets,
            profile: container.profileRepo.profile,
            bodyStatusSuggestion: body
        )
    }
}
