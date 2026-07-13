//
//  SubjectMistakesViewModel.swift
//  StudyPulse
//
import Foundation
import Combine

@MainActor
final class SubjectMistakesViewModel: ObservableObject {
    /// 入口传入的错题(View 不持有数据源) / Mistakes injected by parent view.
    let initialMistakes: [MistakeNote]

    init(initialMistakes: [MistakeNote]) {
        self.initialMistakes = initialMistakes
    }

    /// 单科搜索 / 排序(代理到 Service) / Per-subject search/sort (delegated).
    func searchInSubject(_ mistakes: [MistakeNote], searchText: String) -> [MistakeNote] {
        MistakeFilter.searchInSubject(mistakes, searchText: searchText)
    }

    /// 复习建议(代理到 Service) / Review suggestions (delegated).
    func suggestedForReview(_ mistakes: [MistakeNote]) -> [MistakeNote] {
        MistakeFilter.suggestedForReview(mistakes)
    }
}
