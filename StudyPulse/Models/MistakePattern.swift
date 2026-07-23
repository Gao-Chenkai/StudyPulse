import Foundation

nonisolated enum MistakePattern: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case conditionOmission = "condition_omission"
    case conceptConfusion = "concept_confusion"
    case formulaMisuse = "formula_misuse"
    case calculationError = "calculation_error"
    case unitError = "unit_error"
    case incompleteReading = "incomplete_reading"
    case logicJump = "logic_jump"
    case boundaryOmission = "boundary_omission"
    case memoryError = "memory_error"
    case unclearExpression = "unclear_expression"
    case methodSelection = "method_selection"
    case other = "other"

    var id: String { rawValue }
    var titleKey: String { "mistake.pattern.\(rawValue).title" }
    var descriptionKey: String { "mistake.pattern.\(rawValue).description" }
}

nonisolated struct MistakePatternMatch: Equatable, Hashable, Sendable {
    let pattern: MistakePattern
    let confidence: Double
    let evidence: String
}

nonisolated struct MistakePatternAIResult: Codable, Equatable, Hashable, Sendable {
    let patternIDs: [MistakePattern]
    let confidence: Double
    let evidence: String
}

/// User-confirmed state is intentionally kept outside MistakeNote for the MVP.
nonisolated struct MistakePatternUserState: Codable, Equatable, Hashable, Sendable {
    let pattern: MistakePattern?
    let ignored: Bool
    let resolved: Bool

    static func accepted(_ pattern: MistakePattern) -> Self {
        Self(pattern: pattern, ignored: false, resolved: false)
    }

    static let ignoredState = Self(pattern: nil, ignored: true, resolved: false)
    static let resolvedState = Self(pattern: nil, ignored: false, resolved: true)
}

nonisolated struct MistakePatternSummary: Identifiable, Hashable {
    let pattern: MistakePattern
    let count: Int
    let subjects: [String]
    let recentCount: Int
    let riskScore: Double
    let relatedMistakes: [MistakeNote]
    let relatedPatterns: [MistakePattern]

    var id: String { pattern.id }
    var firstDate: Date? { relatedMistakes.map(\.date).min() }
    var latestDate: Date? { relatedMistakes.map(\.date).max() }
    var averageMastery: Double {
        guard !relatedMistakes.isEmpty else { return 0 }
        return relatedMistakes.map(\.masteryScore).reduce(0, +) / Double(relatedMistakes.count)
    }
}
