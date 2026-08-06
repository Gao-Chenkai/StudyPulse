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
    // MARK: - 对外 API / Public API

    /// 为某场考试调度考后复盘提醒。/ Schedule the post-exam review reminder.
    /// 触发时间:`(examEndDate ?? examDate) + 1 day` 的 09:00 本地时间。
    /// Trigger: 09:00 local time the day after (examEndDate ?? examDate).
    /// 跳过:已复盘 / 触发时间 ≤ now。/ Skips: already-reviewed and past triggers.
    nonisolated func schedule(for exam: Exam) {
        // 已复盘的不再推 / Skip exams already reviewed.
        guard exam.examReview == nil else {
            logger.debug("跳过已复盘的考试 / Skipping already-reviewed exam: id=\(exam.id.uuidString, privacy: .public)")
            return
        }
        // 触发时间 ≤ now 直接跳过 / Skip if the trigger is already in the past.
        guard let triggerDate = computeTriggerDate(for: exam), triggerDate > Date() else {
            logger.debug("跳过过期触发点 / Skipping past review trigger: id=\(exam.id.uuidString, privacy: .public)")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Review Reminder".localized()
        // 引导用户复盘的 prompt 模板 / Prompt template guiding the review capture.
        content.body = String(
            format: "%@ — fill out your review: what was tested, what went wrong, what you learned, next strategy.".localized(),
            exam.name
        )
        content.sound = .default
        // userInfo 携带 examId,通知点击后路由到对应复盘页
        // userInfo carries examId so a tap routes to its review.
        content.userInfo = ["examId": exam.id.uuidString, "type": "examReview"]

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        // 标识符:ExamReview_<examId> —— 与 Exam_<name>_<day>Days / SRS_ 区分
        // Identifier: ExamReview_<examId>; distinguishable from Exam_<name>_<day>Days / SRS_.
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

    /// 取消某场考试的复盘提醒(已复盘 / 考试被删时调用)/ Cancel the review reminder.
    nonisolated func cancel(for examId: UUID) {
        let identifier = "\(Self.identifierPrefix)\(examId.uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        logger.info("取消复盘通知 / Cancelled exam review notification: id=\(examId.uuidString, privacy: .public)")
    }

    /// 重新调度所有未复盘的考试的通知(启动时调用)/ Reschedule review notifications for all unreviewed exams.
    nonisolated func rescheduleAll(exams: [Exam]) {
        let center = UNUserNotificationCenter.current()
        // 1) 先清空所有 ExamReview_ 前缀的待发通知 / Clear all pending requests with the prefix.
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .filter { $0.identifier.hasPrefix(Self.identifierPrefix) }
                .map { $0.identifier }
            if !ids.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: ids)
                self.logger.info("清空旧的复盘通知 / Removed old exam review notifications: count=\(ids.count, privacy: .public)")
            }
            // 2) 重新调度每场未复盘的考试 / Re-schedule every unreviewed exam.
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

    /// 考前 1–3 天预测为高风险时，在最近一个 20:00 调度一次温和的早睡提醒。
    /// Rebuilds the separate readiness-warning namespace so ordinary exam
    /// review reminders are unaffected.
    nonisolated func rescheduleReadinessWarnings(
        assessments: [ExamDayReadiness],
        now: Date = Date()
    ) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .filter { $0.identifier.hasPrefix(Self.readinessWarningPrefix) }
                .map(\.identifier)
            if !ids.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: ids)
            }

            let calendar = Calendar.current
            var triggerComponents = calendar.dateComponents([.year, .month, .day], from: now)
            triggerComponents.hour = 20
            triggerComponents.minute = 0
            var triggerDate = calendar.date(from: triggerComponents) ?? now
            if triggerDate <= now {
                triggerDate = calendar.date(byAdding: .day, value: 1, to: triggerDate) ?? triggerDate
            }

            for assessment in assessments where assessment.daysRemaining >= 1
                && assessment.daysRemaining <= 3
                && (assessment.riskCategory == .atRisk || assessment.riskCategory == .critical)
            {
                guard triggerDate < assessment.examDate else { continue }
                let content = UNMutableNotificationContent()
                content.title = "examReadiness.notificationTitle".localized()
                content.body = String(
                    format: "examReadiness.notificationBody".localized(),
                    assessment.examName
                )
                content.sound = .default
                content.userInfo = [
                    "examId": assessment.examID.uuidString,
                    "type": "examReadiness"
                ]
                let components = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: triggerDate
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "\(Self.readinessWarningPrefix)\(assessment.examID.uuidString)",
                    content: content,
                    trigger: trigger
                )
                center.add(request) { [logger = self.logger] error in
                    if let error {
                        logger.error("考前状态提醒调度失败 / Failed to schedule readiness warning: \(error.localizedDescription, privacy: .public)")
                    }
                }
            }
        }
    }

    /// 取消所有 ExamReview_ 通知(目前未使用,保留以备调试)/ Cancel all (kept for debugging).
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
    // MARK: - 内部实现 / Private

    /// 通知标识符前缀,与 Exam_<name>_<day>Days / SRS_ 区分 / Identifier prefix.
    nonisolated private static let identifierPrefix = "ExamReview_"
    nonisolated private static let readinessWarningPrefix = "ExamReadiness_"

    /// 算出"考后次日 09:00"的可触发 Date / Compute the trigger date.
    nonisolated private func computeTriggerDate(for exam: Exam) -> Date? {
        // 优先用 examEndDate,没有则用 examDate / Prefer examEndDate; fall back to examDate.
        let baseDate = exam.examEndDate ?? exam.examDate
        guard let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: baseDate) else {
            return nil
        }
        // 重组为次日 09:00 本地时间;Calendar 负责 DST / 跨月等边界
        // Rebuild as next-day 09:00 local time; Calendar handles DST / month rollovers.
        var components = Calendar.current.dateComponents([.year, .month, .day], from: nextDay)
        components.hour = 9
        components.minute = 0
        return Calendar.current.date(from: components)
    }
}
