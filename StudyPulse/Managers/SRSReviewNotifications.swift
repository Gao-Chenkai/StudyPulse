//
//  SRSReviewNotifications.swift
//  StudyPulse
//
//  错题间隔重复 (Spaced Repetition) 通知管理器
//  根据错题的 nextReviewDate 调度本地通知
//
//  Created by Chenkai Gao on 2026/6/27.
//

import Foundation
@preconcurrency import UserNotifications
import os

/// 错题 SRS 复习通知管理器（单例）
/// 仿照 ExamPrepareNotifications 的设计模式：
/// - identifier 前缀：`SRS_<mistakeId>`（与 Exam_<name>_<day>Days 区分）
/// - 触发器：UNCalendarNotificationTrigger
/// - 调度策略：每次重新计算「该错题应否有通知」，先清空所有 SRS_ 前缀再批量重建
final class SRSReviewNotifications {
    static let shared = SRSReviewNotifications()

    private let logger = Logger(subsystem: "app.StudyPulse.notifications", category: "SRS")
    private init() {}

    // MARK: - Public API

    /// 重新调度所有错题复习通知
    /// - Parameter mistakes: 当前所有错题
    func rescheduleAll(mistakes: [MistakeNote]) {
        let center = UNUserNotificationCenter.current()

        // 1. 先清空所有 SRS_ 前缀的待发通知
        center.getPendingNotificationRequests { requests in
            let srsIds = requests
                .filter { $0.identifier.hasPrefix(Self.identifierPrefix) }
                .map { $0.identifier }
            if !srsIds.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: srsIds)
                self.logger.info("清空旧的 SRS 通知 / Removed old SRS notifications: count=\(srsIds.count, privacy: .public)")
            }

            // 2. 重建每张错题的复习通知
            let now = Date()
            var scheduledCount = 0
            var skippedCount = 0
            for mistake in mistakes {
                guard let state = mistake.reviewState else {
                    skippedCount += 1
                    continue
                }
                // 跳过已过期（今天到期的不重复推）和距离现在很近（< 1 小时）的
                if state.nextReviewDate <= now {
                    skippedCount += 1
                    continue
                }
                self.schedule(mistake: mistake, at: state.nextReviewDate)
                scheduledCount += 1
            }
            self.logger.info("SRS 通知重调度完成 / SRS notifications rescheduled: scheduled=\(scheduledCount, privacy: .public) skipped=\(skippedCount, privacy: .public)")
        }
    }

    /// 取消某张错题的通知（删除错题或关闭 opt-in 时调用）
    /// - Parameter mistakeId: 错题 UUID
    func cancel(for mistakeId: UUID) {
        let identifier = "\(Self.identifierPrefix)\(mistakeId.uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        logger.info("取消错题通知 / Cancelled SRS notification: id=\(mistakeId.uuidString, privacy: .public)")
    }

    /// 取消所有 SRS 通知
    func cancelAll() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let srsIds = requests
                .filter { $0.identifier.hasPrefix(Self.identifierPrefix) }
                .map { $0.identifier }
            if !srsIds.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: srsIds)
                self.logger.info("取消全部 SRS 通知 / Cancelled all SRS notifications: count=\(srsIds.count, privacy: .public)")
            }
        }
    }

    // MARK: - Private

    private static let identifierPrefix = "SRS_"

    private func schedule(mistake: MistakeNote, at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Time to Review".localized()
        let subjectTag = mistake.subject.isEmpty ? "" : "[\(mistake.subject.localized())] "
        content.body = "\(subjectTag)\(mistake.title)"
        content.sound = .default
        content.userInfo = [
            "mistakeId": mistake.id.uuidString,
            "type": "srs"
        ]

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let identifier = "\(Self.identifierPrefix)\(mistake.id.uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { [logger] error in
            if let error = error {
                logger.error("调度 SRS 通知失败 / Failed to schedule SRS notification: id=\(mistake.id.uuidString, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
