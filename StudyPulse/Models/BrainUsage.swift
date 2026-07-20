import Foundation

nonisolated struct BrainUsageEvent: Codable, Equatable, Identifiable, Sendable {
    enum Kind: String, Codable, CaseIterable, Hashable, Sendable {
        case mistakeReview, gradeRecorded, focusMinutes
        var pointsPerUnit: Int {
            switch self { case .mistakeReview: return 3; case .gradeRecorded: return 5; case .focusMinutes: return 1 }
        }
        var localizedTitle: String {
            switch self { case .mistakeReview: return "Mistake Review".localized(); case .gradeRecorded: return "Grade Entry".localized(); case .focusMinutes: return "Focus Analysis".localized() }
        }
    }
    let id: UUID
    let date: Date
    let kind: Kind
    let units: Int
    init(id: UUID = UUID(), date: Date = Date(), kind: Kind, units: Int = 1) { self.id = id; self.date = date; self.kind = kind; self.units = max(0, units) }
    var points: Int { units * kind.pointsPerUnit }
}

nonisolated struct BrainUsageQuota: Codable, Equatable, Sendable {
    var fiveHour: Int
    var sevenDay: Int
    static let `default` = BrainUsageQuota(fiveHour: 120, sevenDay: 600)
    static let bounds = (fiveHour: 20...600, sevenDay: 100...3000)
    init(fiveHour: Int, sevenDay: Int) {
        self.fiveHour = min(max(fiveHour, Self.bounds.fiveHour.lowerBound), Self.bounds.fiveHour.upperBound)
        self.sevenDay = min(max(sevenDay, Self.bounds.sevenDay.lowerBound), Self.bounds.sevenDay.upperBound)
    }
}

nonisolated struct BrainUsagePreferences: Codable, Equatable, Sendable {
    enum Mode: String, Codable, CaseIterable, Hashable, Sendable { case manual, dynamic }
    var mode: Mode = .manual
    var manualQuota: BrainUsageQuota = .default
    var notifyFiveHour = true
    var notifySevenDay = true
    var lastFiveHourNotificationAt: Date?
    var lastSevenDayNotificationAt: Date?
    var dynamicQuota: BrainUsageQuota?
    var dynamicQuotaGeneratedAt: Date?
    var effectiveQuota: BrainUsageQuota { mode == .manual ? manualQuota : (dynamicQuota ?? manualQuota) }
}

extension Notification.Name { static let brainUsageDidChange = Notification.Name("brainUsageDidChange") }

@MainActor
enum BrainUsageStore {
    private static let fileName = "brain_usage_events.json"
    private static let migrationKey = "brainUsageLegacyMigrationCompleted"
    static func load() -> [BrainUsageEvent] {
        guard let url = try? fileURL(), let data = try? Data(contentsOf: url), let events = try? JSONDecoder().decode([BrainUsageEvent].self, from: data) else { return [] }
        return events.sorted { $0.date < $1.date }
    }
    @discardableResult static func append(kind: BrainUsageEvent.Kind, units: Int, date: Date = Date()) -> [BrainUsageEvent] {
        guard units > 0 else { return load() }; var events = load(); events.append(BrainUsageEvent(date: date, kind: kind, units: units)); save(events)
        NotificationCenter.default.post(name: .brainUsageDidChange, object: nil); return events
    }
    static func save(_ events: [BrainUsageEvent]) {
        guard let url = try? fileURL(), let data = try? JSONEncoder().encode(events) else { return }; try? data.write(to: url, options: .atomic)
    }
    static func migrateLegacyIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }
        var events = load()
        for log in AchievementStore.load().logs {
            // Daily logs have no event timestamp. Place migrated activity
            // safely before the day boundary so it remains available to the
            // 7-day window without falsely entering the rolling 5-hour window.
            let day = Calendar.current.startOfDay(for: log.date).addingTimeInterval(-6 * 60 * 60)
            events += repeatEvents(kind: .mistakeReview, units: log.mistakeReviews, date: day)
            events += repeatEvents(kind: .gradeRecorded, units: log.gradesRecorded, date: day)
        }
        for session in StudySessionStore.load().filter(\.completed) { events.append(BrainUsageEvent(date: session.startDate, kind: .focusMinutes, units: session.durationSeconds / 60)) }
        save(events); UserDefaults.standard.set(true, forKey: migrationKey)
    }
    private static func repeatEvents(kind: BrainUsageEvent.Kind, units: Int, date: Date) -> [BrainUsageEvent] { (0..<max(0, units)).map { _ in BrainUsageEvent(date: date, kind: kind) } }
    private static func fileURL() throws -> URL { try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent(fileName) }
}
