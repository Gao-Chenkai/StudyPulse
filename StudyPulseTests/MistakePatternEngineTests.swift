import XCTest
@testable import StudyPulse

final class MistakePatternEngineTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func mistake(subject: String = "数学", dateOffset: Int = 0, reason: String = "忽略了 x > 0 条件", mastery: Double = 0.4, quality: Int = 0, lapses: Int = 0) -> MistakeNote {
        var note = MistakeNote(title: "题目", subject: subject, originalQuestion: "题目", source: "测试", date: now.addingTimeInterval(Double(dateOffset) * 86_400), errorReason: reason, wrongSolution: "错误解法", correctSolution: "正确解法")
        note.masteryScore = mastery
        if quality != 0 { note.masteryHistory = [MasteryHistoryEntry(timestamp: note.date, score: mastery, quality: quality)] }
        if lapses > 0 { note.reviewState = ReviewState(nextReviewDate: now, lapses: lapses) }
        return note
    }

    func testEmptyReasonDoesNotCreateMisleadingPattern() {
        let note = mistake(reason: "", mastery: 0)
        XCTAssertNil(MistakePatternEngine.classify(note))
        XCTAssertTrue(MistakePatternEngine.summaries(from: [note], now: now).isEmpty)
    }

    func testClassifiesConditionOmissionAndAggregatesAcrossSubjects() {
        let summaries = MistakePatternEngine.summaries(from: [mistake(dateOffset: -2), mistake(subject: "物理", dateOffset: -20), mistake(dateOffset: -30)], now: now)
        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summaries[0].pattern, .conditionOmission)
        XCTAssertEqual(summaries[0].count, 3)
        XCTAssertEqual(Set(summaries[0].subjects), ["数学", "物理"])
        XCTAssertEqual(summaries[0].recentCount, 1)
    }

    func testSingleOccurrenceIsNotARecurringPattern() {
        XCTAssertTrue(MistakePatternEngine.summaries(from: [mistake()], now: now).isEmpty)
    }

    func testRepeatedReviewFailureRaisesRisk() {
        let baseline = MistakePatternEngine.summaries(from: [mistake(dateOffset: -30, mastery: 0.8), mistake(subject: "物理", dateOffset: -40, mastery: 0.8)], now: now)[0].riskScore
        let failing = MistakePatternEngine.summaries(from: [mistake(dateOffset: -2, mastery: 0.2, quality: 1, lapses: 2), mistake(subject: "物理", dateOffset: -3, mastery: 0.2, quality: 1, lapses: 1)], now: now)[0].riskScore
        XCTAssertGreaterThan(failing, baseline)
    }

    func testTopMistakesPrioritizesLowMasteryAndLapses() {
        let notes = [mistake(dateOffset: -1, mastery: 0.9), mistake(dateOffset: -2, mastery: 0.1, lapses: 2), mistake(dateOffset: -3, mastery: 0.5)]
        let summary = MistakePatternEngine.summaries(from: notes, now: now)[0]
        XCTAssertEqual(MistakePatternEngine.topMistakes(for: summary, limit: 1).first?.masteryScore, 0.1)
    }

    func testCorrectionPlanCreatesSevenDaysWithThreeDailyItems() {
        let notes = [
            mistake(dateOffset: -1),
            mistake(subject: "物理", dateOffset: -2),
            mistake(subject: "化学", dateOffset: -3)
        ]
        let summary = MistakePatternEngine.summaries(from: notes, now: now)[0]
        let plan = MistakeCorrectionPlanEngine.makePlan(for: summary, now: now)
        XCTAssertEqual(plan.days.count, 7)
        XCTAssertTrue(plan.days.allSatisfy { $0.mistakeIDs.count == 3 })
    }

    func testUserOverrideReclassifiesAndResolvedStateExcludesMistake() {
        let note = mistake(reason: "公式套用错误")
        let override = MistakePatternUserState.accepted(.conditionOmission)
        XCTAssertEqual(MistakePatternEngine.classify(note, userState: override)?.pattern, .conditionOmission)
        let resolved = MistakePatternEngine.summaries(from: [note, note], userStates: [note.id: .resolvedState])
        XCTAssertTrue(resolved.isEmpty)
    }

    @MainActor
    func testParsesStructuredAIResult() {
        let text = "## 错误模式\n{\"pattern_ids\":[\"condition_omission\"],\"confidence\":0.91,\"evidence\":\"忽略 x > 0\"}"
        let result = MistakeAnalysisLLM.parsePatternResult(from: text)
        XCTAssertEqual(result?.patternIDs, [.conditionOmission])
        XCTAssertEqual(result?.confidence, 0.91)
        XCTAssertEqual(result?.evidence, "忽略 x > 0")
    }
}
