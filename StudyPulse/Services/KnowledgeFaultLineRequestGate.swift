//
//  KnowledgeFaultLineRequestGate.swift
//  StudyPulse
//

import Foundation

@MainActor
final class KnowledgeFaultLineRequestGate {
    static let minimumNewMistakes = 5

    private let defaults: UserDefaults
    private let baselineKey: String

    init(
        defaults: UserDefaults = .standard,
        baselineKey: String = "knowledgeFaultLine.aiBaselineMistakeIDs"
    ) {
        self.defaults = defaults
        self.baselineKey = baselineKey
    }

    func shouldAutomaticallyRequest(for mistakes: [MistakeNote]) -> Bool {
        let currentIDs = Set(mistakes.map(\.id))
        guard !currentIDs.isEmpty else { return false }

        guard let storedIDs = defaults.stringArray(forKey: baselineKey) else {
            // Bootstrap existing data once; subsequent app launches are gated.
            return true
        }

        let baseline = Set(storedIDs.compactMap(UUID.init(uuidString:)))
        return currentIDs.subtracting(baseline).count >= Self.minimumNewMistakes
    }

    func markRequestCompleted(for mistakes: [MistakeNote]) {
        let ids = mistakes.map { $0.id.uuidString }
        guard !ids.isEmpty else { return }
        defaults.set(ids, forKey: baselineKey)
    }
}
