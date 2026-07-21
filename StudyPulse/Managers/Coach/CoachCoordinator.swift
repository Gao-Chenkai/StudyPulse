import Foundation

@MainActor
final class CoachCoordinator {
    private let container: RepositoryContainer

    init(container: RepositoryContainer) { self.container = container }

    func snapshot(now: Date = Date()) -> CoachDataSnapshot {
        container.studySessionRepo.refreshFromLegacyJSON()
        let health = HealthKitManager.shared
        let recentMoodEntries = container.diaryRepo.entriesInRange(
            Calendar.current.date(byAdding: .day, value: -7, to: now) ?? .distantPast, now
        )
        let recentAnnotations = snapshotAnnotations(from: container.studySessionRepo.sessions, now: now)
        let psychologicalStability = psychologicalStabilityScore(
            mistakes: container.mistakeRepo.filteredMistakeSets,
            annotations: recentAnnotations,
            moodEntries: recentMoodEntries
        )
        let moodScore = recentMoodEntries.isEmpty ? nil : recentMoodEntries.map { Double($0.moodScore) }.reduce(0, +) / Double(recentMoodEntries.count)
        let energyScore = recentMoodEntries.isEmpty ? nil : recentMoodEntries.map { Double($0.energyScore) }.reduce(0, +) / Double(recentMoodEntries.count)
        let signals = CoachHealthSignals(sleepHours: health.bodyStatus.lastNightSleepHours,
                                         restingHeartRate: health.bodyStatus.restingHeartRate,
                                         respiratoryRate: health.bodyStatus.respiratoryRate,
                                         exerciseMinutes: health.bodyStatus.exerciseMinutesToday,
                                         readinessCategory: health.readiness.category.rawValue,
                                         hrvZScore: health.readiness.zScore,
                                         todayHRV: health.readiness.todayHRV,
                                         latestHeartRate: health.bodyStatus.latestHeartRate,
                                         restorativeSleepHours: health.bodyStatus.restorativeSleepHours,
                                         psychologicalStability: psychologicalStability,
                                         moodScore: moodScore,
                                         energyScore: energyScore)
        return CoachDataSnapshot(
            grades: container.gradeRepo.filteredGrades,
            mistakes: container.mistakeRepo.filteredMistakeSets,
            tasks: container.taskRepo.filteredTaskItems,
            exams: container.examRepo.filteredExamSets,
            sessions: container.studySessionRepo.sessions,
            now: now,
            healthDataAvailable: health.bodyStatus.isUsable || health.readiness.todayHRV != nil,
            healthSignals: signals
        )
    }

    private func snapshotAnnotations(from sessions: [StudySession], now: Date) -> [DifficultyAnnotation] {
        let cutoff = now.addingTimeInterval(-7 * 86_400)
        return sessions.filter { $0.startDate >= cutoff }.flatMap { $0.difficultyAnnotations ?? [] }
    }

