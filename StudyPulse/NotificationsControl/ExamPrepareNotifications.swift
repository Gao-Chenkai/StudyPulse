//
//  ExamPrepareNotifications.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/4/4.
//

import Foundation
import os
@preconcurrency import UserNotifications

class ExamPrepareNotifications {
    static let shared = ExamPrepareNotifications()
    
    private init() {}
    
    /// Request notification authorization
    /// 请求通知授权
    func requestAuthorization() {
        Log.notification.info("开始请求通知授权 / Requesting notification authorization")
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                Log.notification.error("通知授权请求失败 / Notification authorization request failed: \(error.localizedDescription, privacy: .public)")
            } else {
                Log.notification.info("通知授权结果 / Notification authorization: \(granted ? "granted 已授权" : "denied 已拒绝", privacy: .public)")
            }
        }
    }

    /// Schedule exam countdown notifications
    /// - Parameters:
    ///   - examName: Exam name
    ///   - date: Exam date
    /// 为考试调度倒计时通知
    func scheduleNotifications(for examName: String, date: Date) {
        Log.notification.info("开始为考试调度通知 / Scheduling notifications for exam: name=\(examName, privacy: .public) date=\(date, privacy: .public)")
        let center = UNUserNotificationCenter.current()

        let daysToNotify = [1, 3, 5, 10, 30]

        var scheduled = 0
        var skipped = 0
        for day in daysToNotify {
            guard let triggerDate = Calendar.current.date(byAdding: .day, value: -day, to: date) else {
                Log.notification.warning("无法计算触发时间 / Cannot compute trigger date: exam=\(examName, privacy: .public) day=\(day, privacy: .public)")
                continue
            }

            if triggerDate < Date() {
                Log.notification.debug("跳过过期触发点 / Skipping past trigger: exam=\(examName, privacy: .public) day=\(day, privacy: .public) triggerDate=\(triggerDate, privacy: .public)")
                skipped += 1
                continue
            }

            let content = UNMutableNotificationContent()
            content.title = "Exam Countdown".localized()
            content.body = String(format: "%@ - %d day(s) until the exam. Get ready!".localized(), examName, day)
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate),
                repeats: false
            )

            let identifier = "Exam_\(examName)_\(day)Days"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            center.add(request) { error in
                if let error = error {
                    Log.notification.error("调度通知失败 / Failed to schedule \(day, privacy: .public) day before for \(examName, privacy: .public): \(error.localizedDescription, privacy: .public)")
                } else {
                    Log.notification.info("通知调度成功 / Scheduled: exam=\(examName, privacy: .public) day=\(day, privacy: .public) triggerDate=\(triggerDate, privacy: .public)")
                }
            }
            scheduled += 1
        }
        Log.notification.info("考试通知调度完成 / Finished scheduling notifications for \(examName, privacy: .public): scheduled=\(scheduled, privacy: .public) skipped=\(skipped, privacy: .public)")
    }

    /// Cancel all notifications for a specific exam
    /// 取消指定考试的所有通知
    func cancelNotifications(for examName: String) {
        Log.notification.info("开始取消考试通知 / Cancelling notifications for exam: \(examName, privacy: .public)")
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let toRemove = requests.filter { $0.identifier.contains(examName) }
            let ids = toRemove.map { $0.identifier }
            if !ids.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: ids)
                Log.notification.info("已取消考试通知 / Cancelled notifications: exam=\(examName, privacy: .public) count=\(ids.count, privacy: .public)")
            } else {
                Log.notification.debug("没有可取消的通知 / No pending notifications for exam: \(examName, privacy: .public)")
            }
        }
    }
}
