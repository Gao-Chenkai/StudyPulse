import Foundation
@preconcurrency import UserNotifications

final class BrainUsageNotifications {
    static let shared = BrainUsageNotifications()
    private let center = UNUserNotificationCenter.current()
    private init() {}

    func evaluate(snapshot: BrainUsageSnapshot, preferences: BrainUsagePreferences, now: Date = Date()) {
        evaluate(window: snapshot.fiveHour, enabled: preferences.notifyFiveHour, prefix: "BrainUsage_5h_", interval: BrainUsageEngine.fiveHourInterval, now: now)
        evaluate(window: snapshot.sevenDay, enabled: preferences.notifySevenDay, prefix: "BrainUsage_7d_", interval: BrainUsageEngine.sevenDayInterval, now: now)
    }

    private func evaluate(window: BrainUsageWindow, enabled: Bool, prefix: String, interval: TimeInterval, now: Date) {
        guard enabled, window.isComplete else { return }
        let period = Int(floor(now.timeIntervalSince1970 / interval))
        let key = prefix + String(period)
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        let content = UNMutableNotificationContent()
        content.title = "Brain Usage Goal Reached".localized()
        content.body = "Your learning target is complete. You can relax now.".localized()
        content.sound = .default
        content.userInfo = ["type": "brainUsage", "window": prefix]
        center.add(UNNotificationRequest(identifier: key, content: content,
                                         trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)))
    }
}
