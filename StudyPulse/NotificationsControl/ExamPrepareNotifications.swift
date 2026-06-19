//
//  ExamPrepareNotifications.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/4/4.
//

import Foundation
@preconcurrency import UserNotifications

class ExamPrepareNotifications {
    static let shared = ExamPrepareNotifications()
    
    private init() {}
    
    /// Request notification authorization
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("[ERROR] Notification authorization request failed: \(error.localizedDescription)")
            } else {
                print("[OK] Notification authorization status: \(granted ? "granted" : "denied")")
            }
        }
    }
    
    /// Schedule exam countdown notifications
    /// - Parameters:
    ///   - examName: Exam name
    ///   - date: Exam date
    func scheduleNotifications(for examName: String, date: Date) {
        let center = UNUserNotificationCenter.current()
        
        let daysToNotify = [1, 3, 5, 10, 30]
        
        for day in daysToNotify {
            guard let triggerDate = Calendar.current.date(byAdding: .day, value: -day, to: date) else { continue }
            
            if triggerDate < Date() { continue }
            
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
                    print("[ERROR] Failed to schedule (\(day) day before): \(error.localizedDescription)")
                } else {
                    print("[OK] Successfully scheduled: \(day) day before (\(triggerDate))")
                }
            }
        }
    }
    
    /// Cancel all notifications for a specific exam
    func cancelNotifications(for examName: String) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let toRemove = requests.filter { $0.identifier.contains(examName) }
            let ids = toRemove.map { $0.identifier }
            if !ids.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: ids)
                print("[OK] Cancelled \(ids.count) notifications for \(examName)")
            }
        }
    }
}
