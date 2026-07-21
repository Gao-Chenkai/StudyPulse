import Foundation
@preconcurrency import UserNotifications

final class CoachNotifications {
    static let shared = CoachNotifications()
    private let identifier = "studyPulse.coach.daily"
    private init() {}

    nonisolated func reschedule(enabled: Bool, hour: Int, goalID: UUID? = nil) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
        guard enabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "AI Coach".localized()
        content.body = "Your daily learning analysis is ready to review.".localized()
        content.sound = .default
        var userInfo: [AnyHashable: Any] = ["type": "coach"]
        if let goalID { userInfo["goalID"] = goalID.uuidString }
        content.userInfo = userInfo
        var components = DateComponents(); components.hour = max(0, min(23, hour)); components.minute = 0
        center.add(UNNotificationRequest(identifier: identifier, content: content,
                                          trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)))
    }
}
