//
//  DefaultMistakeRepository.swift
//  StudyPulse
//

import Foundation
import SwiftData
import SwiftUI
import os

@Observable @MainActor
final class DefaultMistakeRepository: MistakeRepository, PersistenceExecutorBacked {
    var mistakeSets: [MistakeNote] = []
    var filteredMistakeSets: [MistakeNote] = []

    @ObservationIgnored private let envManager: AppEnvironmentManager
    @ObservationIgnored private var executor: PersistenceExecutor?
    @ObservationIgnored private var persistenceTail: Task<Void, Never>?
    @ObservationIgnored private var phaseIndex: [UUID: [MistakeNote]] = [:]

    init(envManager: AppEnvironmentManager) {
        self.envManager = envManager
    }

    func attachPersistenceExecutor(_ executor: PersistenceExecutor) {
        self.executor = executor
    }

    func loadAll(context: ModelContext) async {
        if executor == nil {
            executor = PersistenceExecutor(modelContainer: context.container)
        }
        guard let executor else { return }
        await persistenceTail?.value
        do {
            let snapshots = try await executor.fetchMistakes()
            try Task.checkCancellation()
            publish(snapshots)
        } catch is CancellationError {
            Log.data.debug("MistakeRepository load cancelled")
        } catch {
            Log.data.error("MistakeRepository load failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func publishStartupSnapshots(_ snapshots: [MistakeNote]) {
        publish(snapshots)
    }

    func add(_ mistake: MistakeNote) {
        add([mistake])
    }

    func add(_ newMistakes: [MistakeNote]) {
        guard !newMistakes.isEmpty else { return }
        let activeID = envManager.activePhaseId
        let stored = newMistakes.map { note in
            var value = note
            if value.phaseId == nil { value.phaseId = activeID }
            return value
        }
        enqueue { executor in
            try await executor.insertMistakes(stored)
            self.publish((self.mistakeSets + stored).sorted { $0.date > $1.date })
            Log.data.info("MistakeRepository batch persisted: count=\(stored.count, privacy: .public)")
        }
    }

    func update(_ mistake: MistakeNote) {
        persistAndPublish(mistake)
    }

    func delete(_ mistake: MistakeNote) {
        delete(ids: [mistake.id], titles: [mistake.title])
    }

    func delete(at offsets: IndexSet, in set: inout [MistakeNote]) {
        let removed = offsets.compactMap { set.indices.contains($0) ? set[$0] : nil }
        set.remove(atOffsets: offsets)
        delete(ids: Set(removed.map(\.id)), titles: removed.map(\.title))
    }

    @discardableResult
    func clearAll() -> Int {
        let expectedCount = mistakeSets.count
        let ids = mistakeSets.map(\.id)
        enqueue { executor in
            _ = try await executor.deleteAllMistakes()
            for id in ids {
                SRSReviewNotifications.shared.cancel(for: id)
            }
            self.publish([])
        }
        return expectedCount
    }

    func allTags() -> [String] {
        MistakeFilter.allTags(mistakeSets)
    }

    func tagCounts() -> [(tag: String, count: Int)] {
        MistakeFilter.tagCounts(mistakeSets)
    }

    func updateReviewState(_ mistakeId: UUID, newState: ReviewState?) {
        guard var note = mistakeSets.first(where: { $0.id == mistakeId }) else { return }
        note.reviewState = newState
        persistAndPublish(note)
    }

    func recordExposure(_ mistakeId: UUID) {
        guard var note = mistakeSets.first(where: { $0.id == mistakeId }) else { return }
        note.exposureCount += 1
        persistAndPublish(note)
    }

    func recordReview(_ mistakeId: UUID, quality: ReviewQuality, now: Date) {
        guard var note = mistakeSets.first(where: { $0.id == mistakeId }) else { return }
        let result = MasteryAlgorithm.apply(
            oldScore: note.masteryScore,
            exposureCount: note.exposureCount,
            quality: quality,
            now: now
        )
        note.exposureCount += 1
        note.masteryScore = result.score
        note.masteryHistory.append(result.entry)
        if note.masteryHistory.count > 200 {
            note.masteryHistory.removeFirst(note.masteryHistory.count - 200)
        }
        persistAndPublish(note)
    }

    func recordHandwriting(
        _ mistakeId: UUID,
        pngData: Data,
        quality: ReviewQuality?,
        now: Date
    ) {
        guard var note = mistakeSets.first(where: { $0.id == mistakeId }) else { return }
        note.handwritingHistory.append(
            HandwritingAnswerEntry(
                timestamp: now,
                imageData: pngData,
                quality: quality?.rawValue ?? 0
            )
        )
        persistAndPublish(note)
    }

    func recomputeFiltered() {
        if let activeID = envManager.activePhaseId {
            filteredMistakeSets = phaseIndex[activeID] ?? []
        } else {
            filteredMistakeSets = mistakeSets
        }
    }

    func flushPendingPersistence() async {
        await persistenceTail?.value
    }

    func cancelPendingPersistence() {
        persistenceTail?.cancel()
        persistenceTail = nil
    }

    private func persistAndPublish(_ note: MistakeNote) {
        enqueue { executor in
            try await executor.upsertMistake(note)
            var next = self.mistakeSets
            if let index = next.firstIndex(where: { $0.id == note.id }) {
                next[index] = note
            } else {
                next.append(note)
            }
            self.publish(next.sorted { $0.date > $1.date })
        }
    }

    private func delete(ids: Set<UUID>, titles: [String]) {
        guard !ids.isEmpty else { return }
        enqueue { executor in
            try await executor.deleteMistakes(ids: ids)
            for id in ids {
                SRSReviewNotifications.shared.cancel(for: id)
            }
            self.publish(self.mistakeSets.filter { !ids.contains($0.id) })
            Log.data.info("MistakeRepository deleted: \(titles.joined(separator: ", "), privacy: .public)")
        }
    }

    private func publish(_ snapshots: [MistakeNote]) {
        mistakeSets = snapshots
        phaseIndex = Dictionary(grouping: snapshots.compactMap { note in
            note.phaseId.map { ($0, note) }
        }, by: \.0).mapValues { $0.map(\.1) }
        recomputeFiltered()
    }

    private func enqueue(
        _ operation: @escaping @MainActor @Sendable (PersistenceExecutor) async throws -> Void
    ) {
        guard let executor else {
            Log.data.error("MistakeRepository persistence executor is not attached")
            return
        }
        let predecessor = persistenceTail
        persistenceTail = Task {
            await predecessor?.value
            guard !Task.isCancelled else { return }
            do {
                try await operation(executor)
            } catch is CancellationError {
                Log.data.debug("MistakeRepository mutation cancelled")
            } catch {
                Log.data.error("MistakeRepository mutation failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
