//
//  ClimateInterleavingEngine.swift
//  StudyPulse
//

import Foundation

nonisolated enum FlashcardQueueSource: Hashable, Sendable {
    case scheduled
    case earlyContrast(ConceptInterference)
}

nonisolated struct FlashcardQueueItem: Identifiable, Equatable {
    let mistake: MistakeNote
    let source: FlashcardQueueSource

    var id: UUID { mistake.id }
    var isEarlyContrast: Bool {
        if case .earlyContrast = source { return true }
        return false
    }
    var interference: ConceptInterference? {
        if case .earlyContrast(let pair) = source { return pair }
        return nil
    }

    static func scheduled(_ mistake: MistakeNote) -> FlashcardQueueItem {
        FlashcardQueueItem(mistake: mistake, source: .scheduled)
    }
}

/// Builds a stable queue that preserves urgency while avoiding long concept blocks.
nonisolated enum ClimateInterleavingEngine {
    static let rotationWindow = 4

    static func buildQueue(
        due: [MistakeNote],
        allMistakes: [MistakeNote],
        climate: MemoryClimateSnapshot,
        now: Date = Date()
    ) -> [FlashcardQueueItem] {
        guard !due.isEmpty else { return [] }
        let arrangedDue = rotateConcepts(in: due)
        let maximumEarlyCards = min(3, Int(ceil(Double(due.count) * 0.25)))
        guard maximumEarlyCards > 0 else {
            return arrangedDue.map(FlashcardQueueItem.scheduled)
        }

        let dueIDs = Set(due.map(\.id))
        let candidates = allMistakes.filter {
            guard let state = $0.reviewState else { return false }
            return state.nextReviewDate > now && !dueIDs.contains($0.id)
        }
        let thunderPairs = climate.subjects
            .filter { $0.weather == .thunderstorm }
            .flatMap { climate in climate.interferences.map { (climate.subject, $0) } }
        guard !candidates.isEmpty, !thunderPairs.isEmpty else {
            return arrangedDue.map(FlashcardQueueItem.scheduled)
        }

        var result: [FlashcardQueueItem] = []
        var insertedIDs = Set<UUID>()
        var insertedCount = 0

        for dueMistake in arrangedDue {
            result.append(.scheduled(dueMistake))
            guard insertedCount < maximumEarlyCards else { continue }
            let currentConcepts = MemoryClimateEngine.concepts(for: dueMistake)
            guard let match = thunderPairs.first(where: { subject, pair in
                subject.caseInsensitiveCompare(dueMistake.subject) == .orderedSame &&
                currentConcepts.contains {
                    $0.caseInsensitiveCompare(pair.firstConcept) == .orderedSame ||
                    $0.caseInsensitiveCompare(pair.secondConcept) == .orderedSame
                }
            }) else { continue }

            let pair = match.1
            let targetConcept: String
            if currentConcepts.contains(where: { $0.caseInsensitiveCompare(pair.firstConcept) == .orderedSame }) {
                targetConcept = pair.secondConcept
            } else {
                targetConcept = pair.firstConcept
            }
            guard let contrast = candidates
                .filter({ !insertedIDs.contains($0.id) })
                .filter({ $0.subject.caseInsensitiveCompare(dueMistake.subject) == .orderedSame })
                .filter({
                    MemoryClimateEngine.concepts(for: $0).contains {
                        $0.caseInsensitiveCompare(targetConcept) == .orderedSame
                    }
                })
                .sorted(by: stableCandidateOrder)
                .first else { continue }

            result.append(FlashcardQueueItem(mistake: contrast, source: .earlyContrast(pair)))
            insertedIDs.insert(contrast.id)
            insertedCount += 1
        }
        return result
    }

    private static func rotateConcepts(in due: [MistakeNote]) -> [MistakeNote] {
        var remaining = due
        var result: [MistakeNote] = []
        var previousConcepts = Set<String>()

        while !remaining.isEmpty {
            let windowEnd = min(rotationWindow, remaining.count)
            let index = remaining[..<windowEnd].firstIndex { mistake in
                let concepts = Set(MemoryClimateEngine.concepts(for: mistake).map { $0.lowercased() })
                return previousConcepts.isDisjoint(with: concepts)
            } ?? remaining.startIndex
            let selected = remaining.remove(at: index)
            result.append(selected)
            previousConcepts = Set(MemoryClimateEngine.concepts(for: selected).map { $0.lowercased() })
        }
        return result
    }

    private static func stableCandidateOrder(_ lhs: MistakeNote, _ rhs: MistakeNote) -> Bool {
        let leftDate = lhs.reviewState?.nextReviewDate ?? .distantFuture
        let rightDate = rhs.reviewState?.nextReviewDate ?? .distantFuture
        if leftDate != rightDate { return leftDate < rightDate }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
