//
//  DailyPlanEngineTests.swift
//  StudyPulseTests
//
//  Unit tests for DailyPlanEngine (Services/DailyPlanEngine.swift).
//  Covers pure-function behaviour of "today's top N" aggregation: empty
//  fallback, exam-only, SRS-only, HRV-low recovery, and a multi-signal case
//  with strong subject fallback. All assertions are score / kind based so
//  they are stable across localized strings.
//

import XCTest
@testable import StudyPulse

@MainActor
final class DailyPlanEngineTests: XCTestCase {

    // Fixed reference: 2026-07-09 12:00:00 local
    private let now: Date = {
        var c = DateComponents()
        c.year = 2026
        c.month = 7
        c.day = 9
        c.hour = 12
        c.minute = 0
        c.second = 0
        return Calendar(identifier: .gregorian).date(from: c) ?? Date()
    }()

    private var cal: Calendar { Calendar.current }

    // MARK: - Factories

    private func makeGrade(
        subject: String,
        score: Double,
        daysAgo: Int = 0
    ) -> Grade {
        let date = cal.date(byAdding: .day, value: -daysAgo, to: now) ?? now
        return Grade(
            subject: subject,
            score: score,
            date: date,
            examName: "Exam"
        )
    }

    private func makeMistake(
        subject: String = "Math",
        isDue: Bool = true,
        daysOffset: Int = -1
    ) -> MistakeNote {
        var note = MistakeNote(
            title: "Q",
            subject: subject,
            originalQuestion: "Q?",
            source: "Book",
            date: now,
            errorReason: "calc",
            wrongSolution: "1",
            correctSolution: "2"
        )
        let reviewAt = cal.date(byAdding: .day, value: daysOffset, to: now) ?? now
        note.reviewState = ReviewState(
            repetitions: 1,
            easeFactor: 2.5,
            intervalDays: 1,
            nextReviewDate: isDue ? reviewAt : cal.date(byAdding: .day, value: 7, to: now) ?? now,
            lastReviewDate: nil,
            lapses: 0
        )
        return note
    }

    private func makeExam(
        name: String = "Final",
        subject: String = "Math",
        daysFromNow: Int = 0
    ) -> Exam {
        let date = cal.date(byAdding: .day, value: daysFromNow, to: now) ?? now
        return Exam(
            name: name,
            date: date,
            importance: 5,
            subject: subject,
            examName: "Term",
            masteryDegree: 60
        )
    }

    private func makeTask(
        title: String = "Read chapter 3",
        daysFromNow: Int = 0,
        isCompleted: Bool = false
    ) -> TaskItem {
        let due = cal.date(byAdding: .day, value: daysFromNow, to: now) ?? now
        return TaskItem(
            title: title,
            type: .homework,
            dueDate: due,
            reminderDate: due,
            isCompleted: isCompleted
        )
    }

    private func makeRoutineInstance(
        title: String = "Math review",
        startOffsetMinutes: Int,
        durationMinutes: Int = 60
    ) -> RoutineInstance {
        let start = cal.date(byAdding: .minute, value: startOffsetMinutes, to: now) ?? now
        let end = cal.date(byAdding: .minute, value: startOffsetMinutes + durationMinutes, to: now) ?? now
        return RoutineInstance(
            routineId: UUID(),
            title: title,
            type: .mistakeReview,
            subject: "Math",
            startTime: start,
            endTime: end,
            date: cal.startOfDay(for: now)
        )
    }

    private func makeHRV(category: HRVReadiness.Category) -> HRVReadiness {
        HRVReadiness(
            zScore: category == .low ? -1.5 : 0.0,
            todayHRV: 50,
            baselineMean: 50,
            baselineSampleCount: 30,
            category: category,
            suggestion: ""
        )
    }

    private func emptyContext(
        hrv: HRVReadiness? = nil
    ) -> DailyPlanContext {
        DailyPlanContext(
            grades: [],
            mistakeSets: [],
            examSets: [],
            taskItems: [],
            routineInstances: [],
            hrvReadiness: hrv,
            hrvBodyStatus: nil,
            now: now
        )
    }

