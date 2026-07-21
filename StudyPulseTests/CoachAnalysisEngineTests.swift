import XCTest
@testable import StudyPulse

final class CoachAnalysisEngineTests: XCTestCase {
    func testWeightedMultiSubjectForecastUsesConfiguredWeights() {
        let goal = CoachGoal(title: "Exam", subjects: [
            CoachGoalSubject(subject: "Math", baselineScore: 70, targetScore: 100, weight: 2),
            CoachGoalSubject(subject: "English", baselineScore: 80, targetScore: 100, weight: 1)
        ], targetDate: Date().addingTimeInterval(60 * 86400))
        let analysis = CoachAnalysisEngine.analyze(goal: goal, snapshot: CoachDataSnapshot(grades: [], mistakes: [], tasks: [], exams: []))
        XCTAssertEqual(analysis.weightedPredicted, (70 * 2 + 80) / 3, accuracy: 0.001)
        XCTAssertEqual(analysis.predictions.count, 2)
    }

    func testShortDeadlineAndLargeGapCanRejectGoal() {
        let goal = CoachGoal(title: "Impossible", subjects: [
            CoachGoalSubject(subject: "Math", baselineScore: 60, targetScore: 110, fullScore: 120)
        ], targetDate: Date().addingTimeInterval(2 * 86400))
        let analysis = CoachAnalysisEngine.analyze(goal: goal, snapshot: CoachDataSnapshot(grades: [], mistakes: [], tasks: []))
        XCTAssertEqual(analysis.decision, .notFeasible)
    }

    func testHealthKitIsOptionalInSnapshot() {
        let goal = CoachGoal(title: "Goal", subjects: [CoachGoalSubject(subject: "Math", targetScore: 80)], targetDate: Date().addingTimeInterval(30 * 86400))
        let analysis = CoachAnalysisEngine.analyze(goal: goal, snapshot: CoachDataSnapshot(grades: [], mistakes: [], tasks: [], exams: [], healthDataAvailable: false))
        XCTAssertFalse(analysis.healthDataAvailable)
    }
}
