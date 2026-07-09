//
//  DefaultRoutineInstanceRepository.swift
//  StudyPulse
//
//  例程实例 (RoutineInstance) Repository 默认实现。SwiftData 持久化。
//  Default RoutineInstanceRepository implementation backed by SwiftData.
//

import Foundation
import SwiftData
import os

@Observable @MainActor
final class DefaultRoutineInstanceRepository: RoutineInstanceRepository {
    var allInstances: [RoutineInstance] = []
    var todayInstances: [RoutineInstance] = []
    var activeInstances: [RoutineInstance] = []

    @ObservationIgnored
    private var modelContext: ModelContext?

    init() {}

    // MARK: - Lifecycle

    func loadAll(context: ModelContext) async {
        self.modelContext = context
        do {
            let entities = try context.fetch(
                FetchDescriptor<RoutineInstanceRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)])
            )
            self.allInstances = entities.map { $0.toSnapshot() }
            recomputeDerived()
        } catch {
            Log.data.error("DefaultRoutineInstanceRepository loadAll failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - CRUD

    @discardableResult
    func spawnIfMissing(_ instance: RoutineInstance) -> Bool {
        // 幂等检查:业务层先查 in-memory,这里再保险一次 SwiftData 查重
        if allInstances.contains(where: { $0.idempotencyKey == instance.idempotencyKey }) {
            return false
        }
        if let context = modelContext {
            // 防御:即便 in-memory 没命中,持久层也查一遍
            let key = instance.idempotencyKey
            let existing = try? context.fetch(
                FetchDescriptor<RoutineInstanceRecord>(predicate: #Predicate { $0.idempotencyKey == key })
            )
            if let existing = existing, !existing.isEmpty {
                return false
            }
            context.insert(RoutineInstanceRecord(from: instance))
            try? context.save()
        }
        allInstances.append(instance)
        allInstances.sort { $0.date > $1.date }
        recomputeDerived()
        Log.data.info("RoutineInstanceRepository spawned: routineId=\(instance.routineId.uuidString, privacy: .public) dateKey=\(instance.dateKey, privacy: .public)")
        Log.record(.info, category: "Data", message: "RoutineInstanceRepository spawned: routineId=\(instance.routineId.uuidString) dateKey=\(instance.dateKey)")
        return true
    }

    func update(_ instance: RoutineInstance) {
        if let index = allInstances.firstIndex(where: { $0.id == instance.id }) {
            allInstances[index] = instance
        }
        updateRecord(instance)
        recomputeDerived()
    }

    func setCompletion(_ id: UUID, isCompleted: Bool) {
        guard let index = allInstances.firstIndex(where: { $0.id == id }) else { return }
        allInstances[index].isCompleted = isCompleted
        allInstances[index].completedAt = isCompleted ? Date() : nil
        updateRecord(allInstances[index])
        Log.data.info("RoutineInstanceRepository setCompletion: id=\(id.uuidString, privacy: .public) completed=\(isCompleted, privacy: .public)")
    }

    func delete(_ id: UUID) {
        removeRecord(id: id)
        allInstances.removeAll { $0.id == id }
        recomputeDerived()
    }

    @discardableResult
    func cleanupStale(olderThanDays days: Int) -> Int {
        guard let context = modelContext else { return 0 }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let cutoffKey = RoutineInstance.dateKeyString(for: cutoff)
        do {
            let entities = try context.fetch(
                FetchDescriptor<RoutineInstanceRecord>(predicate: #Predicate { $0.dateKey < cutoffKey })
            )
            for e in entities { context.delete(e) }
            try context.save()
            allInstances.removeAll { $0.dateKey < cutoffKey }
            recomputeDerived()
            return entities.count
        } catch {
            Log.data.error("RoutineInstanceRepository cleanupStale failed: \(error.localizedDescription, privacy: .public)")
            return 0
        }
    }

    // MARK: - Internals

    func recomputeDerived() {
        let cal = Calendar.current
        let now = Date()
        let todayStart = cal.startOfDay(for: now)
        let todayKey = RoutineInstance.dateKeyString(for: now)
        todayInstances = allInstances.filter { $0.dateKey == todayKey }
        activeInstances = allInstances.filter { inst in
            inst.startTime <= now && inst.endTime > now
        }
        _ = todayStart  // reserved for future date-bucket queries
    }

    private func removeRecord(id: UUID) {
        guard let context = modelContext else { return }
        do {
            if let entity = try context.fetch(
                FetchDescriptor<RoutineInstanceRecord>(predicate: #Predicate { $0.id == id })
            ).first {
                context.delete(entity)
                try context.save()
            }
        } catch {
            Log.data.error("RoutineInstanceRepository removeRecord failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func updateRecord(_ instance: RoutineInstance) {
        guard let context = modelContext else { return }
        do {
            if let entity = try context.fetch(
                FetchDescriptor<RoutineInstanceRecord>(predicate: #Predicate { $0.id == instance.id })
            ).first {
                entity.title = instance.title
                entity.typeRaw = instance.type.rawValue
                entity.subject = instance.subject
                entity.startTime = instance.startTime
                entity.endTime = instance.endTime
                entity.isCompleted = instance.isCompleted
                entity.completedAt = instance.completedAt
                entity.spawnedMistakeCount = instance.spawnedMistakeCount
                try context.save()
            }
        } catch {
            Log.data.error("RoutineInstanceRepository updateRecord failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
