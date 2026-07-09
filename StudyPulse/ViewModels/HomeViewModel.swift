//
//  HomeViewModel.swift
//  StudyPulse
//
//  首页 ViewModel。负责 4 个核心派生数据的重算 + 图表选科 + 建议生成。
// 渲染/分享(imageRenderer)是 UI 关注点,保留在 View 层。
//
//  设计:
//  - @MainActor + ObservableObject
//  - 状态全部 @Published private(set),View 只读不写
//  - 业务方法(recompute / selectChartSubject / generateSuggestions)不依赖 SwiftUI View
//
//  Created for MVVM refactor (2026-07-05).
//  Updated for Repository pattern (2026-07-05).
//

import Foundation
import SwiftUI
import Combine

/// 学科选择规则(图表卡片的"聚焦"模式)
enum SubjectSelectionRule: Equatable {
    case lowestScore
    case mostGrades
    case recentMost
    case mostImprovement
    case random

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

/// 首页 ViewModel。
/// 负责派生数据重算、图表选科、学习建议生成;
/// 不参与 UI 渲染 / 分享 sheet 控制(这些是 View 的事)。
@MainActor
final class HomeViewModel: ObservableObject {

    // MARK: - Dependencies

    private let container: RepositoryContainer
    private let hrvManager: HealthKitManager

    // MARK: - Output State(@Published private(set),View 只读)

    @Published private(set) var srsOverview: SRSOverview = .empty
    @Published private(set) var recentGrades: [Grade] = []
    @Published private(set) var upcomingExams: [Exam] = []
    @Published private(set) var unregisteredExams: [Exam] = []
    /// 今日 Top-3 计划(2026-07-09 新增, Plans & Routines spec)
    @Published private(set) var dailyPlan: [DailyPlanItem] = []

    /// 图表卡片的当前规则 + 选中科目
    @Published private(set) var chartRule: SubjectSelectionRule = .lowestScore
    @Published private(set) var chartSelectedSubject: String? = nil

    // MARK: - Init

    init(container: RepositoryContainer, hrvManager: HealthKitManager) {
        self.container = container
        self.hrvManager = hrvManager
    }

    // MARK: - Factory(container 由父 View 通过 init 传入)

    /// 工厂方法。Container 由 StudyPulseApp 创建并通过环境注入;
    /// 父 View 在 init 阶段调用此工厂构建 VM。
    static func makeDefault(container: RepositoryContainer) -> HomeViewModel {
        HomeViewModel(
            container: container,
            hrvManager: HealthKitManager.shared
        )
    }

    // MARK: - 业务方法:派生数据重算

    /// 一次性刷新 4 个缓存(SRS / recent grades / upcoming exams / unregistered exams)。
    /// View 内的 onChange(of: container.gradeRepo.grades) / onAppear 都应调此方法。
    func recompute() {
        let grades = container.gradeRepo.grades
        let mistakes = container.mistakeRepo.mistakeSets
        let filteredExams = container.examRepo.filteredExamSets

        // SRS
        srsOverview = SRSAlgorithm.overview(from: mistakes)

        // Recent grades: 按时间倒序取前 5
        let sortedGradesDesc = grades.sorted { $0.date > $1.date }
        recentGrades = Array(sortedGradesDesc.prefix(5))

        // Upcoming exams: 14 天内
        upcomingExams = ExamFilter.examsWithinDays(14, exams: filteredExams)

        // Unregistered exams: 已过 3-7 天但未登记
        unregisteredExams = ExamFilter.unregisteredExams(
            startDaysAgo: -3,
            endDaysAgo: -7,
            grades: grades,
            exams: filteredExams
        )

        // 今日 Top-3 计划(2026-07-09 新增)
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

        // 图表选中科目可能因为数据变化失效,刷新
        applyChartRule(chartRule)
    }

    // MARK: - 业务方法:图表选择

    /// 用户切换聚焦规则
    func selectChartSubject(rule: SubjectSelectionRule) {
        chartRule = rule
        applyChartRule(rule)
    }

    /// 根据当前规则 + 数据重新计算选中科目
    private func applyChartRule(_ rule: SubjectSelectionRule) {
        let grades = container.gradeRepo.grades
        let activeSubjects = Set(grades.map { $0.subject })
        guard !activeSubjects.isEmpty else {
            chartSelectedSubject = nil
            return
        }
        // 单次 O(n) 分组聚合
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
            // 改进分 = (last - first);需要至少 2 条成绩
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

    /// 查询某科目的全部成绩(给 chart card 用)
    func gradesForSubject(_ subject: String) -> [Grade]? {
        let grades = container.gradeRepo.grades.filter { $0.subject == subject }
        return grades.isEmpty ? nil : grades
    }

    // MARK: - 业务方法:学习建议(供 StudySuggestionsCard 复用)

    /// 生成学习建议列表。供 StudySuggestionsCardViewModel 调用。
    /// 内部调用 `SuggestionEngine.generate(...)`,body 状态建议从 HealthKitManager 取。
    func generateSuggestions(limit: Int = 3) -> [StudySuggestion] {
        let body = StudyReadinessAlgorithm.recommend(
            hrvEnabled: hrvManager.hrvEnabled,
            hrvOnboardingCompleted: hrvManager.hrvOnboardingCompleted,
            isAuthorized: hrvManager.isAuthorized,
            hrv: hrvManager.readiness,
            bodyStatus: hrvManager.bodyStatus,
            baselines: hrvManager.personalBaselines,
            age: container.profileRepo.profile.age
        )
        let context = StudySuggestionsContext(
            grades: container.gradeRepo.grades,
            mistakeSets: container.mistakeRepo.mistakeSets,
            examSets: container.examRepo.filteredExamSets,
            profile: container.profileRepo.profile,
            bodyStatusSuggestion: body
        )
        return SuggestionEngine.generate(from: context, max: limit)
    }
}
