//
//  SubjectAggregatorTests.swift
//  StudyPulseTests
//
//  Unit tests for SubjectAggregator (Services/SubjectAggregator.swift).
//  Pure-function tests: group by subject, average, count, recent window, sorted asc.
//

import XCTest
@testable import StudyPulse

@MainActor
final class SubjectAggregatorTests: XCTestCase {

    // MARK: - Helpers

    private func makeGrade(
        subject: String,
        score: Double,
        daysAgo: Int = 0,
        id: UUID = UUID()
    ) -> Grade {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return Grade(
            id: id,
            subject: subject,
            score: score,
            date: date,
            examName: "Exam"
        )
    }

    // MARK: - aggregate()

    func test_aggregate_emptyGrades_returnsEmptyDictionary() {
        let result = SubjectAggregator.aggregate(grades: [])
        XCTAssertTrue(result.isEmpty)
    }

    func test_aggregate_singleSubject_computesAverageAndCount() {
        let g1 = makeGrade(subject: "Math", score: 80, daysAgo: 5)
        let g2 = makeGrade(subject: "Math", score: 90, daysAgo: 2)
        let g3 = makeGrade(subject: "Math", score: 70, daysAgo: 10)
        let result = SubjectAggregator.aggregate(grades: [g1, g2, g3])
        let math = result["Math"]
        XCTAssertNotNil(math)
        XCTAssertEqual(math?.count, 3)
        XCTAssertEqual(math?.average ?? 0, 80, accuracy: 0.0001)
        // sortedAsc must be ascending by date
        let dates = math?.sortedAsc.map { $0.date } ?? []
        XCTAssertEqual(dates, dates.sorted())
    }

    func test_aggregate_multipleSubjects_separatesByKey() {
        let g1 = makeGrade(subject: "Math", score: 85)
        let g2 = makeGrade(subject: "English", score: 92)
        let g3 = makeGrade(subject: "Math", score: 75)
        let result = SubjectAggregator.aggregate(grades: [g1, g2, g3])
        XCTAssertEqual(result["Math"]?.count, 2)
        XCTAssertEqual(result["English"]?.count, 1)
        XCTAssertEqual(result["Math"]?.average ?? 0, 80, accuracy: 0.0001)
        XCTAssertEqual(result["English"]?.average ?? 0, 92, accuracy: 0.0001)
    }

    func test_aggregate_subjectsFilter_excludesOtherSubjects() {
        let grades = [
            makeGrade(subject: "Math", score: 90),
            makeGrade(subject: "English", score: 70),
            makeGrade(subject: "Physics", score: 80)
        ]
        let result = SubjectAggregator.aggregate(
            grades: grades,
            subjects: ["Math", "Physics"]
        )
        XCTAssertNotNil(result["Math"])
        XCTAssertNotNil(result["Physics"])
        XCTAssertNil(result["English"])
    }

    func test_aggregate_recentCount_excludesOldEntries() {
        let recent = makeGrade(subject: "Math", score: 90, daysAgo: 3)
        let old = makeGrade(subject: "Math", score: 70, daysAgo: 60)
        let result = SubjectAggregator.aggregate(
            grades: [recent, old],
            recentDays: 30,
            referenceDate: Date()
        )
        XCTAssertEqual(result["Math"]?.count, 2)
        XCTAssertEqual(result["Math"]?.recentCount, 1)
    }

    func test_aggregate_includeRecentCountFalse_recentCountAlwaysZero() {
        let grades = [makeGrade(subject: "Math", score: 80, daysAgo: 1)]
        let result = SubjectAggregator.aggregate(
            grades: grades,
            includeRecentCount: false
        )
        XCTAssertEqual(result["Math"]?.recentCount, 0)
        XCTAssertEqual(result["Math"]?.count, 1)
    }

    // MARK: - qualifiedAggregates()

    func test_qualifiedAggregates_filtersBelowMinCount() {
        let single = makeGrade(subject: "Math", score: 90)
        let many = [
            makeGrade(subject: "English", score: 70),
            makeGrade(subject: "English", score: 80),
            makeGrade(subject: "English", score: 90)
        ]
        let raw = SubjectAggregator.aggregate(grades: [single] + many)
        let qualified = SubjectAggregator.qualifiedAggregates(raw, minCount: 2)
        XCTAssertNil(qualified["Math"])
        XCTAssertNotNil(qualified["English"])
        XCTAssertEqual(qualified["English"]?.count, 3)
    }

    // MARK: - Statistics helpers

    func test_averageScore_emptyArray_returnsZero() {
        XCTAssertEqual(SubjectAggregator.averageScore(for: []), 0)
    }

    func test_averageScore_basicMean() {
        let grades = [
            makeGrade(subject: "Math", score: 60),
            makeGrade(subject: "Math", score: 80),
            makeGrade(subject: "Math", score: 100)
        ]
        XCTAssertEqual(SubjectAggregator.averageScore(for: grades), 80, accuracy: 0.0001)
    }

    func test_highestScore_returnsMaxScore() {
        let grades = [
            makeGrade(subject: "Math", score: 60),
            makeGrade(subject: "Math", score: 100),
            makeGrade(subject: "Math", score: 80)
        ]
        XCTAssertEqual(SubjectAggregator.highestScore(for: grades), 100, accuracy: 0.0001)
    }
}
