import Foundation
import Testing
@testable import StudyPulse

struct MistakeShelfLifeTests {
    private func makeMistake(date: Date, state: ReviewState? = nil, mastery: Double = 0.6) -> MistakeNote {
        MistakeNote(title: "Q", subject: "Math", originalQuestion: "x", source: "test", date: date,
                    errorReason: "concept", wrongSolution: "wrong", correctSolution: "right",
                    reviewState: state, masteryScore: mastery)
    }

    @Test
    func testFreshMistakeHasUncertainWindowAndRemainingProgress() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let estimate = MistakeShelfLife.estimate(for: makeMistake(date: now), now: now)
        #expect(estimate.status == .fresh)
        #expect(estimate.remainingFraction > 0.9)
        #expect(estimate.expectedForgettingRange.upperBound.timeIntervalSince(estimate.expectedForgettingRange.lowerBound) < 20 * 86_400)
    }

    @Test
    func testLapsedLowMasteryMistakeIsRecurrentlyFailing() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let state = ReviewState(repetitions: 0, intervalDays: 1,
                                nextReviewDate: now.addingTimeInterval(-86_400),
                                lastReviewDate: now.addingTimeInterval(-3 * 86_400), lapses: 2)
        let estimate = MistakeShelfLife.estimate(for: makeMistake(date: now, state: state, mastery: 0.2), now: now)
        #expect(estimate.status == .recurrentlyFailing)
        #expect(estimate.remainingFraction == 0)
    }
}
