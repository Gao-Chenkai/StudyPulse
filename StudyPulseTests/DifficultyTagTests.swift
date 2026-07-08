//
//  DifficultyTagTests.swift
//  StudyPulseTests
//
//  Unit tests for the difficulty multiplier + tag filter logic
//  added 2026-07-08.
//

import XCTest
@testable import StudyPulse

@MainActor
final class DifficultyTagTests: XCTestCase {

    // All tests use MistakeFilter which is @MainActor isolated.

    func test_difficultyMultiplier_returnsExpectedValues() {
        XCTAssertEqual(SRSAlgorithm.difficultyMultiplier(for: 1), 0.5, accuracy: 0.001)
        XCTAssertEqual(SRSAlgorithm.difficultyMultiplier(for: 2), 0.75, accuracy: 0.001)
        XCTAssertEqual(SRSAlgorithm.difficultyMultiplier(for: 3), 1.0, accuracy: 0.001)
        XCTAssertEqual(SRSAlgorithm.difficultyMultiplier(for: 4), 1.3, accuracy: 0.001)
        XCTAssertEqual(SRSAlgorithm.difficultyMultiplier(for: 5), 1.6, accuracy: 0.001)
    }

    func test_difficultyMultiplier_unratedIsNeutral() {
        XCTAssertEqual(SRSAlgorithm.difficultyMultiplier(for: 0), 1.0, accuracy: 0.001)
        XCTAssertEqual(SRSAlgorithm.difficultyMultiplier(for: 99), 1.0, accuracy: 0.001)
    }

    func test_apply_easyDifficultyShortensInterval() {
        // 第一次复习 .good:repetitions=1, intervalDays=1(基础值,无乘子)
        // 第二次复习 .good:repetitions=2, intervalDays=6(基础值)
        // 第三次复习 .good:repetitions=3, intervalDays=6 * EF(2.5)=15
        // 难度=1 → 乘子 0.5 → 7 或 8
        let initial = ReviewState.initial()
        let s1 = SRSAlgorithm.apply(quality: .good, to: initial)
        let s2 = SRSAlgorithm.apply(quality: .good, to: s1, difficulty: 1)
        let s3 = SRSAlgorithm.apply(quality: .good, to: s2, difficulty: 1)
        XCTAssertEqual(s1.intervalDays, 1, "first .good is 1 day")
        XCTAssertEqual(s2.intervalDays, 6, "second .good base is 6 days (no multiplier when difficulty=0)")
        // s3: 6 * 2.5 = 15 → 15 * 0.5 = 7 (or 8)
        XCTAssertTrue((7...8).contains(s3.intervalDays), "third .good with difficulty=1 should be 7-8 days, got \(s3.intervalDays)")
    }

    func test_apply_hardDifficultyExtendsInterval() {
        // 难度=5 → 乘子 1.6
        // 第三次 .good:6 * 2.5 = 15 → 15 * 1.6 = 24
        let initial = ReviewState.initial()
        let s1 = SRSAlgorithm.apply(quality: .good, to: initial)
        let s2 = SRSAlgorithm.apply(quality: .good, to: s1, difficulty: 5)
        let s3 = SRSAlgorithm.apply(quality: .good, to: s2, difficulty: 5)
        XCTAssertEqual(s3.intervalDays, 24, "third .good with difficulty=5 should be 15*1.6=24 days, got \(s3.intervalDays)")
    }

    func test_apply_neutralDifficultyLeavesIntervalUnchanged() {
        // difficulty=3 (neutral) 等价于 difficulty=0
        let initial = ReviewState.initial()
        let sNoDifficulty = SRSAlgorithm.apply(quality: .good, to: initial)
        let sNeutral = SRSAlgorithm.apply(quality: .good, to: initial, difficulty: 3)
        XCTAssertEqual(sNoDifficulty.intervalDays, sNeutral.intervalDays, "neutral difficulty should leave interval unchanged")
    }

    // MARK: - Tag filter

    func makeMistake(id: UUID = UUID(), title: String = "T", tags: [String], subject: String = "Math") -> MistakeNote {
        MistakeNote(
            id: id, title: title, subject: subject, originalQuestion: "Q",
            source: "S", errorReason: "E", wrongSolution: "W", correctSolution: "C",
            tags: tags
        )
    }

    func test_allTags_dedupesCaseInsensitive() {
        let mistakes = [
            self.makeMistake(tags: ["函数", "导数"]),
            self.makeMistake(tags: ["函数", "三角"]),
            self.makeMistake(tags: ["解析几何"])
        ]
        let result = MistakeFilter.allTags(mistakes)
        XCTAssertEqual(result, ["函数", "导数", "三角", "解析几何"])
    }

