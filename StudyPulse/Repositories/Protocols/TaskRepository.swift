//
//  TaskRepository.swift
//  StudyPulse
//
//  待办 (TaskItem) 域 Repository 协议。
//  Task (homework / reading) domain repository protocol.
//

import Foundation
import SwiftData

/// 待办 Repository 协议。
/// 负责 TaskItem 增删改查、系统 Reminders(EKReminder)同步、SwiftData 持久化。
@MainActor
protocol TaskRepository: AnyObject, Sendable {
    var taskItems: [TaskItem] { get }
    /// 按 active phase 过滤后的待办缓存
    var filteredTaskItems: [TaskItem] { get }

    // MARK: - Lifecycle
    func loadAll(context: ModelContext) async

    // MARK: - CRUD
    func add(_ task: TaskItem, syncToReminders: Bool, reminderResult: (calendarItemId: String, calendarId: String)?)
    func add(_ newTasks: [TaskItem])
    func update(_ task: TaskItem, reminderResult: (calendarItemId: String, calendarId: String)?)
    func delete(_ task: TaskItem)
    func setCompletion(_ taskId: UUID, isCompleted: Bool)
    func clearAll() -> Int

    // MARK: - Reminders 同步
    /// 从系统 Reminders 拉取所有绑定任务的完成态,差异写回本地
    func refreshCompletionStatesFromReminders()
}
