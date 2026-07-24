import Foundation

@MainActor
@Observable
final class CoachViewModel {
    private(set) var goals: [CoachGoal] = []
    private(set) var selectedGoal: CoachGoal?
    private(set) var analysis: CoachAnalysis?
    private(set) var proposal: CoachProposal?
    private(set) var proposals: [CoachProposal] = []
    private(set) var isLoading = false
    var errorMessage: String?

    let container: RepositoryContainer
    @ObservationIgnored private lazy var coordinator = CoachCoordinator(container: container)

    init(container: RepositoryContainer) {
        self.container = container
        CoachCoordinator(container: container).expireStaleProposals()
        selectedGoal = container.coachRepo.goals.first { $0.status == .active }
        proposal = container.coachRepo.proposals.first { $0.status == .pending }
        proposals = container.coachRepo.proposals
        goals = container.coachRepo.goals.sorted { $0.updatedAt > $1.updatedAt }
        if let selectedGoal, !CoachRefreshSignal.isDirty { analysis = container.coachRepo.analyses.first { $0.goalID == selectedGoal.id } }
    }

    func select(_ goal: CoachGoal) {
        selectedGoal = goal
        analysis = container.coachRepo.analyses.first { $0.goalID == goal.id }
        proposal = container.coachRepo.proposals.first { $0.goalID == goal.id && $0.status == .pending }
    }

    func refreshGoals() {
        goals = container.coachRepo.goals.sorted { $0.updatedAt > $1.updatedAt }

        // The summary card represents the single current analysis target. Keep
        // its selection constrained to one active goal even when the repository
        // contains several active goals or the previously selected goal changed
        // status elsewhere.
        let currentGoal = selectedGoal.flatMap { selected in
            goals.first { $0.id == selected.id && $0.status == .active }
        } ?? goals.first { $0.status == .active }
        selectedGoal = currentGoal
        analysis = currentGoal.flatMap { goal in
            container.coachRepo.analyses
                .filter { $0.goalID == goal.id }
                .max(by: { $0.calculatedAt < $1.calculatedAt })
        }
        proposal = currentGoal.flatMap { goal in
            container.coachRepo.proposals.first { $0.goalID == goal.id && $0.status == .pending }
        }
    }

    /// Refresh once per calendar day, or whenever another process marked the
    /// analysis dirty. Background refresh can also have produced a newer result,
    /// so adopt that result before deciding whether another calculation is needed.
    func refreshIfNeeded(now: Date = Date()) async {
        guard let goal = selectedGoal, !isLoading else { return }
        if let latest = container.coachRepo.analyses
            .filter({ $0.goalID == goal.id })
            .max(by: { $0.calculatedAt < $1.calculatedAt }),
           analysis == nil || latest.calculatedAt > analysis!.calculatedAt {
            analysis = latest
        }
        let needsRefresh = CoachRefreshSignal.isDirty || analysis == nil ||
            !Calendar.current.isDate(analysis!.calculatedAt, inSameDayAs: now)
        if needsRefresh { await refresh() }
    }

    @discardableResult
    func createGoal(title: String, subjects: [CoachGoalSubject], targetDate: Date,
                    dailyMinutes: Int, purpose: String, constraints: String,
                    comprehensiveExamID: UUID? = nil) -> CoachGoal {
        let goal = CoachGoal(title: title.isEmpty ? "My study goal" : title, subjects: subjects,
                             comprehensiveExamID: comprehensiveExamID,
                             targetDate: targetDate, dailyAvailableMinutes: dailyMinutes,
                             purpose: purpose, constraints: constraints)
        container.coachRepo.addGoal(goal)
        container.coachRepo.addChat(CoachChat(goalID: goal.id))
        select(goal); refreshGoals()
        return goal
    }

    func updateGoal(_ goal: CoachGoal, title: String, subjects: [CoachGoalSubject], targetDate: Date,
                    dailyMinutes: Int, purpose: String, constraints: String, changeNote: String,
                    comprehensiveExamID: UUID? = nil) {
        var updated = goal
        updated.title = title
        updated.subjects = subjects
        updated.comprehensiveExamID = comprehensiveExamID
        updated.targetDate = targetDate
        updated.dailyAvailableMinutes = dailyMinutes
        updated.purpose = purpose
        updated.constraints = constraints
        updated.version += 1
        updated.updatedAt = Date()
        updated.history.append(CoachGoalVersion(version: updated.version, subjects: subjects,
                                                targetDate: targetDate, dailyAvailableMinutes: dailyMinutes,
                                                createdAt: updated.updatedAt, changeNote: changeNote))
        container.coachRepo.updateGoal(updated)
        select(updated); refreshGoals()
        CoachRefreshSignal.markDirty()
    }

    func setStatus(_ status: CoachGoalStatus, for goal: CoachGoal) {
        var updated = goal; updated.status = status; updated.updatedAt = Date()
        container.coachRepo.updateGoal(updated); refreshGoals()
    }

    func deleteGoal(_ goal: CoachGoal) {
        container.coachRepo.deleteMessages(for: goal.id)
        container.coachRepo.deleteGoal(goal)
        if selectedGoal?.id == goal.id { selectedGoal = goals.first(where: { $0.id != goal.id && $0.status == .active }) }
        refreshGoals()
    }

    func refresh() async {
        guard let goal = selectedGoal else { return }
        isLoading = true; defer { isLoading = false }
        let result = coordinator.analyze(goal: goal)
        analysis = result
        do { proposal = try await coordinator.generateProposal(goal: goal, analysis: result) }
        catch { errorMessage = error.localizedDescription }
        coordinator.expireStaleProposals()
        proposals = container.coachRepo.proposals
    }

    func approveProposal() {
        approveProposal(selectedItems: nil)
    }

    func approveProposal(selectedItems: [CoachPlanItem]?) {
        guard let proposal else { return }
        do { try coordinator.approve(proposal, selectedItemIDs: selectedItems.map { Set($0.map(\.id)) }); self.proposal = nil }
        catch { errorMessage = error.localizedDescription }
        proposals = container.coachRepo.proposals
    }

    func regenerateProposal() async {
        guard let proposal else { return }
        isLoading = true; defer { isLoading = false }
        do { self.proposal = try await coordinator.regenerateProposal(for: proposal) }
        catch { errorMessage = error.localizedDescription }
        proposals = container.coachRepo.proposals
    }

    func rejectProposal() {
        guard let proposal else { return }
        coordinator.reject(proposal); self.proposal = nil
        proposals = container.coachRepo.proposals
    }
}
