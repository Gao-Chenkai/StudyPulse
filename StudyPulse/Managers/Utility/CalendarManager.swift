//
//  CalendarManager.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//
//  负责两类 EventKit 集成：
//  1. 系统日历 (EKEvent) —— 考试日程沿用
//  2. 系统提醒事项 (EKReminder) —— 作业 / 阅读材料
//

import Foundation
import EventKit

// MARK: - Calendar Manager (日历 + 提醒事项管理器)

/// 日历事件 + 提醒事项管理器 - 处理考试事件的创建和任务提醒的同步
/// 使用 EventKit 框架把考试写入系统日历,把作业 / 阅读材料写入系统提醒事项
class CalendarManager {
    static let shared = CalendarManager()
    private let eventStore = EKEventStore()

    /// Request calendar access
    /// - Returns: Whether the user granted access
    func requestAccess() async throws -> Bool {
        try await eventStore.requestWriteOnlyAccessToEvents()
    }

    /// 请求 Reminders 写权限
    /// Request write access to Reminders.
    ///
    /// iOS 17+ 使用 requestFullAccessToReminders；旧系统回退到 requestAccess(to: .reminder)。
    func requestRemindersAccess() async throws -> Bool {
        if #available(iOS 17.0, *) {
            return try await eventStore.requestFullAccessToReminders()
        } else {
            return try await eventStore.requestAccess(to: .reminder)
        }
    }

    // MARK: - 日历事件（考试）

    /// Add an exam to the system calendar
    /// - Parameters:
    ///   - examName: Exam name
    ///   - subject: Subject name
    ///   - examDate: Exam date
	///   - startTime: Specific start time (nil = all-day event)
    ///   - note: Additional notes (optional)
    /// - Returns: Whether the event was added successfully
    func addExamToCalendar(
        examName: String,
        subject: String,
        examDate: Date,
		startTime: Date? = nil,
		endTime: Date? = nil,
        note: String? = nil
    ) async throws -> Bool {
        let granted = try await requestAccess()
        guard granted else {
            throw CalendarError.accessDenied
        }

		let event = EKEvent(eventStore: eventStore)
		event.title = "Exam: \(examName)"
		event.notes = note ?? "Subject: \(subject)\nFrom StudyPulse"
		let effectiveStart = startTime ?? examDate
		event.startDate = effectiveStart
		if let endTime = endTime, endTime > effectiveStart {
			event.endDate = endTime
		} else {
			event.endDate = Calendar.current.date(byAdding: .hour, value: 2, to: effectiveStart) ?? effectiveStart
		}
		event.isAllDay = (startTime == nil)

		let alarm = EKAlarm(relativeOffset: -86400)
		event.alarms = [alarm]

		event.calendar = eventStore.defaultCalendarForNewEvents

		try eventStore.save(event, span: .thisEvent)
		return true
	}

    /// Remove a previously added exam event
    /// - Parameter eventIdentifier: Event unique identifier
    /// - Returns: Whether the event was removed successfully
    func removeExamFromCalendar(eventIdentifier: String) async throws -> Bool {
        let granted = try await requestAccess()
        guard granted else {
            throw CalendarError.accessDenied
        }

        guard let event = eventStore.event(withIdentifier: eventIdentifier) else {
            return false
        }

        try eventStore.remove(event, span: .thisEvent)
        return true
    }

    // MARK: - 提醒事项（作业 / 阅读材料）

    /// 在系统 Reminders 中创建一条任务。
    /// Create a reminder in the system Reminders app for a homework / reading task.
    /// - Parameters:
    ///   - title: 任务标题
    ///   - dueDate: 截止日期（用作 reminder.dueDateComponents）
    ///   - alarmDate: 提醒时间（用作 EKAlarm 触发时间）
    ///   - notes: 备注
    ///   - subject: 关联科目（写入 notes 头部）
    /// - Returns: 写入成功返回 (calendarItemIdentifier, calendarIdentifier)；失败抛错
    func addTaskToReminders(
        title: String,
        dueDate: Date,
        alarmDate: Date,
        notes: String? = nil,
        subject: String? = nil
    ) async throws -> (calendarItemId: String, calendarId: String) {
        let granted = try await requestRemindersAccess()
        guard granted else {
            throw CalendarError.accessDenied
        }

        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title

        // 备注：把科目前缀写进去（如果提供）
        var composedNotes: [String] = []
        if let subject = subject, !subject.isEmpty {
            composedNotes.append("Subject: \(subject)")
        }
        if let notes = notes, !notes.isEmpty {
            composedNotes.append(notes)
        }
        composedNotes.append("From StudyPulse")
        reminder.notes = composedNotes.joined(separator: "\n")

        // 截止日期
        let dueComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: dueDate
        )
        reminder.dueDateComponents = dueComponents

        // 提醒时间 -> alarm
        let alarm = EKAlarm(absoluteDate: alarmDate)
        reminder.addAlarm(alarm)

        // 默认列表
        reminder.calendar = eventStore.defaultCalendarForNewReminders()

        try eventStore.save(reminder, commit: true)

        // `calendarItemIdentifier` is non-optional String on iOS 13+.
        // `calendar` may be nil if the reminder was never assigned a calendar.
        guard let calendar = reminder.calendar else {
            throw CalendarError.saveFailed
        }
        return (reminder.calendarItemIdentifier, calendar.calendarIdentifier)
    }

    /// 更新已有的 Reminder（用于任务编辑后回写）
    /// Update an existing Reminder (used when a task is edited).
    /// - Parameters:
    ///   - calendarItemId: 之前 addTaskToReminders 返回的 identifier
    ///   - calendarId: 之前 addTaskToReminders 返回的 calendar identifier
    func updateTaskInReminders(
        calendarItemId: String,
        calendarId: String,
        title: String,
        dueDate: Date,
        alarmDate: Date,
        notes: String? = nil,
        subject: String? = nil,
        isCompleted: Bool
    ) async throws -> Bool {
        let granted = try await requestRemindersAccess()
        guard granted else {
            throw CalendarError.accessDenied
        }
        guard let calendar = eventStore.calendar(withIdentifier: calendarId) else {
            return false
        }
        guard let reminder = eventStore.calendarItem(withIdentifier: calendarItemId) as? EKReminder else {
            return false
        }

        reminder.title = title
        var composedNotes: [String] = []
        if let subject = subject, !subject.isEmpty {
            composedNotes.append("Subject: \(subject)")
        }
        if let notes = notes, !notes.isEmpty {
            composedNotes.append(notes)
        }
        composedNotes.append("From StudyPulse")
        reminder.notes = composedNotes.joined(separator: "\n")

        reminder.dueDateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: dueDate
        )

        // 先清掉旧 alarm，再加新的
        if let alarms = reminder.alarms {
            for alarm in alarms {
                reminder.removeAlarm(alarm)
            }
        }
        reminder.addAlarm(EKAlarm(absoluteDate: alarmDate))

        reminder.isCompleted = isCompleted
        reminder.calendar = calendar

        try eventStore.save(reminder, commit: true)
        return true
    }

    /// 删除一条 Reminder
    /// Remove a previously synced Reminder.
    func removeTaskFromReminders(
        calendarItemId: String
    ) async throws -> Bool {
        let granted = try await requestRemindersAccess()
        guard granted else {
            throw CalendarError.accessDenied
        }
        guard let reminder = eventStore.calendarItem(withIdentifier: calendarItemId) as? EKReminder else {
            return false
        }
        try eventStore.remove(reminder, commit: true)
        return true
    }

    /// 切换 Reminder 完成态（仅当 Reminder 仍存在时返回 true；不存在返回 false）
    /// Toggle the completion flag of a Reminder; returns false if the reminder was removed externally.
    func setTaskCompletionInReminders(
        calendarItemId: String,
        isCompleted: Bool
    ) async throws -> Bool {
        let granted = try await requestRemindersAccess()
        guard granted else {
            throw CalendarError.accessDenied
        }
        guard let reminder = eventStore.calendarItem(withIdentifier: calendarItemId) as? EKReminder else {
            return false
        }
        reminder.isCompleted = isCompleted
        try eventStore.save(reminder, commit: true)
        return true
    }

    /// 读取一条 Reminder 的当前完成态。
    /// - Returns: `Bool?` —— Reminder 仍存在则返回其 `isCompleted`;Reminder 已被外部删除则返回 `nil`
    /// Read the current completion flag of a Reminder.
    /// - Returns: `Bool?` — `isCompleted` if the Reminder still exists; `nil` if the Reminder has been deleted externally.
    func getTaskCompletionFromReminders(
        calendarItemId: String
    ) async throws -> Bool? {
        let granted = try await requestRemindersAccess()
        guard granted else {
            throw CalendarError.accessDenied
        }
        guard let reminder = eventStore.calendarItem(withIdentifier: calendarItemId) as? EKReminder else {
            return nil
        }
        return reminder.isCompleted
    }
}

enum CalendarError: LocalizedError {
    case accessDenied
    case saveFailed
    case eventNotFound

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return NSLocalizedString("StudyPulse does not have calendar access. Please enable it in Settings.", comment: "Calendar error: no permission")
        case .saveFailed:
            return NSLocalizedString("Failed to save calendar event.", comment: "Calendar error: save failed")
        case .eventNotFound:
            return NSLocalizedString("Calendar event not found.", comment: "Calendar error: event not found")
        }
    }
}
