import XCTest
@testable import StudyPulse

@MainActor
final class CoachViewModelTests: XCTestCase {
    func testGoalEditorDataCanBeUpdatedAndVersioned() {
        let (container, _) = TestRepositoryContainerFactory.makeMockContainer()
        let vm = CoachViewModel(container: container)
        vm.createGoal(title: "Exam", subjects: [CoachGoalSubject(subject: "Math", targetScore: 100)], targetDate: Date().addingTimeInterval(86400), dailyMinutes: 90, purpose: "Improve", constraints: "")
        guard let goal = vm.selectedGoal else { return XCTFail("goal missing") }
        vm.updateGoal(goal, title: "Exam v2", subjects: [CoachGoalSubject(subject: "Math", targetScore: 110), CoachGoalSubject(subject: "English", targetScore: 95)], targetDate: goal.targetDate, dailyMinutes: 120, purpose: "Improve", constraints: "", changeNote: "Added English")
        XCTAssertEqual(vm.selectedGoal?.version, 2)
        XCTAssertEqual(vm.selectedGoal?.subjects.count, 2)
        XCTAssertEqual(vm.selectedGoal?.history.count, 1)
    }
}
