//
//  DefaultRoutineRepository.swift
//  StudyPulse
//
//  例程 (Routine) Repository 默认实现。SwiftData 持久化。
//  Default RoutineRepository implementation backed by SwiftData.
//

import Foundation
import SwiftData
import os

/// 例程 (Routine) Repository 默认实现。SwiftData 持久化。
/// Default RoutineRepository implementation backed by SwiftData.
@Observable @MainActor
final class DefaultRoutineRepository: RoutineRepository {
    /// 全部例程模板
    /// All routine templates.
    var routines: [Routine] = []
    /// 仅 enabled 例程
    /// Enabled-only routines.
    var enabledRoutines: [Routine] {
        routines.filter { $0.enabled }
    }
    /// 按 active phase 过滤后的例程
    /// Routines filtered by the active phase.
    var filteredRoutines: [Routine] = []

    @ObservationIgnored
    private var modelContext: ModelContext?

    init() {}

    // MARK: - Lifecycle
    // MARK: - 生命周期 / Lifecycle

    /// 加载全部例程
    /// Load all routines.
    func loadAll(context: ModelContext) async {
        self.modelContext = context
        do {
            let entities = try context.fetch(
                FetchDescriptor<RoutineRecord>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
            )
            self.routines = entities.map { $0.toSnapshot() }
            recomputeFiltered()
        } catch {
            Log.data.error("DefaultRoutineRepository loadAll failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - CRUD
    // MARK: - 增删改查 / CRUD

    /// 新增例程
    /// Add a routine.
    func add(_ routine: Routine) {
        var stored = routine
        if stored.phaseId == nil {
            stored.phaseId = AppEnvironmentManager.shared.activePhaseId
        }
        if let context = modelContext {
            context.insert(RoutineRecord(from: stored))
            try? context.save()
        }
        routines.append(stored)
        routines.sort { $0.createdAt < $1.createdAt }
        Log.data.info("RoutineRepository added: title=\(stored.title, privacy: .public) type=\(stored.type.rawValue, privacy: .public)")
        Log.record(.info, category: "Data", message: "RoutineRepository added: title=\(stored.title) type=\(stored.type.rawValue)")
        recomputeFiltered()
    }

    func add(_ newRoutines: [Routine]) {
        guard !newRoutines.isEmpty else { return }
        let activeId = AppEnvironmentManager.shared.activePhaseId
        let stored: [Routine] = newRoutines.map { r in
            var s = r
            if s.phaseId == nil { s.phaseId = activeId }
            return s
        }
        if let context = modelContext {
            for r in stored {
                context.insert(RoutineRecord(from: r))
            }
            try? context.save()
        }
        routines.append(contentsOf: stored)
        routines.sort { $0.createdAt < $1.createdAt }
        Log.data.info("RoutineRepository batch added: count=\(stored.count, privacy: .public)")
        Log.record(.info, category: "Data", message: "RoutineRepository batch added: count=\(stored.count)")
        recomputeFiltered()
    }

    func update(_ routine: Routine) {
        if let index = routines.firstIndex(where: { $0.id == routine.id }) {
            routines[index] = routine
            routines.sort { $0.createdAt < $1.createdAt }
        }
        updateRecord(routine)
        Log.data.info("RoutineRepository updated: title=\(routine.title, privacy: .public) id=\(routine.id.uuidString, privacy: .public)")
        Log.record(.info, category: "Data", message: "RoutineRepository updated: title=\(routine.title) id=\(routine.id.uuidString)")
    }

    func delete(_ id: UUID) {
        removeRecord(id: id)
        routines.removeAll { $0.id == id }
        Log.data.info("RoutineRepository deleted: id=\(id.uuidString, privacy: .public)")
        Log.record(.info, category: "Data", message: "RoutineRepository deleted: id=\(id.uuidString)")
        recomputeFiltered()
    }

    func setEnabled(_ id: UUID, enabled: Bool) {
        guard let index = routines.firstIndex(where: { $0.id == id }) else { return }
        routines[index].enabled = enabled
        updateRecord(routines[index])
        Log.data.info("RoutineRepository setEnabled: id=\(id.uuidString, privacy: .public) enabled=\(enabled, privacy: .public)")
    }

    @discardableResult
    func clearAll() -> Int {
        guard let context = modelContext else { return 0 }
        let count = routines.count
        do {
            let entities = try context.fetch(FetchDescriptor<RoutineRecord>())
            for entity in entities { context.delete(entity) }
            try context.save()
        } catch {
            Log.data.error("RoutineRepository clearAll failed: \(error.localizedDescription, privacy: .public)")
            return 0
        }
        routines.removeAll()
        Log.data.warning("RoutineRepository clearAll: count=\(count, privacy: .public)")
        Log.record(.warning, category: "Data", message: "RoutineRepository clearAll: count=\(count)")
        recomputeFiltered()
        return count
    }

    // MARK: - Internals
    // MARK: - 内部工具 / Internals

    /// 重新计算 filteredRoutines
    /// Recompute filteredRoutines from the active phase.
    func recomputeFiltered() {
        let activeId = AppEnvironmentManager.shared.activePhaseId
        if let id = activeId {
            filteredRoutines = routines.filter { $0.phaseId == id }
        } else {
            filteredRoutines = routines
        }
    }

    private func removeRecord(id: UUID) {
        guard let context = modelContext else { return }
        do {
            if let entity = try context.fetch(
                FetchDescriptor<RoutineRecord>(predicate: #Predicate { $0.id == id })
            ).first {
                context.delete(entity)
                try context.save()
            }
        } catch {
            Log.data.error("RoutineRepository removeRecord failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func updateRecord(_ routine: Routine) {
        guard let context = modelContext else { return }
        do {
            if let entity = try context.fetch(
                FetchDescriptor<RoutineRecord>(predicate: #Predicate { $0.id == routine.id })
            ).first {
                entity.title = routine.title
                entity.typeRaw = routine.type.rawValue
                entity.subject = routine.subject
                entity.weekdays = routine.weekdays
                entity.startTime = routine.startTime
                entity.endTime = routine.endTime
                entity.enabled = routine.enabled
                entity.createdAt = routine.createdAt
                entity.phaseId = routine.phaseId
                try context.save()
            } else {
                context.insert(RoutineRecord(from: routine))
                try context.save()
            }
        } catch {
            Log.data.error("RoutineRepository updateRecord failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
