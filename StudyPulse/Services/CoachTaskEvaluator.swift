import Foundation

nonisolated struct CoachTaskEvaluationInput: Sendable {
    let mistakes: [MistakeNote]
    let sessions: [StudySession]
    let now: Date
}

enum CoachTaskEvaluator {
    static func evaluate(spec: CoachTaskSpec, input: CoachTaskEvaluationInput) -> CoachTaskEvaluation {
        let condition = spec.stopCondition
        let matchedMistakes = condition.targetIDs.isEmpty ? input.mistakes : input.mistakes.filter { condition.targetIDs.contains($0.id) }
        let progress: Double
        let detail: String
        switch condition.kind {
        case .mistakeReviewCount:
            let count = matchedMistakes.reduce(0) { $0 + $1.masteryHistory.filter { $0.timestamp >= spec.startDate && $0.timestamp <= input.now }.count }
            progress = condition.value > 0 ? Double(count) / condition.value : 1
            detail = "Reviewed (count) of (Int(condition.value)) mistakes."
        case .masteryThreshold:
            let mastery = matchedMistakes.isEmpty ? 0 : matchedMistakes.map(\.masteryScore).reduce(0, +) / Double(matchedMistakes.count)
            progress = condition.value > 0 ? mastery / condition.value : mastery
            detail = String(format: "Mastery %.0f%% of %.0f%%.", mastery * 100, condition.value * 100)
        case .questionCount:
            let count = matchedMistakes.reduce(0) { $0 + $1.masteryHistory.filter { $0.timestamp >= spec.startDate && $0.timestamp <= input.now }.count }
            progress = condition.value > 0 ? Double(count) / condition.value : 1
            detail = "Completed (count) of (Int(condition.value)) practice items."
        case .knowledgePoint:
            let needle = condition.label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let tagged = input.mistakes.filter { mistake in
                !needle.isEmpty && mistake.tags.contains { $0.lowercased() == needle }
            }
            let matched = condition.targetIDs.isEmpty ? tagged : tagged.filter { condition.targetIDs.contains($0.id) }
            let mastery = matched.isEmpty ? 0 : matched.map(\.masteryScore).reduce(0, +) / Double(matched.count)
            progress = matched.isEmpty ? 0 : mastery
            detail = matched.isEmpty ? "No indexed knowledge-point mistakes found." : String(format: "Indexed knowledge point mastery %.0f%%.", mastery * 100)
        case .studySessionReflection:
            let found = input.sessions.contains { $0.completed && $0.startDate >= spec.startDate && !($0.difficultyAnnotations ?? []).isEmpty }
            progress = found ? 1 : 0
            detail = found ? "A completed session has a reflection." : "Complete a study session and add a reflection."
        }
        let clamped = min(1, max(0, progress))
        let status: CoachTaskEvaluationStatus = clamped >= 1 ? .completed : (clamped > 0 ? .inProgress : .pending)
        return CoachTaskEvaluation(status: status, progress: clamped, evaluatedAt: input.now, detail: detail)
    }
}
