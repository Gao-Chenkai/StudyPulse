//
//  MistakeViewModel.swift
//  StudyPulse
//
//  错题页 ViewModel。负责分组/搜索/排序/SRS 概览/复习建议。
// 抽取自 MistakeView.recomputeAll() + SubjectMistakesView 的 3 个 computed properties。
//
//  Created for MVVM refactor (2026-07-05).
//  Updated for Repository pattern (2026-07-05).
//

import Foundation
import Combine

@MainActor
final class MistakeViewModel: ObservableObject {

    // MARK: - Dependencies

    private let container: RepositoryContainer

    // MARK: - Input State(View 写,VM 读)

    /// 搜索词
    @Published var searchText: String = ""

    // MARK: - Output State

    @Published private(set) var groups: MistakeGroups = .empty
    @Published private(set) var srsOverview: SRSOverview = .empty

    // MARK: - Init

    init(container: RepositoryContainer) {
        self.container = container
    }

    static func makeDefault(container: RepositoryContainer) -> MistakeViewModel {
        MistakeViewModel(container: container)
    }

    // MARK: - 业务方法

    /// 集中重算所有缓存
    func recompute() {
        let filteredMistakes = container.mistakeRepo.filteredMistakeSets
        groups = MistakeFilter.group(
            mistakes: filteredMistakes,
            searchText: searchText
        )
        srsOverview = SRSAlgorithm.overview(from: filteredMistakes)
    }

    /// 单科目内的搜索/排序
    func searchInSubject(_ mistakes: [MistakeNote]) -> [MistakeNote] {
        MistakeFilter.searchInSubject(mistakes, searchText: searchText)
    }

    /// 复习建议
    func suggestedForReview(_ mistakes: [MistakeNote]) -> [MistakeNote] {
        MistakeFilter.suggestedForReview(mistakes)
    }
}

private extension MistakeGroups {
    static let empty = MistakeGroups(
        bySubject: [:],
        sortedSubjects: [],
        filteredSubjects: [],
        totalCount: 0
    )
}
