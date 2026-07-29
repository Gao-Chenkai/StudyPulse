import Foundation
import os

@MainActor
@Observable
final class ExamReversePlannerViewModel {
    enum Phase: Equatable {
        case idle
        case loading
        case success
        case failure
    }

    private(set) var phase: Phase = .idle
    private(set) var goals: [ExamGoal] = []
    private(set) var selectedGoalID: UUID?
    private(set) var currentPlan: ExamPlan?
    private(set) var errorMessage: String?

    private let container: RepositoryContainer

    init(container: RepositoryContainer) {
        self.container = container
        refreshGoals()
    }

    static func makeDefault(container: RepositoryContainer) -> ExamReversePlannerViewModel {
        .init(container: container)
    }

    var selectedGoal: ExamGoal? {
        goals.first { $0.id == selectedGoalID }
    }

    var subjects: [Subject] {
        container.subjectRepo.subjects.filter(\.enabled)
    }

    var isLLMConfigured: Bool {
        container.envManager.llmConfig.isConfigured
    }

    func refreshGoals() {
        goals = container.examPlanRepo.goals.sorted { $0.createdAt > $1.createdAt }
    }

    func saveGoal(_ goal: ExamGoal) {
        container.examPlanRepo.upsertGoal(goal)
        refreshGoals()
        selectedGoalID = goal.id
        currentPlan = container.examPlanRepo.latestPlan(for: goal.id)
        phase = .idle
    }

    func deleteGoal(_ goal: ExamGoal) {
        container.examPlanRepo.deleteGoal(goal)
        refreshGoals()
        if selectedGoalID == goal.id {
            selectedGoalID = goals.first?.id
            currentPlan = selectedGoalID.flatMap { container.examPlanRepo.latestPlan(for: $0) }
        }
    }

    func selectGoal(_ goal: ExamGoal) {
        selectedGoalID = goal.id
        loadLatestPlan(for: goal.id)
        phase = .idle
    }

    func loadLatestPlan(for goalID: UUID) {
        currentPlan = container.examPlanRepo.latestPlan(for: goalID)
    }

    func cancelGeneration() {
        phase = .idle
    }

    func clearError() {
        errorMessage = nil
    }

    func generatePlan(for goal: ExamGoal) async {
        phase = .loading
        errorMessage = nil
        selectedGoalID = goal.id
        do {
            let plan = try await ExamReversePlannerLLM.generate(goal: goal, container: container)
            container.examPlanRepo.upsertPlan(plan)
            currentPlan = plan
            phase = .success
        } catch is CancellationError {
            phase = .idle
        } catch {
            let desc = (error as? LLMError)?.errorDescription ?? error.localizedDescription
            Log.llm.error("ExamReversePlanner 失败: \(desc, privacy: .public)")
            errorMessage = desc
            phase = .failure
        }
    }

    func deletePlan(_ plan: ExamPlan) {
        container.examPlanRepo.deletePlan(plan)
        if currentPlan?.id == plan.id {
            currentPlan = selectedGoalID.flatMap { container.examPlanRepo.latestPlan(for: $0) }
        }
    }
}
