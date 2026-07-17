//
//  DiaryReminderNotifications.swift
//  StudyPulse
//
//  学习日记每日提醒通知管理器(单例)。
//  Daily diary reminder notification manager (singleton).
//
//  仿照 SRSReviewNotifications 的设计模式:
//  - identifier: `studyPulse.diaryReminder`(单一通知,每天定点触发)
//  - 触发器: UNCalendarNotificationTrigger(repeats: true)
//  - 调度策略: 用户在 DiarySettingsView 切换开关或调整时间时调用 reschedule
//

import Foundation
@preconcurrency import UserNotifications
import os

/// 学习日记每日提醒通知管理器(单例)。
/// Daily diary reminder notification manager (singleton).
final class DiaryReminderNotifications {
    static let shared = DiaryReminderNotifications()

    nonisolated private let logger = Logger(subsystem: "app.StudyPulse.notifications", category: "Diary")
    private init() {}

    // MARK: - Public API

    /// 重新调度每日日记提醒。
    /// 当 enabled=false 时取消已有提醒;当 enabled=true 时按指定小时重建。
    /// Reschedule the daily diary reminder.
    /// Cancels the existing reminder when `enabled` is false; otherwise rebuilds
    /// it at the specified `hour`.
    nonisolated func reschedule(enabled: Bool, hour: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
        center.removeDeliveredNotifications(withIdentifiers: [Self.identifier])

        guard enabled else {
            logger.info("日记提醒已关闭 / Diary reminder disabled")
            return
        }

        let clampedHour = max(0, min(23, hour))
        let content = UNMutableNotificationContent()
        content.title = "Study Diary".localized()
        content.body = "Record today's mood and reflection.".localized()
        content.sound = .default
        content.userInfo = [
            "type": "diaryReminder"
        ]

        var components = DateComponents()
        components.hour = clampedHour
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(identifier: Self.identifier, content: content, trigger: trigger)
        center.add(request) { [logger] error in
            if let error = error {
                logger.error("调度日记提醒失败 / Failed to schedule diary reminder: hour=\(clampedHour, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
            } else {
                logger.info("日记提醒已调度 / Diary reminder scheduled: hour=\(clampedHour, privacy: .public)")
            }
        }
    }

    /// 取消日记提醒(等同 reschedule(enabled: false, hour: _))
    /// Cancel the diary reminder (equivalent to `reschedule(enabled: false, ...)`).
    nonisolated func cancel() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
        center.removeDeliveredNotifications(withIdentifiers: [Self.identifier])
        logger.info("日记提醒已取消 / Diary reminder cancelled")
    }

    // MARK: - Private

    nonisolated private static let identifier = "studyPulse.diaryReminder"
}
