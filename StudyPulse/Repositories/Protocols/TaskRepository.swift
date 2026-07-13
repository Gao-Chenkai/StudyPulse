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
/// Task repository protocol.
/// 负责 TaskItem 增删改查、系统 Reminders(EKReminder)同步、SwiftData 持久化。
/// Owns `TaskItem` CRUD, EKReminder sync, and SwiftData persistence.
@MainActor
protocol TaskRepository: AnyObject, Sendable {
    /// 全部待办
    /// All tasks.
    var taskItems: [TaskItem] { get }
    /// 按 active phase 过滤后的待办缓存
    /// Cached tasks filtered by the active phase.
    var filteredTaskItems: [TaskItem] { get }

    // MARK: - Lifecycle
    // MARK: - 生命周期 / Lifecycle

    /// 加载全部待办
    /// Load all tasks.
    func loadAll(context: ModelContext) async

    // MARK: - CRUD
    // MARK: - 增删改查 / CRUD

    /// 新增
    /// Add one task.
    func add(_ task: TaskItem, syncToReminders: Bool, reminderResult: (calendarItemId: String, calendarId: String)?)
    /// 批量新增
    /// Batch add.
    func add(_ newTasks: [TaskItem])
    /// 更新
    /// Update.
    func update(_ task: TaskItem, reminderResult: (calendarItemId: String, calendarId: String)?)
    /// 删除
    /// Delete.
    func delete(_ task: TaskItem)
    /// 切换完成态
    /// Toggle completion.
    func setCompletion(_ taskId: UUID, isCompleted: Bool)
    /// 清空所有
    /// Clear all.
    func clearAll() -> Int

    // MARK: - Reminders 同步
    // MARK: - Reminders 同步 / Reminders sync

    /// 从系统 Reminders 拉取所有绑定任务的完成态,差异写回本地
    /// Pull completion state of all bound tasks from system Reminders;
    /// diff-write back to local.
    func refreshCompletionStatesFromReminders()
}