    func test_allTags_preservesFirstAppearanceCase() {
        let mistakes = [
            self.makeMistake(tags: ["函数"]),
            self.makeMistake(tags: ["函数"]),  // dedup
            self.makeMistake(tags: ["函数"])   // dedup
        ]
        let result = MistakeFilter.allTags(mistakes)
        XCTAssertEqual(result, ["函数"])
    }

    func test_tagged_caseInsensitiveMatch() {
        let a = self.makeMistake(tags: ["函数"])
        let b = self.makeMistake(tags: ["导数"])
        let result = MistakeFilter.tagged([a, b], tag: "函数")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, a.id)
    }

    func test_searchInSubject_hashTagPrefix_filtersByTag() {
        let a = self.makeMistake(tags: ["函数"])
        let b = self.makeMistake(tags: ["导数"])
        let c = self.makeMistake(tags: ["函数", "导数"])
        let result = MistakeFilter.searchInSubject([a, b, c], searchText: "#函数")
        XCTAssertEqual(result.count, 2)
    }

    func test_searchInSubject_hashTagEmptyReturnsAll() {
        let a = self.makeMistake(tags: ["函数"])
        let result = MistakeFilter.searchInSubject([a], searchText: "#")
        XCTAssertEqual(result.count, 1, "empty tag after # → no filter")
    }

    func test_searchInSubject_plainSearch_matchesTag() {
        let a = self.makeMistake(tags: ["导数"])
        let b = self.makeMistake(tags: ["函数"])
        let result = MistakeFilter.searchInSubject([a, b], searchText: "导数")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, a.id)
    }

    func test_tagCounts_sortedByCountDesc() {
        let a = self.makeMistake(tags: ["函数", "导数"])
        let b = self.makeMistake(tags: ["函数", "导数"])
        let c = self.makeMistake(tags: ["函数"])
        let d = self.makeMistake(tags: ["三角"])
        let counts = MistakeFilter.tagCounts([a, b, c, d])
        XCTAssertEqual(counts.first?.tag, "函数")
        XCTAssertEqual(counts.first?.count, 3)
        XCTAssertEqual(counts[1].tag, "导数")
        XCTAssertEqual(counts[1].count, 2)
        XCTAssertEqual(counts[2].tag, "三角")
        XCTAssertEqual(counts[2].count, 1)
    }

    // MARK: - Multi-tag search (AND)

    func test_searchInSubject_multiTagAnd_semantics() {
        let a = self.makeMistake(tags: ["函数", "导数"])
        let b = self.makeMistake(tags: ["函数", "三角"])
        let c = self.makeMistake(tags: ["导数", "三角"])
        let d = self.makeMistake(tags: ["函数", "导数", "三角"])
        let result = MistakeFilter.searchInSubject([a, b, c, d], searchText: "#函数 #导数")
        // a 和 d 同时有「函数」和「导数」
        XCTAssertEqual(result.count, 2)
        let ids = Set(result.map(\.id))
        XCTAssertTrue(ids.contains(a.id))
        XCTAssertTrue(ids.contains(d.id))
    }

    func test_searchInSubject_multiTagWithCommaSeparator() {
        let a = self.makeMistake(tags: ["函数", "导数"])
        let b = self.makeMistake(tags: ["函数"])
        let result = MistakeFilter.searchInSubject([a, b], searchText: "#函数,#导数")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, a.id)
    }

    func test_searchInSubject_tagWithPlainText() {
        let a = self.makeMistake(title: "极限题", tags: ["函数"])
        let b = self.makeMistake(title: "导数题", tags: ["函数"])
        let c = self.makeMistake(title: "极限题", tags: ["导数"])
        // #函数 标签 + "极限" 自由文本 → 必须既带「函数」tag 又匹配「极限」
        let result = MistakeFilter.searchInSubject([a, b, c], searchText: "#函数 极限")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, a.id)
    }

    func test_searchInSubject_emptyQueryReturnsAll() {
        let a = self.makeMistake(tags: ["函数"])
        let b = self.makeMistake(tags: ["导数"])
        let result = MistakeFilter.searchInSubject([a, b], searchText: "")
        XCTAssertEqual(result.count, 2)
    }

    func test_parseSearchQuery_extractsMultipleTags() {
        let parsed = MistakeFilter.parseSearchQuery("#函数 #导数 极限")
        XCTAssertEqual(parsed.tags, ["函数", "导数"])
        XCTAssertEqual(parsed.text, "极限")
    }
}
