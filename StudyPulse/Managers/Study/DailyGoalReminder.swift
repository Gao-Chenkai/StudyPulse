//
//  DailyGoalReminder.swift
//  StudyPulse
//
//  每日目标晚间提醒本地通知。
//  Schedules a daily reminder when the user hasn't yet met any
//  of their three daily goals by the configured reminder time.
//
//  仿照 SRSReviewNotifications 模式：
//  - identifier 前缀：DailyGoal_
//  - 触发器：UNCalendarNotificationTrigger
//  - 调度策略：每天首次进入前台时重建当天的提醒；
//    用户达成任一目标后立即取消。
//

import Foundation
@preconcurrency import UserNotifications
import os

final class DailyGoalReminder {
    static let shared = DailyGoalReminder()

    nonisolated private static let identifierPrefix = "DailyGoal_"
    nonisolated private let logger = Logger(subsystem: "app.StudyPulse.notifications", category: "DailyGoal")

    private init() {}

    /// 重建当天的提醒通知（每天首次进入前台或配置变更时调用）。
    /// Schedules (or re-schedules) the daily-goal reminder for *today*.
    nonisolated func reschedule(for date: Date, config: DailyGoalConfig) {
        let center = UNUserNotificationCenter.current()
        cancel()

        guard config.reminderEnabled else {
            logger.info("每日目标提醒已关闭 / Daily goal reminder disabled")
            return
        }

        let cal = Calendar.current
        let today = cal.startOfDay(for: date)
        var comps = cal.dateComponents([.year, .month, .day], from: today)
        comps.hour = config.reminderHour
        comps.minute = config.reminderMinute

        guard let fireDate = cal.date(from: comps), fireDate > Date() else {
            logger.debug("提醒时间已过，今日不再调度 / Reminder time already passed, skipping today")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Daily Goals Reminder".localized()
        content.body = "Don’t break your streak — finish one of today’s goals.".localized()
        content.sound = .default
        content.userInfo = ["type": "dailyGoal"]


        // Capture a local copy to avoid capturing the mutable var in the sendable closure below.
        let scheduledHour = config.reminderHour
        let scheduledMinute = config.reminderMinute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(Self.identifierPrefix)\(today.timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        center.add(request) { error in
            if let error = error {
                self.logger.error("添加每日目标提醒失败 / Failed to add daily goal reminder: \(error.localizedDescription, privacy: .public)")
            } else {
                self.logger.info("已调度每日目标提醒 / Daily goal reminder scheduled for \(scheduledHour, privacy: .public):\(scheduledMinute, privacy: .public)")
            }
        }
    }

    /// 取消所有待发的每日目标提醒。
    nonisolated func cancel() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .filter { $0.identifier.hasPrefix(Self.identifierPrefix) }
                .map { $0.identifier }
            if !ids.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: ids)
                self.logger.info("已取消每日目标提醒 / Cancelled daily goal reminders: count=\(ids.count, privacy: .public)")
            }
        }
    }
}
