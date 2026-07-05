//
//  DefaultTaskRepository.swift
//  StudyPulse
//
//  待办 (TaskItem) Repository 默认实现。
//  Default TaskRepository implementation backed by SwiftData + EKReminder 同步。
//

import Foundation
import SwiftData
import os

@Observable @MainActor
final class DefaultTaskRepository: TaskRepository {
    var taskItems: [TaskItem] = []
    var filteredTaskItems: [TaskItem] = []

    @ObservationIgnored
    private var modelContext: ModelContext?

    init() {}

    // MARK: - Lifecycle

    func loadAll(context: ModelContext) async {
        self.modelContext = context
        do {
            let entities = try context.fetch(
                FetchDescriptor<TaskItemRecord>(sortBy: [SortDescriptor(\.dueDate, order: .forward)])
            )
            self.taskItems = entities.map { $0.toSnapshot() }
            recomputeFiltered()
        } catch {
            Log.data.error("DefaultTaskRepository loadAll failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - CRUD

    func add(_ task: TaskItem, syncToReminders: Bool, reminderResult: (calendarItemId: String, calendarId: String)?) {
        var stored = task
        if syncToReminders, let result = reminderResult {
            stored.reminderEventId = result.calendarItemId
            stored.reminderCalendarId = result.calendarId
        } else if !syncToReminders {
            stored.reminderEventId = nil
            stored.reminderCalendarId = nil
        }
        if stored.phaseId == nil {
            stored.phaseId = AppEnvironmentManager.shared.activePhaseId
        }
        if let context = modelContext {
            context.insert(TaskItemRecord(from: stored))
            try? context.save()
        }
        taskItems.append(stored)
        taskItems.sort { $0.dueDate < $1.dueDate }
        Log.data.info("TaskRepository added: title=\(stored.title, privacy: .public) type=\(stored.type.rawValue, privacy: .public) phaseId=\(stored.phaseId?.uuidString ?? "nil", privacy: .public)")
        Log.record(.info, category: "Data", message: "TaskRepository added: title=\(stored.title) type=\(stored.type.rawValue) phaseId=\(stored.phaseId?.uuidString ?? "nil")")
        recomputeFiltered()
    }

    func add(_ newTasks: [TaskItem]) {
        guard !newTasks.isEmpty else { return }
        let activeId = AppEnvironmentManager.shared.activePhaseId
        let stored: [TaskItem] = newTasks.map { t in
            var s = t
            if s.phaseId == nil { s.phaseId = activeId }
            return s
        }
        if let context = modelContext {
            for t in stored {
                context.insert(TaskItemRecord(from: t))
            }
            try? context.save()
        }
        taskItems.append(contentsOf: stored)
        taskItems.sort { $0.dueDate < $1.dueDate }
        let count = stored.count
        Log.data.info("TaskRepository batch added: count=\(count, privacy: .public)")
        Log.record(.info, category: "Data", message: "TaskRepository batch added: count=\(count)")
        recomputeFiltered()
    }

    func update(_ task: TaskItem, reminderResult: (calendarItemId: String, calendarId: String)?) {
        var stored = task
        if let result = reminderResult {
            stored.reminderEventId = result.calendarItemId
            stored.reminderCalendarId = result.calendarId
        }
        if let index = taskItems.firstIndex(where: { $0.id == stored.id }) {
            taskItems[index] = stored
            taskItems.sort { $0.dueDate < $1.dueDate }
        }
        updateRecord(stored)
        Log.data.info("TaskRepository updated: title=\(stored.title, privacy: .public) id=\(stored.id.uuidString, privacy: .public)")
        Log.record(.info, category: "Data", message: "TaskRepository updated: title=\(stored.title) id=\(stored.id.uuidString)")
    }

    func delete(_ task: TaskItem) {
        let reminderId = task.reminderEventId
        removeRecord(id: task.id)
        if let index = taskItems.firstIndex(where: { $0.id == task.id }) {
            taskItems.remove(at: index)
        }
        if let reminderId = reminderId {
            Task {
                do {
                    _ = try await CalendarManager.shared.removeTaskFromReminders(calendarItemId: reminderId)
                } catch {
                    Log.data.warning("TaskRepository delete: failed to remove system Reminder: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
        Log.data.info("TaskRepository deleted: title=\(task.title, privacy: .public) id=\(task.id.uuidString, privacy: .public)")
        Log.record(.info, category: "Data", message: "TaskRepository deleted: title=\(task.title) id=\(task.id.uuidString)")
        recomputeFiltered()
    }

    func setCompletion(_ taskId: UUID, isCompleted: Bool) {
        guard let index = taskItems.firstIndex(where: { $0.id == taskId }) else {
            Log.data.warning("TaskRepository setCompletion: not found id=\(taskId.uuidString, privacy: .public)")
            return
        }
        var updated = taskItems[index]
        updated.isCompleted = isCompleted
        taskItems[index] = updated
        updateRecord(updated)
        if let reminderId = updated.reminderEventId {
            Task {
                do {
                    _ = try await CalendarManager.shared.setTaskCompletionInReminders(
                        calendarItemId: reminderId,
                        isCompleted: isCompleted
                    )
                } catch {
                    Log.data.warning("TaskRepository setCompletion: failed to sync reminder: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
        Log.data.info("TaskRepository setCompletion: id=\(taskId.uuidString, privacy: .public) completed=\(isCompleted, privacy: .public)")
    }

    @discardableResult
    func clearAll() -> Int {
        guard let context = modelContext else { return 0 }
        let count = taskItems.count
        let reminderIds: [(eventId: String, calendarId: String?)] = taskItems
            .compactMap { task in
                guard let eventId = task.reminderEventId else { return nil }
                return (eventId, task.reminderCalendarId)
            }
        do {
            let entities = try context.fetch(FetchDescriptor<TaskItemRecord>())
            for entity in entities { context.delete(entity) }
            try context.save()
        } catch {
            Log.data.error("TaskRepository clearAll failed: \(error.localizedDescription, privacy: .public)")
            return 0
        }
        taskItems.removeAll()
        if !reminderIds.isEmpty {
            Task {
                var okCount = 0
                for item in reminderIds {
                    do {
                        _ = try await CalendarManager.shared.removeTaskFromReminders(calendarItemId: item.eventId)
                        okCount += 1
                    } catch {
                        Log.data.warning("TaskRepository clearAll: remove Reminder failed: \(error.localizedDescription, privacy: .public)")
                    }
                }
                Log.data.info("TaskRepository clearAll: reminders cleaned ok=\(okCount, privacy: .public) total=\(reminderIds.count, privacy: .public)")
            }
        }
        Log.data.warning("TaskRepository clearAll: count=\(count, privacy: .public)")
        Log.record(.warning, category: "Data", message: "TaskRepository clearAll: count=\(count)")
        recomputeFiltered()
        return count
    }

    // MARK: - Reminders 同步

    func refreshCompletionStatesFromReminders() {
        let tasksToRefresh = taskItems.filter { $0.reminderEventId != nil }
        guard !tasksToRefresh.isEmpty else { return }
        Task {
            var changed = 0
            var cleared = 0
            for task in tasksToRefresh {
                guard let reminderId = task.reminderEventId else { continue }
                do {
                    if let isCompleted = try await CalendarManager.shared.getTaskCompletionFromReminders(calendarItemId: reminderId) {
                        if task.isCompleted != isCompleted {
                            await MainActor.run {
                                if let idx = self.taskItems.firstIndex(where: { $0.id == task.id }) {
                                    self.taskItems[idx].isCompleted = isCompleted
                                    self.updateRecord(self.taskItems[idx])
                                }
                            }
                            changed += 1
                        }
                    } else {
                        await MainActor.run {
                            if let idx = self.taskItems.firstIndex(where: { $0.id == task.id }) {
                                self.taskItems[idx].reminderEventId = nil
                                self.taskItems[idx].reminderCalendarId = nil
                                self.updateRecord(self.taskItems[idx])
                            }
                        }
                        cleared += 1
                    }
                } catch {
                    Log.data.warning("TaskRepository refreshCompletionStates: \(error.localizedDescription, privacy: .public)")
                }
            }
            if changed > 0 || cleared > 0 {
                Log.data.info("TaskRepository refreshCompletionStates: changed=\(changed, privacy: .public) cleared=\(cleared, privacy: .public)")
                Log.record(.info, category: "Data", message: "TaskRepository refreshCompletionStates: changed=\(changed) cleared=\(cleared)")
            }
        }
    }

    // MARK: - Internals

    func recomputeFiltered() {
        let activeId = AppEnvironmentManager.shared.activePhaseId
        if let id = activeId {
            filteredTaskItems = taskItems.filter { $0.phaseId == id }
        } else {
            filteredTaskItems = taskItems
        }
    }

    private func removeRecord(id: UUID) {
        guard let context = modelContext else { return }
        do {
            if let entity = try context.fetch(
                FetchDescriptor<TaskItemRecord>(predicate: #Predicate { $0.id == id })
            ).first {
                context.delete(entity)
                try context.save()
            }
        } catch {
            Log.data.error("TaskRepository removeRecord failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func updateRecord(_ task: TaskItem) {
        guard let context = modelContext else { return }
        do {
            if let entity = try context.fetch(
                FetchDescriptor<TaskItemRecord>(predicate: #Predicate { $0.id == task.id })
            ).first {
                entity.title = task.title
                entity.typeRaw = task.type.rawValue
                entity.dueDate = task.dueDate
                entity.reminderDate = task.reminderDate
                entity.subject = task.subject
                entity.importance = task.importance
                entity.notes = task.notes
                entity.isCompleted = task.isCompleted
                entity.reminderEventId = task.reminderEventId
                entity.reminderCalendarId = task.reminderCalendarId
                entity.createdAt = task.createdAt
                entity.phaseId = task.phaseId
                try context.save()
            } else {
                context.insert(TaskItemRecord(from: task))
                try context.save()
            }
        } catch {
            Log.data.error("TaskRepository updateRecord failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
