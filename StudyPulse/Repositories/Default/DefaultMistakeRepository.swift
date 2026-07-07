//
//  DefaultMistakeRepository.swift
//  StudyPulse
//
//  错题 (MistakeNote) Repository 默认实现。
//  Default MistakeRepository implementation backed by SwiftData.
//

import Foundation
import SwiftData
import SwiftUI
import os

@Observable @MainActor
final class DefaultMistakeRepository: MistakeRepository {
    var mistakeSets: [MistakeNote] = []
    var filteredMistakeSets: [MistakeNote] = []

    @ObservationIgnored
    private var modelContext: ModelContext?

    init() {}

    // MARK: - Lifecycle

    func loadAll(context: ModelContext) async {
        self.modelContext = context
        do {
            let entities = try context.fetch(
                FetchDescriptor<MistakeNoteRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)])
            )
            // 在主 actor 上做 toSnapshot(@Model 不可跨 actor 边界)
            let snap = entities.map { $0.toSnapshot() }
            self.mistakeSets = snap
            recomputeFiltered()
        } catch {
            Log.data.error("DefaultMistakeRepository loadAll failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - CRUD

    func add(_ mistake: MistakeNote) {
        var stored = mistake
        if stored.phaseId == nil {
            stored.phaseId = AppEnvironmentManager.shared.activePhaseId
        }
        if let context = modelContext {
            context.insert(MistakeNoteRecord(from: stored))
            try? context.save()
        }
        mistakeSets.append(stored)
        Log.data.info("MistakeRepository added: title=\(stored.title, privacy: .public) subject=\(stored.subject, privacy: .public) phaseId=\(stored.phaseId?.uuidString ?? "nil", privacy: .public)")
        Log.record(.info, category: "Data", message: "MistakeRepository added: title=\(stored.title) subject=\(stored.subject) phaseId=\(stored.phaseId?.uuidString ?? "nil")")
        recomputeFiltered()
    }

    func add(_ newMistakes: [MistakeNote]) {
        if let context = modelContext {
            for m in newMistakes {
                context.insert(MistakeNoteRecord(from: m))
            }
            try? context.save()
        }
        mistakeSets.append(contentsOf: newMistakes)
        let count = newMistakes.count
        Log.data.info("MistakeRepository batch added: count=\(count, privacy: .public)")
        Log.record(.info, category: "Data", message: "MistakeRepository batch added: count=\(count)")
        recomputeFiltered()
    }

    func update(_ mistake: MistakeNote) {
        if let index = mistakeSets.firstIndex(where: { $0.id == mistake.id }) {
            mistakeSets[index] = mistake
        }
        updateRecord(mistake)
        recomputeFiltered()
    }

    func delete(_ mistake: MistakeNote) {
        SRSReviewNotifications.shared.cancel(for: mistake.id)
        removeRecord(id: mistake.id)
        if let index = mistakeSets.firstIndex(where: { $0.id == mistake.id }) {
            mistakeSets.remove(at: index)
        }
        Log.data.info("MistakeRepository deleted: title=\(mistake.title, privacy: .public)")
        Log.record(.info, category: "Data", message: "MistakeRepository deleted: title=\(mistake.title)")
        recomputeFiltered()
    }

    func delete(at offsets: IndexSet, in set: inout [MistakeNote]) {
        let removed = offsets.map { set[$0] }
        for note in removed {
            removeRecord(id: note.id)
        }
        set.remove(atOffsets: offsets)
        mistakeSets.removeAll { note in removed.contains(where: { $0.id == note.id }) }
        Log.data.info("MistakeRepository batch deleted: \(removed.map(\.title).joined(separator: ", "), privacy: .public)")
        recomputeFiltered()
    }

    @discardableResult
    func clearAll() -> Int {
        guard let context = modelContext else { return 0 }
        let count = mistakeSets.count
        for m in mistakeSets {
            SRSReviewNotifications.shared.cancel(for: m.id)
        }
        do {
            let entities = try context.fetch(FetchDescriptor<MistakeNoteRecord>())
            for entity in entities { context.delete(entity) }
            try context.save()
        } catch {
            Log.data.error("MistakeRepository clearAll failed: \(error.localizedDescription, privacy: .public)")
            return 0
        }
        mistakeSets.removeAll()
        Log.data.warning("MistakeRepository clearAll: count=\(count, privacy: .public)")
        Log.record(.warning, category: "Data", message: "MistakeRepository clearAll: count=\(count)")
        recomputeFiltered()
        return count
    }

    // MARK: - SRS & Mastery

    func updateReviewState(_ mistakeId: UUID, newState: ReviewState?) {
        guard let index = mistakeSets.firstIndex(where: { $0.id == mistakeId }) else {
            Log.data.warning("MistakeRepository updateReviewState: not found id=\(mistakeId.uuidString, privacy: .public)")
            return
        }
        mistakeSets[index].reviewState = newState
        updateRecord(mistakeSets[index])
        Log.data.info("MistakeRepository updateReviewState: id=\(mistakeId.uuidString, privacy: .public) enrolled=\(newState != nil, privacy: .public)")
    }

    func recordExposure(_ mistakeId: UUID) {
        guard let index = mistakeSets.firstIndex(where: { $0.id == mistakeId }) else { return }
        mistakeSets[index].exposureCount += 1
        updateRecord(mistakeSets[index])
    }

    func recordReview(_ mistakeId: UUID, quality: ReviewQuality, now: Date) {
        guard let index = mistakeSets.firstIndex(where: { $0.id == mistakeId }) else {
            Log.data.warning("MistakeRepository recordReview: not found id=\(mistakeId.uuidString, privacy: .public)")
            return
        }
        var note = mistakeSets[index]
        let oldExposure = note.exposureCount
        let result = MasteryAlgorithm.apply(
            oldScore: note.masteryScore,
            exposureCount: oldExposure,
            quality: quality,
            now: now
        )
        note.exposureCount = oldExposure + 1
        note.masteryScore = result.score
        // 限制历史长度(最多 200)
        let maxHistory = 200
        note.masteryHistory.append(result.entry)
        if note.masteryHistory.count > maxHistory {
            note.masteryHistory.removeFirst(note.masteryHistory.count - maxHistory)
        }
        mistakeSets[index] = note
        updateRecord(note)
        Log.data.info("MistakeRepository recordReview: id=\(mistakeId.uuidString, privacy: .public) quality=\(quality.rawValue, privacy: .public) oldScore=\(oldExposure, privacy: .public)->\(result.score, privacy: .public)")
    }

    func recordHandwriting(_ mistakeId: UUID, pngData: Data, quality: ReviewQuality?, now: Date) {
        guard let index = mistakeSets.firstIndex(where: { $0.id == mistakeId }) else {
            Log.data.warning("MistakeRepository recordHandwriting: not found id=\(mistakeId.uuidString, privacy: .public)")
            return
        }
        var note = mistakeSets[index]
        let entry = HandwritingAnswerEntry(
            timestamp: now,
            imageData: pngData,
            quality: quality?.rawValue ?? 0
        )
        note.handwritingHistory.append(entry)
        mistakeSets[index] = note
        updateRecord(note)
        Log.data.info("MistakeRepository recordHandwriting: id=\(mistakeId.uuidString, privacy: .public) bytes=\(pngData.count, privacy: .public) quality=\(quality?.rawValue ?? 0, privacy: .public) total=\(note.handwritingHistory.count, privacy: .public)")
    }

    // MARK: - Internals

    func recomputeFiltered() {
        let activeId = AppEnvironmentManager.shared.activePhaseId
        if let id = activeId {
            filteredMistakeSets = mistakeSets.filter { $0.phaseId == id }
        } else {
            filteredMistakeSets = mistakeSets
        }
    }

    private func removeRecord(id: UUID) {
        guard let context = modelContext else { return }
        do {
            if let entity = try context.fetch(
                FetchDescriptor<MistakeNoteRecord>(predicate: #Predicate { $0.id == id })
            ).first {
                context.delete(entity)
                try context.save()
            }
        } catch {
            Log.data.error("MistakeRepository removeRecord failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func updateRecord(_ note: MistakeNote) {
        guard let context = modelContext else { return }
        do {
            if let entity = try context.fetch(
                FetchDescriptor<MistakeNoteRecord>(predicate: #Predicate { $0.id == note.id })
            ).first {
                let srs = note.reviewState
                entity.title = note.title
                entity.subject = note.subject
                entity.originalQuestion = note.originalQuestion
                entity.source = note.source
                entity.date = note.date
                entity.errorReason = note.errorReason
                entity.wrongSolution = note.wrongSolution
                entity.correctSolution = note.correctSolution
                entity.srsRepetitions = srs?.repetitions ?? 0
                entity.srsEaseFactor = srs?.easeFactor ?? 2.5
                entity.srsIntervalDays = srs?.intervalDays ?? 0
                entity.srsNextReviewDate = srs?.nextReviewDate
                entity.srsLastReviewDate = srs?.lastReviewDate
                entity.srsLapses = srs?.lapses ?? 0
                entity.questionImagesData = note.questionImages
                entity.reasonImagesData = note.reasonImages
                entity.wrongSolutionImagesData = note.wrongSolutionImages
                entity.correctSolutionImagesData = note.correctSolutionImages
                entity.phaseId = note.phaseId
                entity.exposureCount = note.exposureCount
                entity.masteryScore = note.masteryScore
                entity.masteryHistoryData = note.masteryHistory.isEmpty
                    ? nil
                    : try? JSONEncoder().encode(note.masteryHistory)
                entity.handwritingHistoryData = note.handwritingHistory.isEmpty
                    ? nil
                    : try? JSONEncoder().encode(note.handwritingHistory)
                try context.save()
            } else {
                context.insert(MistakeNoteRecord(from: note))
                try context.save()
            }
        } catch {
            Log.data.error("MistakeRepository updateRecord failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
