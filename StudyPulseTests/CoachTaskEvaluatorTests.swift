import Foundation
import Testing
@testable import StudyPulse

@MainActor
struct CoachTaskEvaluatorTests {
    @Test
    func testMistakeReviewConditionCompletesAfterReviews() {
        var mistake = MistakeNote(title: "Q", subject: "Math", originalQuestion: "Q", source: "Book", errorReason: "x", wrongSolution: "x", correctSolution: "y")
        mistake.masteryHistory = [MasteryHistoryEntry(timestamp: Date(), score: 0.5, quality: 3)]
        let spec = CoachTaskSpec(startDate: Date().addingTimeInterval(-60), subject: "Math", objective: "Review", stopCondition: CoachStopCondition(kind: .mistakeReviewCount, value: 1), goalID: UUID())
        let result = CoachTaskEvaluator.evaluate(spec: spec, input: CoachTaskEvaluationInput(mistakes: [mistake], sessions: [], now: Date()))
        #expect(result.status == .completed)
        #expect(result.progress == 1)
    }

    @Test
    func testReflectionConditionRequiresCompletedSession() {
        let spec = CoachTaskSpec(startDate: Date().addingTimeInterval(-60), subject: "Math", objective: "Reflect", stopCondition: CoachStopCondition(kind: .studySessionReflection), goalID: UUID())
        let session = StudySession(id: UUID(), startDate: Date(), durationSeconds: 1800, intensity: .steady, completed: true, difficultyAnnotations: [])
        let result = CoachTaskEvaluator.evaluate(spec: spec, input: CoachTaskEvaluationInput(mistakes: [], sessions: [session], now: Date()))
        #expect(result.status == .pending)
    }
}
