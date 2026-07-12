//
//  MockTaskRepository.swift
//  StudyPulseTests
//
//  TaskRepository 的纯内存 Mock 测试替身。
//  In-memory mock implementation of TaskRepository for unit tests.
//

import Foundation
import SwiftData
@testable import StudyPulse

@MainActor
final class MockTaskRepository: TaskRepository, @unchecked Sendable {
    var taskItems: [TaskItem] = []
    var filteredTaskItems: [TaskItem] = []

    // MARK: - 调用状态追踪

    var loadAllCalledCount = 0
    var addCalledCount = 0
    var updateCalledCount = 0
    var deleteCalledCount = 0
    var setCompletionCalledCount = 0
    var clearAllCalledCount = 0
    var refreshCompletionStatesCalledCount = 0

    init(tasks: [TaskItem] = [], filteredTasks: [TaskItem]? = nil) {
        self.taskItems = tasks
        self.filteredTaskItems = filteredTasks ?? tasks
    }

    func loadAll(context: ModelContext) async {
        loadAllCalledCount += 1
    }

    func add(_ task: TaskItem, syncToReminders: Bool, reminderResult: (calendarItemId: String, calendarId: String)?) {
        addCalledCount += 1
        var t = task
        if let res = reminderResult {
            t.reminderEventId = res.calendarItemId
            t.reminderCalendarId = res.calendarId
        }
        taskItems.insert(t, at: 0)
        filteredTaskItems.insert(t, at: 0)
    }

    func add(_ newTasks: [TaskItem]) {
        addCalledCount += 1
        taskItems.insert(contentsOf: newTasks, at: 0)
        filteredTaskItems.insert(contentsOf: newTasks, at: 0)
    }

    func update(_ task: TaskItem, reminderResult: (calendarItemId: String, calendarId: String)?) {
        updateCalledCount += 1
        var t = task
        if let res = reminderResult {
            t.reminderEventId = res.calendarItemId
            t.reminderCalendarId = res.calendarId
        }
        if let idx = taskItems.firstIndex(where: { $0.id == t.id }) {
            taskItems[idx] = t
        }
        if let idx = filteredTaskItems.firstIndex(where: { $0.id == t.id }) {
            filteredTaskItems[idx] = t
        }
    }

    func delete(_ task: TaskItem) {
        deleteCalledCount += 1
        taskItems.removeAll { $0.id == task.id }
        filteredTaskItems.removeAll { $0.id == task.id }
    }

    func setCompletion(_ taskId: UUID, isCompleted: Bool) {
        setCompletionCalledCount += 1
        if let idx = taskItems.firstIndex(where: { $0.id == taskId }) {
            taskItems[idx].isCompleted = isCompleted
        }
        if let idx = filteredTaskItems.firstIndex(where: { $0.id == taskId }) {
            filteredTaskItems[idx].isCompleted = isCompleted
        }
    }

    func clearAll() -> Int {
        clearAllCalledCount += 1
        let count = taskItems.count
        taskItems.removeAll()
        filteredTaskItems.removeAll()
        return count
    }

    func refreshCompletionStatesFromReminders() {
        refreshCompletionStatesCalledCount += 1
    }
}
