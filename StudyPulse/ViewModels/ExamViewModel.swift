//
//  ExamViewModel.swift
//  StudyPulse
//
//  Created by Antigravity on 2026/7/12.
//
//  考试页 ViewModel。负责合并单科 / 综合考试、按时间分组,以及分数预测入口。
//  Exam-list VM. Merges single/comprehensive exams, groups by time, gates
//  the score-prediction flow.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class ExamViewModel {
    // MARK: - 依赖项 / Dependencies
    private let container: RepositoryContainer

    // MARK: - 界面状态 / UI states
    /// 是否显示"新增考试"弹窗 / Whether the "new exam set" sheet is shown.
    var showingNewExamSet = false
    /// 选中的单科考试(详情 sheet) / Selected single-subject exam (detail).
    var selectedExamForDetail: Exam? = nil
    /// 选中的综合考试(详情 sheet) / Selected comprehensive exam (detail).
    var selectedComprehensiveExam: comprehensiveExam? = nil
    /// 是否显示"过往考试"列表 / Whether the past-exams list is shown.
    var showingPastExams = false
    /// 列表/日历 视图模式(持久化) / List/calendar view mode (persisted).
    var viewMode: ExamViewMode = ExamViewMode.loadFromDefaults()
    /// 单科预测目标 / Single-subject prediction target.
    var predictionTarget: PredictionTarget? = nil
    /// 综合考试预测目标 / Comprehensive-exam prediction target.
    var comprehensivePredictionTarget: ComprehensivePredictionTarget? = nil

    // MARK: - 输出状态 / Output states
    /// 全部考试项(已合并 + 排序) / All items (merged & sorted).
    private(set) var allItems: [ExamItem] = []
    /// 即将到来的考试项 / Upcoming items.
    private(set) var upcomingItems: [ExamItem] = []
    /// 已过去的考试项 / Past items.
    private(set) var pastItems: [ExamItem] = []
    /// 即将到来的考试按时间分桶 / Upcoming items bucketed by time.
    private(set) var groupedUpcoming: [ExamBucket] = []

    // MARK: - 初始化 / Initialization
    init(container: RepositoryContainer) {
        self.container = container
    }

    /// 工厂方法 / Factory.
    static func makeDefault(container: RepositoryContainer) -> ExamViewModel {
        ExamViewModel(container: container)
    }

    // MARK: - 计算属性 / Computed properties
    /// 是否以日历形态展示 / Whether to render in calendar mode.
    var showsCalendar: Bool {
        viewMode == .calendar
    }

    /// 全部考试(解开 enum 包装) / All exams (enum unwrapped).
    var allExamsSorted: [Any] {
        allItems.map { item -> Any in
            switch item {
            case .single(let e): return e
            case .comprehensive(let e): return e
            }
        }
    }

    /// 即将到来的考试(解开 enum) / Upcoming exams (enum unwrapped).
    var upcomingExams: [Any] {
        upcomingItems.map { item -> Any in
            switch item {
            case .single(let e): return e
            case .comprehensive(let e): return e
            }
        }
    }

    /// 已过去的考试(解开 enum) / Past exams (enum unwrapped).
    var pastExams: [Any] {
        pastItems.map { item -> Any in
            switch item {
            case .single(let e): return e
            case .comprehensive(let e): return e
            }
        }
    }

    /// 按时间分桶的即将到来考试(标题 + 列表)
    /// Upcoming exams grouped by time (title + list).
    var groupedExams: [(sectionTitle: String, exams: [Any])] {
        groupedUpcoming.map { bucket in
            (bucket.title, bucket.items.map { item -> Any in
                switch item {
                case .single(let e): return e
                case .comprehensive(let e): return e
                }
            })
        }
    }

    // MARK: - 操作 / Actions
    /// 集中重算所有输出缓存(合并 + 拆分 + 分桶)
    /// Recompute all output caches (merge, split, bucketize).
    func recompute() {
        let merged = ExamFilter.mergeAndSort(
            single: container.examRepo.filteredExamSets,
            comprehensive: container.examRepo.filteredComprehensiveExamSets
        )
        allItems = merged
        upcomingItems = ExamFilter.upcomingItems(from: merged)
        pastItems = ExamFilter.pastItems(from: merged)
        groupedUpcoming = ExamFilter.bucketUpcomingItems(from: merged)
    }

    /// 删除单科考试并立即重算 / Delete a single exam and recompute.
    func deleteExam(_ exam: Exam) {
        container.deleteExam(exam)
        recompute()
    }

    /// 删除综合考试并立即重算 / Delete a comprehensive exam and recompute.
    func deleteComprehensiveExam(_ exam: comprehensiveExam) {
        container.deleteComprehensiveExam(exam)
        recompute()
    }

    /// 切换列表 / 日历视图并持久化 / Toggle list/calendar view & persist.
    func toggleViewMode() {
        if viewMode == .list {
            viewMode = .calendar
        } else {
            viewMode = .list
        }
        viewMode.saveToDefaults()
    }

    /// 为单科考试准备预测数据并打开预测 sheet
    /// Prepare prediction data and open the prediction sheet.
    func openPrediction(for exam: Exam) {
        let subjectGrades = container.gradeRepo.filteredGrades
            .filter { $0.subject == exam.subject }
        // 默认满分 100,未配置 subject 时兜底
        // Default full-score 100, fallback when subject config is missing.
        let fullScore = container.subjectRepo.subjects.first(where: { $0.name == exam.subject })?.fullScore ?? 100
        predictionTarget = PredictionTarget(
            exam: exam,
            history: subjectGrades,
            fullScore: fullScore
        )
    }

    /// 为综合考试逐科预测并聚合成"全卷"预测
    /// Per-subject predict and aggregate into a whole-exam prediction.
    func openPrediction(for exam: comprehensiveExam) {
        let predictor = ScorePredictorFactory.active
        let allSubjects = exam.subject
        var perSubject: [PerSubjectPrediction] = []
        var totalFull: Double = 0
        var totalPredicted: Double = 0
        var totalLower: Double = 0
        var totalUpper: Double = 0

        for subject in allSubjects {
            let grades = container.gradeRepo.filteredGrades.filter { $0.subject == subject }
            let mistakes = container.mistakeRepo.filteredMistakeSets.filter { $0.subject == subject }
            let context = MistakeContext.build(from: mistakes)
            // 默认满分 100,未配置 subject 时兜底
            // Default full-score 100, fallback when subject config is missing.
            let fullScore = container.subjectRepo.subjects.first(where: { $0.name == subject })?.fullScore ?? 100
            if let r = predictor.predict(history: grades, mistakeContext: context, examDate: exam.examDate, fullScore: fullScore) {
                perSubject.append(PerSubjectPrediction(subject: subject, result: r))
                // 累加各科预测值用于汇总总分
                // Accumulate per-subject predictions for the total.
                totalFull += fullScore
                totalPredicted += r.predicted
                totalLower += r.lowerBound
                totalUpper += r.upperBound
            }
        }
        // 没有任何科目能成功预测 → 不显示 sheet
        // No subject produced a successful prediction → don't show the sheet.
        guard !perSubject.isEmpty else { return }
        comprehensivePredictionTarget = ComprehensivePredictionTarget(
            exam: exam,
            perSubject: perSubject,
            totalFull: totalFull,
            totalPredicted: totalPredicted,
            totalLower: totalLower,
            totalUpper: totalUpper
        )
    }
}
