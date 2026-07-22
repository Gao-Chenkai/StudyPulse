import Foundation

nonisolated enum AutopsyLossReason: String, Codable, CaseIterable, Sendable {
    case knowledgeGap, unstableMastery, methodError, calculationError, readingError
    case timeInsufficient, unanswered, expressionIssue, unknown
}
nonisolated enum AutopsyItemSource: String, Codable, Sendable { case aiDraft, userConfirmed, historicalFact }
nonisolated struct ExamAutopsyItem: Identifiable, Codable, Hashable, Sendable {
    var id: UUID = UUID(); var questionNumber = ""; var question = ""; var userAnswer = ""; var correctAnswer = ""
    var points: Double?; var knowledgePoints: [String] = []; var behavior = ""; var reason: AutopsyLossReason = .unknown
    var evidence = ""; var confidence: Double = 0; var source: AutopsyItemSource = .aiDraft; var isConfirmed = false; var repairSuggestion = ""
}
nonisolated struct ExamAutopsyReport: Codable, Hashable, Sendable {
    var conclusion = ""; var reasonCounts: [String: Int] = [:]; var keyProblems: [String] = []; var historicalFacts: [String] = []; var generatedAt = Date()
}
nonisolated struct ExamAutopsy: Identifiable, Codable, Hashable, Sendable {
    var id: UUID = UUID(); var examId: UUID; var subject: String; var paperImages: [Data] = []; var items: [ExamAutopsyItem] = []; var report: ExamAutopsyReport?
    var updatedAt = Date(); var isAnalyzing = false; var lastError: String?; var importedMistakeIds: [UUID] = []; var importedTaskIds: [UUID] = []
}