    private func psychologicalStabilityScore(mistakes: [MistakeNote], annotations: [DifficultyAnnotation], moodEntries: [DiaryEntry]) -> Double {
        let psychTags: Set<String> = [
            "概念混淆", "计算粗心", "跳步", "审题不清", "思维定势", "逻辑不严密", "考试焦虑", "急躁粗心", "笔误", "遗漏条件",
            "concept confusion", "careless calculation", "skipping steps", "misreading", "fixed thinking", "loose logic", "exam anxiety", "impatience", "slip of pen", "missing condition"
        ]
        let impact = mistakes.reduce(0.0) { total, mistake in
            guard mistake.tags.contains(where: { psychTags.contains($0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)) }) else { return total }
            return total + (1 - mistake.masteryScore)
        }
        let mistakeStability = mistakes.isEmpty ? 1 : max(0, min(1, 1 - impact / Double(mistakes.count)))
        let annotationStability = annotations.isEmpty ? 1 : max(0.2, 1 - Double(annotations.count) * 0.15)
        guard !moodEntries.isEmpty else { return mistakeStability * 0.65 + annotationStability * 0.35 }
        let moodStability = max(0, min(1, (moodEntries.map { Double($0.moodScore) }.reduce(0, +) / Double(moodEntries.count) - 1) / 4))
        return moodStability * 0.4 + mistakeStability * 0.4 + annotationStability * 0.2
    }

    @discardableResult
    func analyze(goal: CoachGoal, now: Date = Date()) -> CoachAnalysis {
        let result = CoachAnalysisEngine.analyze(goal: goal, snapshot: snapshot(now: now))
        container.coachRepo.saveAnalysis(result)
        CoachRefreshSignal.clear()
        return result
    }

    /// Creates a proposal only after the locally computed analysis exists and LLM is explicitly enabled.
    func generateProposal(goal: CoachGoal, analysis: CoachAnalysis) async throws -> CoachProposal {
        let prefs = container.envManager.preferences
        guard prefs.coachEnabled, prefs.llmEnabled else { throw LLMError.notConfigured }
        let proposal = try await CoachLLM.generate(goal: goal, analysis: analysis,
                                                   config: LLMConfig.from(prefs),
                                                   languageCode: prefs.appLanguage)
        container.coachRepo.saveProposal(proposal)
        return proposal
    }

    /// Approves exactly once. Existing Tasks are never modified.
    func approve(_ proposal: CoachProposal, selectedItemIDs: Set<UUID>? = nil) throws {
        guard let current = container.coachRepo.proposal(id: proposal.id), current.status == .pending else { return }
        guard let goal = container.coachRepo.goals.first(where: { $0.id == proposal.goalID }), goal.version == proposal.goalVersion else {
            throw CoachCoordinatorError.staleProposal
        }
        let selectedItems = proposal.items.filter { selectedItemIDs?.contains($0.id) ?? true }
        guard !selectedItems.isEmpty else { throw CoachCoordinatorError.noItemsSelected }
        let tasks = selectedItems.map { item -> TaskItem in
            let stopData = try? JSONEncoder().encode(CoachTaskSpec(
                startDate: item.startDate, subject: item.subject, objective: item.objective,
                stopCondition: item.stopCondition, goalID: proposal.goalID, proposalID: proposal.id,
                evaluation: CoachTaskEvaluation(status: .pending, progress: 0, evaluatedAt: Date(), detail: "Not evaluated yet.")
            ))
            let due = Calendar.current.date(byAdding: .hour, value: 2, to: item.startDate) ?? item.startDate
            return TaskItem(id: UUID(), title: item.title, type: .homework, dueDate: due,
                            reminderDate: item.startDate, subject: item.subject,
                            importance: item.importance, notes: item.objective,
                            coachExecutionData: stopData, coachGoalId: proposal.goalID,
                            coachProposalId: proposal.id)
        }
        container.addTasks(tasks)
        var resolved = current
        resolved.status = .approved
        resolved.resolvedAt = Date()
        container.coachRepo.saveProposal(resolved)
    }

    func regenerateProposal(for proposal: CoachProposal) async throws -> CoachProposal {
        guard let goal = container.coachRepo.goals.first(where: { $0.id == proposal.goalID }),
              let analysis = container.coachRepo.analyses.first(where: { $0.id == proposal.analysisID }) else {
            throw CoachCoordinatorError.staleProposal
        }
        var old = proposal
        old.status = .superseded; old.resolvedAt = Date()
        container.coachRepo.saveProposal(old)
        return try await generateProposal(goal: goal, analysis: analysis)
    }

    func evaluateCoachTasks(now: Date = Date()) {
        container.studySessionRepo.refreshFromLegacyJSON()
        let input = CoachTaskEvaluationInput(mistakes: container.mistakeRepo.mistakeSets,
                                             sessions: container.studySessionRepo.sessions, now: now)
        for task in container.taskRepo.taskItems {
            guard var spec = task.coachExecutionSpec else { continue }
            let evaluation = CoachTaskEvaluator.evaluate(spec: spec, input: input)
            guard spec.evaluation != evaluation else { continue }
            spec.evaluation = evaluation
            var updated = task
            updated.coachExecutionData = try? JSONEncoder().encode(spec)
            if evaluation.status == .completed { updated.isCompleted = true }
            container.taskRepo.update(updated, reminderResult: nil)
        }
    }

    func expireStaleProposals(now: Date = Date()) {
        for proposal in container.coachRepo.proposals where proposal.status == .pending && proposal.expiresAt <= now {
            var expired = proposal
            expired.status = .expired
            expired.resolvedAt = now
            expired.failureReason = "This proposal expired because the learning data changed or it was not confirmed in time."
            container.coachRepo.saveProposal(expired)
        }
    }

    func reject(_ proposal: CoachProposal) {
        guard let current = container.coachRepo.proposal(id: proposal.id), current.status == .pending else { return }
        var resolved = current; resolved.status = .rejected; resolved.resolvedAt = Date()
        container.coachRepo.saveProposal(resolved)
    }
}

enum CoachCoordinatorError: Error, LocalizedError {
    case staleProposal
    case noItemsSelected
    var errorDescription: String? {
        switch self {
        case .staleProposal: return "This Coach proposal belongs to an older goal version."
        case .noItemsSelected: return "Select at least one plan item."
        }
    }
}
