//
//  MistakeFilterTests.swift
//  StudyPulseTests
//
//  Unit tests for MistakeFilter (Services/MistakeFilter.swift).
//  Tests grouping, sorting, search filter, and review-suggestion ranking.
//

import XCTest
@testable import StudyPulse

@MainActor
final class MistakeFilterTests: XCTestCase {

    // Fixed reference: 2026-06-15 12:00:00 UTC
    private let now: Date = {
        var c = DateComponents()
        c.year = 2026
        c.month = 6
        c.day = 15
        c.hour = 12
        c.minute = 0
        c.second = 0
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c) ?? Date()
    }()

    // MARK: - Helpers

    private func makeMistake(
        title: String = "Q",
        subject: String = "Math",
        originalQuestion: String = "What is 2+2?",
        source: String = "Book",
        daysAgo: Int = 0
    ) -> MistakeNote {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: now) ?? now
        return MistakeNote(
            title: title,
            subject: subject,
            originalQuestion: originalQuestion,
            source: source,
            date: date,
            errorReason: "calc",
            wrongSolution: "1+1",
            correctSolution: "2+2"
        )
    }

    // MARK: - group

    func test_group_groupsBySubject() {
        let m1 = makeMistake(title: "Q1", subject: "Math", daysAgo: 5)
        let m2 = makeMistake(title: "Q2", subject: "Math", daysAgo: 3)
        let m3 = makeMistake(title: "Q3", subject: "English", daysAgo: 2)
        let result = MistakeFilter.group(mistakes: [m1, m2, m3], searchText: "")
        XCTAssertEqual(result.totalCount, 3)
        XCTAssertEqual(result.bySubject["Math"]?.count, 2)
        XCTAssertEqual(result.bySubject["English"]?.count, 1)
        XCTAssertEqual(result.filteredSubjects.count, 2)
    }

    func test_group_emptySubjectFallsBackToUncategorized() {
        let m1 = makeMistake(title: "Q1", subject: "", daysAgo: 5)
        let result = MistakeFilter.group(mistakes: [m1], searchText: "", uncategorizedKey: "Other")
        XCTAssertNotNil(result.bySubject["Other"])
        XCTAssertNil(result.bySubject[""])
    }

    func test_group_sortsByCountDescThenAlphabetical() {
        let mistakes = [
            makeMistake(title: "Q1", subject: "Math", daysAgo: 1),
            makeMistake(title: "Q2", subject: "Math", daysAgo: 2),
            makeMistake(title: "Q3", subject: "Math", daysAgo: 3),
            makeMistake(title: "Q4", subject: "English", daysAgo: 4),
            makeMistake(title: "Q5", subject: "Physics", daysAgo: 5)
        ]
        let result = MistakeFilter.group(mistakes: mistakes, searchText: "")
        // Math=3, English=1, Physics=1 → Math first, then alphabetical between English/Physics
        XCTAssertEqual(result.sortedSubjects.first, "Math")
        let tail = Array(result.sortedSubjects.suffix(2))
        XCTAssertEqual(tail, ["English", "Physics"])
    }

    func test_group_searchText_filtersBySubject() {
        let mistakes = [
            makeMistake(title: "Q1", subject: "Math", daysAgo: 1),
            makeMistake(title: "Q2", subject: "English", daysAgo: 2)
        ]
        let result = MistakeFilter.group(mistakes: mistakes, searchText: "math")
        XCTAssertEqual(result.filteredSubjects, ["Math"])
    }

    func test_group_searchText_filtersByTitle() {
        let mistakes = [
            makeMistake(title: "Trig question", subject: "Math", daysAgo: 1),
            makeMistake(title: "Verb question", subject: "English", daysAgo: 2)
        ]
        let result = MistakeFilter.group(mistakes: mistakes, searchText: "Trig")
        XCTAssertEqual(result.filteredSubjects, ["Math"])
    }

    // MARK: - searchInSubject

    func test_searchInSubject_emptySearch_sortsByDateDesc() {
        let m1 = makeMistake(title: "Q1", subject: "Math", daysAgo: 1)
        let m2 = makeMistake(title: "Q2", subject: "Math", daysAgo: 5)
        let m3 = makeMistake(title: "Q3", subject: "Math", daysAgo: 3)
        let result = MistakeFilter.searchInSubject([m1, m2, m3], searchText: "")
        // Descending by date: m1 (1 day), m3 (3 days), m2 (5 days)
        XCTAssertEqual(result.map { $0.title }, ["Q1", "Q3", "Q2"])
    }

    func test_searchInSubject_filtersByOriginalQuestion() {
        let m1 = makeMistake(title: "Q1", subject: "Math", originalQuestion: "pythagoras", daysAgo: 1)
        let m2 = makeMistake(title: "Q2", subject: "Math", originalQuestion: "algebra", daysAgo: 2)
        let result = MistakeFilter.searchInSubject([m1, m2], searchText: "PYTH")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Q1")
    }

    func test_searchInSubject_filtersBySource() {
        let m1 = makeMistake(title: "Q1", subject: "Math", source: "Textbook", daysAgo: 1)
        let m2 = makeMistake(title: "Q2", subject: "Math", source: "Worksheet", daysAgo: 2)
        let result = MistakeFilter.searchInSubject([m1, m2], searchText: "Worksheet")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Q2")
    }

    // MARK: - suggestedForReview

    func test_suggestedForReview_ranksRecentFirst() {
        let recent = makeMistake(title: "Recent", subject: "Math", daysAgo: 1)
        let medium = makeMistake(title: "Medium", subject: "Math", daysAgo: 15)
        let old = makeMistake(title: "Old", subject: "Math", daysAgo: 90)
        let result = MistakeFilter.suggestedForReview([old, recent, medium], now: now)
        XCTAssertEqual(result.first?.title, "Recent")
    }

    func test_suggestedForReview_respectsLimit() {
        let mistakes = (1...6).map { i in
            makeMistake(title: "Q\(i)", subject: "Math", daysAgo: i)
        }
        let result = MistakeFilter.suggestedForReview(mistakes, now: now, limit: 4)
        XCTAssertEqual(result.count, 4)
    }
}