    // MARK: - Empty fallback

    func test_emptyContext_returnsPlaceholder() {
        let result = DailyPlanEngine.generate(from: emptyContext(), max: 3)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].kind, .placeholder)
    }

    // MARK: - Exam-only signal

    func test_onlyExamToday_returnsUrgentExamItem() {
        let context = DailyPlanContext(
            grades: [],
            mistakeSets: [],
            examSets: [makeExam(name: "Final", daysFromNow: 0)],
            taskItems: [],
            routineInstances: [],
            hrvReadiness: nil,
            hrvBodyStatus: nil,
            now: now
        )
        let result = DailyPlanEngine.generate(from: context, max: 3)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].kind, .urgentExam)
        XCTAssertGreaterThan(result[0].score, 0)
    }

    // MARK: - SRS-only signal

    func test_onlySRSDue_returnsSrsReviewItem() {
        let context = DailyPlanContext(
            grades: [],
            mistakeSets: [makeMistake(isDue: true), makeMistake(isDue: true)],
            examSets: [],
            taskItems: [],
            routineInstances: [],
            hrvReadiness: nil,
            hrvBodyStatus: nil,
            now: now
        )
        let result = DailyPlanEngine.generate(from: context, max: 3)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].kind, .srsReview)
    }

    func test_noSrsDue_returnsNoSrsItem() {
        let context = DailyPlanContext(
            grades: [],
            mistakeSets: [makeMistake(isDue: false)],
            examSets: [],
            taskItems: [],
            routineInstances: [],
            hrvReadiness: nil,
            hrvBodyStatus: nil,
            now: now
        )
        let result = DailyPlanEngine.generate(from: context, max: 3)
        XCTAssertFalse(result.contains { $0.kind == .srsReview })
    }

    // MARK: - HRV-low recovery signal

    func test_hrvLow_appendsRecoveryItem() {
        let context = DailyPlanContext(
            grades: [],
            mistakeSets: [],
            examSets: [],
            taskItems: [],
            routineInstances: [],
            hrvReadiness: makeHRV(category: .low),
            hrvBodyStatus: nil,
            now: now
        )
        let result = DailyPlanEngine.generate(from: context, max: 3)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].kind, .recovery)
    }

    // MARK: - HRV-high + multi-signal

    func test_excellentHRVWithManySignals_returnsTopThreeByScore() {
        // strong subject (need >= 2 subjects aggregated with high avg)
        let grades: [Grade] = (0..<4).map { _ in
            makeGrade(subject: "Physics", score: 95, daysAgo: 1)
        }
        let exam = makeExam(name: "Midterm", daysFromNow: 1)
        let srs = makeMistake(isDue: true)
        let task = makeTask(title: "Finish lab", daysFromNow: 0)
        let routine = makeRoutineInstance(startOffsetMinutes: -10, durationMinutes: 60)

        let context = DailyPlanContext(
            grades: grades,
            mistakeSets: [srs],
            examSets: [exam],
            taskItems: [task],
            routineInstances: [routine],
            hrvReadiness: makeHRV(category: .excellent),
            hrvBodyStatus: nil,
            now: now
        )
        let result = DailyPlanEngine.generate(from: context, max: 3)
        XCTAssertEqual(result.count, 3)
        // All scores are positive
        for item in result {
            XCTAssertGreaterThan(item.score, 0)
        }
        // Sorted desc
        for i in 0..<(result.count - 1) {
            XCTAssertGreaterThanOrEqual(result[i].score, result[i + 1].score)
        }
    }

    // MARK: - Score formula

    func test_scoreFor_reflectsUrgency() {
        // urgent exam today vs in 7 days
        let today = DailyPlanEngine.scoreFor(kind: .urgentExam, daysFromNow: 0, hrvFactor: 1.0)
        let week = DailyPlanEngine.scoreFor(kind: .urgentExam, daysFromNow: 7, hrvFactor: 1.0)
        XCTAssertGreaterThan(today, week)
    }

    func test_scoreFor_reflectsHRVFactor() {
        let low = DailyPlanEngine.scoreFor(kind: .srsReview, daysFromNow: 0, hrvFactor: 0.6)
        let high = DailyPlanEngine.scoreFor(kind: .srsReview, daysFromNow: 0, hrvFactor: 1.2)
        XCTAssertGreaterThan(high, low)
    }

    func test_hrvFactor_low_isSmallerThanNormal() {
        let context = DailyPlanContext(
            grades: [],
            mistakeSets: [],
            examSets: [],
            taskItems: [],
            routineInstances: [],
            hrvReadiness: makeHRV(category: .low),
            hrvBodyStatus: nil,
            now: now
        )
        let factor = DailyPlanEngine.currentHRVFactor(context: context)
        XCTAssertEqual(factor, 0.6, accuracy: 0.0001)
    }

    // MARK: - Overdue task

    func test_overdueTaskAppearsWithPositiveScore() {
        let context = DailyPlanContext(
            grades: [],
            mistakeSets: [],
            examSets: [],
            taskItems: [makeTask(title: "Late HW", daysFromNow: -2, isCompleted: false)],
            routineInstances: [],
            hrvReadiness: nil,
            hrvBodyStatus: nil,
            now: now
        )
        let result = DailyPlanEngine.generate(from: context, max: 3)
        XCTAssertTrue(result.contains { $0.kind == .overdueTask })
    }

    func test_completedTaskDoesNotAppear() {
        let context = DailyPlanContext(
            grades: [],
            mistakeSets: [],
            examSets: [],
            taskItems: [makeTask(title: "Done", daysFromNow: 0, isCompleted: true)],
            routineInstances: [],
            hrvReadiness: nil,
            hrvBodyStatus: nil,
            now: now
        )
        let result = DailyPlanEngine.generate(from: context, max: 3)
        XCTAssertFalse(result.contains { $0.kind == .overdueTask || $0.kind == .todayTask })
    }

    // MARK: - Routine active / upcoming

    func test_activeRoutineAppears() {
        let context = DailyPlanContext(
            grades: [],
            mistakeSets: [],
            examSets: [],
            taskItems: [],
            routineInstances: [makeRoutineInstance(startOffsetMinutes: -10, durationMinutes: 60)],
            hrvReadiness: nil,
            hrvBodyStatus: nil,
            now: now
        )
        let result = DailyPlanEngine.generate(from: context, max: 3)
        XCTAssertTrue(result.contains { $0.kind == .routineActive })
    }

    func test_upcomingRoutineWithin30MinAppears() {
        let context = DailyPlanContext(
            grades: [],
            mistakeSets: [],
            examSets: [],
            taskItems: [],
            routineInstances: [makeRoutineInstance(startOffsetMinutes: 15, durationMinutes: 60)],
            hrvReadiness: nil,
            hrvBodyStatus: nil,
            now: now
        )
        let result = DailyPlanEngine.generate(from: context, max: 3)
        XCTAssertTrue(result.contains { $0.kind == .routineUpcoming })
    }

    // MARK: - Max cap

    func test_maxCapsResultCount() {
        // Build 5 distinct signals that all rank high
        let exam1 = makeExam(name: "E1", daysFromNow: 0)
        let exam2 = makeExam(name: "E2", daysFromNow: 0)
        let srs = [makeMistake(isDue: true), makeMistake(isDue: true), makeMistake(isDue: true)]
        let task = makeTask(title: "T", daysFromNow: 0)
        let active = makeRoutineInstance(startOffsetMinutes: -5, durationMinutes: 60)
        let context = DailyPlanContext(
            grades: [],
            mistakeSets: srs,
            examSets: [exam1, exam2],
            taskItems: [task],
            routineInstances: [active],
            hrvReadiness: makeHRV(category: .excellent),
            hrvBodyStatus: nil,
            now: now
        )
        let result = DailyPlanEngine.generate(from: context, max: 3)
        XCTAssertEqual(result.count, 3)
    }
}
