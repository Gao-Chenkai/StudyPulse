//
//  ExamFilterTests.swift
//  StudyPulseTests
//
//  Unit tests for ExamFilter (Services/ExamFilter.swift).
//  Tests past/upcoming split, week/month/later bucketing, and unregistered exam detection.
//

import XCTest
@testable import StudyPulse

@MainActor
final class ExamFilterTests: XCTestCase {

    // Fixed reference: 2026-06-15 12:00:00 UTC (mid-month, mid-year)
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

    private func makeExam(
        name: String = "Test",
        subject: String = "Math",
        daysFromNow: Int = 0,
        importance: Int = 3
    ) -> Exam {
        let date = Calendar.current.date(byAdding: .day, value: daysFromNow, to: now) ?? now
        return Exam(
            name: name,
            date: date,
            importance: importance,
            subject: subject,
            examName: name,
            masteryDegree: 0
        )
    }

    private func makeComprehensiveExam(
        name: String = "Final",
        daysFromNow: Int = 0,
        importance: Int = 4
    ) -> comprehensiveExam {
        let date = Calendar.current.date(byAdding: .day, value: daysFromNow, to: now) ?? now
        return comprehensiveExam(
            name: name,
            date: date,
            importance: importance,
            subject: ["Math", "English"],
            examName: name,
            masteryDegree: 0
        )
    }

    private func makeGrade(
        subject: String,
        examName: String,
        daysFromNow: Int,
        score: Double = 80
    ) -> Grade {
        let date = Calendar.current.date(byAdding: .day, value: daysFromNow, to: now) ?? now
        return Grade(subject: subject, score: score, date: date, examName: examName)
    }

    // MARK: - mergeAndSort

    func test_mergeAndSort_combinesAndSortsByDate() {
        let s1 = makeExam(name: "S1", daysFromNow: 5)
        let s2 = makeExam(name: "S2", daysFromNow: -3)
        let c1 = makeComprehensiveExam(name: "C1", daysFromNow: 1)
        let items = ExamFilter.mergeAndSort(single: [s1, s2], comprehensive: [c1])
        XCTAssertEqual(items.count, 3)
        let dates = items.map { $0.date }
        XCTAssertEqual(dates, dates.sorted())
    }

    // MARK: - past / upcoming

    func test_pastItems_includesOnlyBeforeTodayStart() {
        let past = makeExam(name: "P", daysFromNow: -3)
        let today = makeExam(name: "T", daysFromNow: 0)
        let future = makeExam(name: "F", daysFromNow: 5)
        let pastItems = ExamFilter.pastItems(from: [.single(past), .single(today), .single(future)], now: now)
        XCTAssertEqual(pastItems.count, 1)
        XCTAssertEqual(pastItems.first?.id, past.id)
    }

    func test_upcomingItems_includesTodayAndFuture() {
        let past = makeExam(name: "P", daysFromNow: -3)
        let today = makeExam(name: "T", daysFromNow: 0)
        let future = makeExam(name: "F", daysFromNow: 5)
        let upcoming = ExamFilter.upcomingItems(from: [.single(past), .single(today), .single(future)], now: now)
        XCTAssertEqual(upcoming.count, 2)
    }

    // MARK: - bucketUpcomingItems

    func test_bucketUpcomingItems_partitionsIntoWeekMonthLater() {
        let in3Days = makeExam(name: "W", daysFromNow: 3)
        let in20Days = makeExam(name: "M", daysFromNow: 20)
        let in60Days = makeExam(name: "L", daysFromNow: 60)
        let items: [ExamItem] = [.single(in3Days), .single(in20Days), .single(in60Days)]
        let buckets = ExamFilter.bucketUpcomingItems(from: items, now: now)
        XCTAssertEqual(buckets.count, 3)
        XCTAssertEqual(buckets[0].items.count, 1)
        XCTAssertEqual(buckets[1].items.count, 1)
        XCTAssertEqual(buckets[2].items.count, 1)
    }

    func test_bucketUpcomingItems_omitsEmptyBuckets() {
        // Only week bucket populated
        let in3Days = makeExam(name: "W", daysFromNow: 3)
        let items: [ExamItem] = [.single(in3Days)]
        let buckets = ExamFilter.bucketUpcomingItems(from: items, now: now)
        XCTAssertEqual(buckets.count, 1)
    }

    func test_bucketUpcomingItems_allPast_returnsEmpty() {
        let past = makeExam(name: "P", daysFromNow: -10)
        let items: [ExamItem] = [.single(past)]
        let buckets = ExamFilter.bucketUpcomingItems(from: items, now: now)
        XCTAssertTrue(buckets.isEmpty)
    }

    // MARK: - examsWithinDays

    func test_examsWithinDays_includesOnlyFutureWithinWindow() {
        let in3 = makeExam(name: "3", daysFromNow: 3)
        let in10 = makeExam(name: "10", daysFromNow: 10)
        let in30 = makeExam(name: "30", daysFromNow: 30)
        let past = makeExam(name: "P", daysFromNow: -1)
        let result = ExamFilter.examsWithinDays(14, exams: [in3, in10, in30, past], now: now)
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.contains(where: { $0.id == in3.id }))
        XCTAssertTrue(result.contains(where: { $0.id == in10.id }))
    }

    // MARK: - unregisteredExams

    func test_unregisteredExams_includesOnlyUnregisteredInWindow() {
        // Window: 3..7 days ago (startDaysAgo = -3, endDaysAgo = -7).
        // Two exams in window; one already registered via grade.
        let e1 = makeExam(name: "MathQuiz", daysFromNow: -5)
        let e2 = makeExam(name: "EnglishQuiz", daysFromNow: -4)
        let g1 = makeGrade(subject: "Math", examName: "MathQuiz", daysFromNow: -5)
        let result = ExamFilter.unregisteredExams(
            startDaysAgo: -3,
            endDaysAgo: -7,
            grades: [g1],
            exams: [e1, e2],
            now: now
        )
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, e2.id)
    }

    func test_unregisteredExams_excludesOutOfWindow() {
        let tooOld = makeExam(name: "TooOld", daysFromNow: -20)
        let tooNew = makeExam(name: "TooNew", daysFromNow: -1)
        let result = ExamFilter.unregisteredExams(
            startDaysAgo: -3,
            endDaysAgo: -7,
            grades: [],
            exams: [tooOld, tooNew],
            now: now
        )
        XCTAssertTrue(result.isEmpty)
    }
}
