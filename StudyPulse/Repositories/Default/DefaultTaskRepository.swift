//
//  DefaultTaskRepository.swift
//  StudyPulse
//

import Foundation
import SwiftData
import os

@Observable @MainActor
final class DefaultTaskRepository: TaskRepository, PersistenceExecutorBacked {
    var taskItems: [TaskItem] = []
    var filteredTaskItems: [TaskItem] = []

    @ObservationIgnored private let envManager: AppEnvironmentManager
    @ObservationIgnored private var executor: PersistenceExecutor?
    @ObservationIgnored private var persistenceTail: Task<Void, Never>?
    @ObservationIgnored private var reminderRefreshTask: Task<Void, Never>?

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
            let snapshots = try await executor.fetchTasks()
            let filtered = try await executor.fetchTasks(activePhaseID: envManager.activePhaseId)
            publish(snapshots, filtered: filtered)
        } catch is CancellationError {
            Log.data.debug("TaskRepository load cancelled")
        } catch {
            Log.data.error("TaskRepository load failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func publishStartupSnapshots(_ snapshots: [TaskItem]) {
        publish(snapshots, filtered: snapshots)
    }

    func publishStartupSnapshots(_ snapshots: [TaskItem], filtered: [TaskItem]) {
        publish(snapshots, filtered: filtered)
    }

    func add(
        _ task: TaskItem,
        syncToReminders: Bool,
        reminderResult: (calendarItemId: String, calendarId: String)?
    ) {
        var stored = task
        if syncToReminders, let reminderResult {
            stored.reminderEventId = reminderResult.calendarItemId
            stored.reminderCalendarId = reminderResult.calendarId
        } else if !syncToReminders {
            stored.reminderEventId = nil
            stored.reminderCalendarId = nil
        }
        if stored.phaseId == nil {
            stored.phaseId = envManager.activePhaseId
        }
        add([stored])
    }

    func add(_ newTasks: [TaskItem]) {
        guard !newTasks.isEmpty else { return }
        let activeID = envManager.activePhaseId
        let stored = newTasks.map { task in
            var value = task
            if value.phaseId == nil { value.phaseId = activeID }
            return value
        }
        enqueue { executor in
            try await executor.insertTasks(stored)
            await self.publishFromPersistence(
                (self.taskItems + stored).sorted { $0.dueDate < $1.dueDate },
                executor: executor
            )
        }
    }

    func update(
        _ task: TaskItem,
        reminderResult: (calendarItemId: String, calendarId: String)?
    ) {
        var stored = task
        if let reminderResult {
            stored.reminderEventId = reminderResult.calendarItemId
            stored.reminderCalendarId = reminderResult.calendarId
        }
        persistAndPublish(stored)
    }

    func delete(_ task: TaskItem) {
        enqueue { executor in
            try await executor.deleteTask(id: task.id)
            await self.publishFromPersistence(
                self.taskItems.filter { $0.id != task.id },
                executor: executor
            )
            if let reminderID = task.reminderEventId {
                do {
                    _ = try await CalendarManager.shared.removeTaskFromReminders(
                        calendarItemId: reminderID
                    )
                } catch {
                    Log.data.warning("TaskRepository reminder delete failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    func setCompletion(_ taskId: UUID, isCompleted: Bool) {
        guard var task = taskItems.first(where: { $0.id == taskId }) else { return }
        task.isCompleted = isCompleted
        persistAndPublish(task)
        if let reminderID = task.reminderEventId {
            Task {
                do {
                    _ = try await CalendarManager.shared.setTaskCompletionInReminders(
                        calendarItemId: reminderID,
                        isCompleted: isCompleted
                    )
                } catch {
                    Log.data.warning("TaskRepository completion sync failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    @discardableResult
    func clearAll() -> Int {
        let expectedCount = taskItems.count
        let reminderIDs = taskItems.compactMap(\.reminderEventId)
        enqueue { executor in
            _ = try await executor.deleteAllTasks()
            self.publish([], filtered: [])
            for reminderID in reminderIDs {
                try Task.checkCancellation()
                do {
                    _ = try await CalendarManager.shared.removeTaskFromReminders(
                        calendarItemId: reminderID
                    )
                } catch {
                    Log.data.warning("TaskRepository reminder clear failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
        return expectedCount
    }

    func refreshCompletionStatesFromReminders() {
        reminderRefreshTask?.cancel()
        let values = taskItems.filter { $0.reminderEventId != nil }
        reminderRefreshTask = Task { [weak self] in
            guard let self else { return }
            var updates: [TaskItem] = []
            for var task in values {
                try? Task.checkCancellation()
                guard !Task.isCancelled, let reminderID = task.reminderEventId else { return }
                do {
                    if let completed = try await CalendarManager.shared
                        .getTaskCompletionFromReminders(calendarItemId: reminderID) {
                        if task.isCompleted != completed {
                            task.isCompleted = completed
                            updates.append(task)
                        }
                    } else {
                        task.reminderEventId = nil
                        task.reminderCalendarId = nil
                        updates.append(task)
                    }
                } catch {
                    Log.data.warning("TaskRepository reminder refresh failed: \(error.localizedDescription, privacy: .public)")
                }
            }
            for task in updates {
                self.persistAndPublish(task)
            }
        }
    }

    func reloadFilteredFromSwiftData() async {
        guard let executor else { return }
        do {
            filteredTaskItems = try await executor.fetchTasks(activePhaseID: envManager.activePhaseId)
        } catch is CancellationError {
            Log.data.debug("TaskRepository filtered load cancelled")
        } catch {
            Log.data.error("TaskRepository filtered load failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func flushPendingPersistence() async {
        await persistenceTail?.value
    }

    func cancelPendingPersistence() {
        persistenceTail?.cancel()
        persistenceTail = nil
        reminderRefreshTask?.cancel()
        reminderRefreshTask = nil
    }

    private func persistAndPublish(_ task: TaskItem) {
        enqueue { executor in
            try await executor.upsertTask(task)
            var next = self.taskItems
            if let index = next.firstIndex(where: { $0.id == task.id }) {
                next[index] = task
            } else {
                next.append(task)
            }
            await self.publishFromPersistence(next.sorted { $0.dueDate < $1.dueDate }, executor: executor)
        }
    }

    private func publish(_ snapshots: [TaskItem], filtered: [TaskItem]) {
        taskItems = snapshots
        filteredTaskItems = filtered
    }

    private func publishFromPersistence(
        _ snapshots: [TaskItem],
        executor: PersistenceExecutor
    ) async {
        do {
            let filtered = try await executor.fetchTasks(activePhaseID: envManager.activePhaseId)
            publish(snapshots, filtered: filtered)
        } catch is CancellationError {
            Log.data.debug("TaskRepository filtered refresh cancelled")
        } catch {
            Log.data.error("TaskRepository filtered refresh failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func enqueue(
        _ operation: @escaping @MainActor @Sendable (PersistenceExecutor) async throws -> Void
    ) {
        guard let executor else {
            Log.data.error("TaskRepository persistence executor is not attached")
            return
        }
        let predecessor = persistenceTail
        persistenceTail = Task {
            await predecessor?.value
            guard !Task.isCancelled else { return }
            do {
                try await operation(executor)
            } catch is CancellationError {
                Log.data.debug("TaskRepository mutation cancelled")
            } catch {
                Log.data.error("TaskRepository mutation failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
