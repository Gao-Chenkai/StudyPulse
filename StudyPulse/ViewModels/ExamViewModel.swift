//
//  ExamViewModel.swift
//  StudyPulse
//
//  考试页 ViewModel。负责合并排序 + past/upcoming 拆分 + 未来考试分桶。
// 抽取自 ExamView 的 4 个 computed properties(allExamsSorted / upcomingExams /
// pastExams / groupedExams)。
//
//  Created for MVVM refactor (2026-07-05).
//  Updated for Repository pattern (2026-07-05).
//

import Foundation
import Combine

@MainActor
final class ExamViewModel: ObservableObject {

    // MARK: - Dependencies

    private let container: RepositoryContainer

    // MARK: - Output State

    @Published private(set) var allItems: [ExamItem] = []
    @Published private(set) var upcomingItems: [ExamItem] = []
    @Published private(set) var pastItems: [ExamItem] = []
    @Published private(set) var groupedUpcoming: [ExamBucket] = []

    // MARK: - Init

    init(container: RepositoryContainer) {
        self.container = container
    }

    static func makeDefault(container: RepositoryContainer) -> ExamViewModel {
        ExamViewModel(container: container)
    }

    // MARK: - 业务方法

    /// 集中重算所有缓存
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

    // MARK: - 业务方法:删除

    /// 删除单科考试。ExamRepository 提供专门的 deleteExam。
    func deleteExam(_ exam: Exam) {
        container.examRepo.deleteExam(exam)
        recompute()
    }

    /// 删除综合考试。ExamRepository 提供专门的 deleteComprehensiveExam。
    func deleteComprehensiveExam(_ exam: comprehensiveExam) {
        container.examRepo.deleteComprehensiveExam(exam)
        recompute()
    }
}
