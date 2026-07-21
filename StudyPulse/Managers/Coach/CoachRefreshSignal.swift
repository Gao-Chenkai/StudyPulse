import Foundation

extension Notification.Name {
    static let coachDataDidChange = Notification.Name("coachDataDidChange")
}

enum CoachRefreshSignal {
    private static let dirtyKey = "coach.analysis.dirty"
    static var isDirty: Bool { UserDefaults.standard.bool(forKey: dirtyKey) }
    static func markDirty() {
        UserDefaults.standard.set(true, forKey: dirtyKey)
        NotificationCenter.default.post(name: .coachDataDidChange, object: nil)
    }
    static func clear() { UserDefaults.standard.set(false, forKey: dirtyKey) }
}
