import Foundation
@preconcurrency import UserNotifications
import os

final class HabitInsightNotifications {
    static let shared = HabitInsightNotifications()
    nonisolated private let logger = Logger(subsystem: "app.StudyPulse.notifications", category: "HabitInsight")
    nonisolated private static let identifier = "studyPulse.habitInsight"
    private init() {}

    nonisolated func reschedule(enabled: Bool, hour: Int, body: String?) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
        center.removeDeliveredNotifications(withIdentifiers: [Self.identifier])
        guard enabled, let body, !body.isEmpty else { return }
        let content = UNMutableNotificationContent()
        content.title = "Today's Best Study Window".localized()
        content.body = body
        content.sound = .default
        content.userInfo = ["type": "habitInsight"]
        var components = DateComponents(); components.hour = max(0, min(23, hour)); components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        center.add(UNNotificationRequest(identifier: Self.identifier, content: content, trigger: trigger)) { [logger] error in
            if let error { logger.error("Habit insight notification failed: \(error.localizedDescription, privacy: .public)") }
        }
    }

    nonisolated func cancel() { reschedule(enabled: false, hour: 7, body: nil) }
}
