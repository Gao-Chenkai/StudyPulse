//
//  SubjectMistakesViewModel.swift
//  StudyPulse
//
//  错题详情页 ViewModel。负责单科内的搜索/排序/复习建议。
// 之前在 SubjectMistakesView 内的 3 个 computed properties。
//
//  Created for MVVM refactor (2026-07-05).
//

import Foundation
import Combine

@MainActor
final class SubjectMistakesViewModel: ObservableObject {
    /// 入口传入的错题(由父视图提供,View 自身不持有数据源)
    let initialMistakes: [MistakeNote]

    init(initialMistakes: [MistakeNote]) {
        self.initialMistakes = initialMistakes
    }

    /// 搜索/排序单科目错题(代理到 Service)
    func searchInSubject(_ mistakes: [MistakeNote], searchText: String) -> [MistakeNote] {
        MistakeFilter.searchInSubject(mistakes, searchText: searchText)
    }

    /// 复习建议(代理到 Service)
    func suggestedForReview(_ mistakes: [MistakeNote]) -> [MistakeNote] {
        MistakeFilter.suggestedForReview(mistakes)
    }
}
