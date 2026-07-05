//
//  ExamReviewNotifications.swift
//  StudyPulse
//
//  考后 24h 内推送"复盘提醒"。
//  Pushes a "post-exam review" reminder within 24h after the exam ends.
//  仿照 ExamPrepareNotifications / SRSReviewNotifications 的设计模式：
//  - identifier 前缀:ExamReview_<examId>(与 Exam_<name>_<day>Days / SRS_ 区分)
//  - 触发器:UNCalendarNotificationTrigger
//  - 调度策略:每次重新计算「该考试应否有复盘通知」,先清空 ExamReview_ 前缀再批量重建
//  - 已填写复盘(exam.examReview != nil) / 触发时间已过 的考试跳过
//
//  Created by Chenkai Gao on 2026/7/5.
//

import Foundation
@preconcurrency import UserNotifications
import os

/// 考后复盘通知管理器(单例)
/// Exam post-review notification manager (singleton).
final class ExamReviewNotifications {
    static let shared = ExamReviewNotifications()

    nonisolated private let logger = Logger(subsystem: "app.StudyPulse.notifications", category: "ExamReview")
    private init() {}

    // MARK: - Public API

    /// 为某场考试调度考后复盘提醒。
    /// Schedule the post-exam review reminder for a single exam.
    ///
    /// 触发时间:`(examEndDate ?? examDate) + 1 day` 的 09:00 本地时间。
    /// 跳过:已复盘 / 触发时间 ≤ now。
    /// Trigger: 09:00 local time the day after (examEndDate ?? examDate).
    /// Skips: already-reviewed exams and past triggers.
    nonisolated func schedule(for exam: Exam) {
        // 已复盘的不再推
        guard exam.examReview == nil else {
            logger.debug("跳过已复盘的考试 / Skipping already-reviewed exam: id=\(exam.id.uuidString, privacy: .public)")
            return
        }

        guard let triggerDate = computeTriggerDate(for: exam), triggerDate > Date() else {
            logger.debug("跳过过期触发点 / Skipping past review trigger: id=\(exam.id.uuidString, privacy: .public)")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Review Reminder".localized()
        content.body = String(
            format: "%@ — fill out your review: what was tested, what went wrong, what you learned, next strategy.".localized(),
            exam.name
        )
        content.sound = .default
        content.userInfo = [
            "examId": exam.id.uuidString,
            "type": "examReview"
        ]

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let identifier = "\(Self.identifierPrefix)\(exam.id.uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { [logger] error in
            if let error = error {
                logger.error("调度复盘通知失败 / Failed to schedule exam review notification: id=\(exam.id.uuidString, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
            } else {
                logger.info("复盘通知调度成功 / Scheduled exam review: id=\(exam.id.uuidString, privacy: .public) triggerDate=\(triggerDate, privacy: .public)")
            }
        }
    }

    /// 取消某场考试的复盘提醒(已复盘 / 考试被删时调用)
    /// Cancel the review reminder for a single exam.
    nonisolated func cancel(for examId: UUID) {
        let identifier = "\(Self.identifierPrefix)\(examId.uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        logger.info("取消复盘通知 / Cancelled exam review notification: id=\(examId.uuidString, privacy: .public)")
    }

    /// 重新调度所有未复盘的考试的通知(启动时调用,处理 phase 切换 / 日期编辑)
    /// Reschedule review notifications for all unreviewed exams.
    /// Called on app launch to handle phase switches / date edits.
    nonisolated func rescheduleAll(exams: [Exam]) {
        let center = UNUserNotificationCenter.current()

        // 1. 先清空所有 ExamReview_ 前缀的待发通知
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .filter { $0.identifier.hasPrefix(Self.identifierPrefix) }
                .map { $0.identifier }
            if !ids.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: ids)
                self.logger.info("清空旧的复盘通知 / Removed old exam review notifications: count=\(ids.count, privacy: .public)")
            }

            // 2. 重新调度每场未复盘的考试
            let now = Date()
            var scheduled = 0
            var skipped = 0
            for exam in exams {
                if exam.examReview != nil {
                    skipped += 1
                    continue
                }
                guard let triggerDate = self.computeTriggerDate(for: exam), triggerDate > now else {
                    skipped += 1
                    continue
                }
                self.schedule(for: exam)
                scheduled += 1
            }
            self.logger.info("复盘通知重调度完成 / Rescheduled exam review notifications: scheduled=\(scheduled, privacy: .public) skipped=\(skipped, privacy: .public)")
        }
    }

    /// 取消所有 ExamReview_ 通知(批量清空用,目前未使用,保留以备调试)
    /// Cancel all exam review notifications. Currently unused, kept for debugging.
    nonisolated func cancelAll() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .filter { $0.identifier.hasPrefix(Self.identifierPrefix) }
                .map { $0.identifier }
            if !ids.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: ids)
                self.logger.info("取消全部复盘通知 / Cancelled all exam review notifications: count=\(ids.count, privacy: .public)")
            }
        }
    }

    // MARK: - Private

    nonisolated private static let identifierPrefix = "ExamReview_"

    /// 算出"考后次日 09:00"的可触发 Date。
    /// Compute the trigger date (09:00 the day after the exam ends).
    nonisolated private func computeTriggerDate(for exam: Exam) -> Date? {
        let baseDate = exam.examEndDate ?? exam.examDate
        guard let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: baseDate) else {
            return nil
        }
        var components = Calendar.current.dateComponents([.year, .month, .day], from: nextDay)
        components.hour = 9
        components.minute = 0
        return Calendar.current.date(from: components)
    }
}
