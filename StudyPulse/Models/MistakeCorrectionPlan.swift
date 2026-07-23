import Foundation

nonisolated struct MistakeCorrectionDay: Codable, Equatable, Hashable, Identifiable, Sendable {
    let dayIndex: Int
    let date: Date
    let mistakeIDs: [UUID]
    var completedMistakeIDs: Set<UUID>
    var foundIssueInReading: Bool?

    var id: Int { dayIndex }
    var isCompleted: Bool {
        !mistakeIDs.isEmpty && Set(mistakeIDs).isSubset(of: completedMistakeIDs)
    }
}

nonisolated struct MistakeCorrectionPlan: Codable, Equatable, Hashable, Identifiable, Sendable {
    let id: UUID
    let pattern: MistakePattern
    let startedAt: Date
    var days: [MistakeCorrectionDay]
}
