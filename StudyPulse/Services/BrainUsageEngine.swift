import Foundation

nonisolated struct BrainUsageWindow: Equatable, Sendable {
    let points: Int
    let quota: Int
    let byKind: [BrainUsageEvent.Kind: Int]
    let nextRefreshDate: Date?
    var progress: Double { quota > 0 ? min(1, Double(points) / Double(quota)) : 0 }
    var isComplete: Bool { points >= quota }
}
nonisolated struct BrainUsageSnapshot: Equatable, Sendable { let fiveHour: BrainUsageWindow; let sevenDay: BrainUsageWindow }

enum BrainUsageEngine {
    static let fiveHourInterval: TimeInterval = 5 * 60 * 60
    static let sevenDayInterval: TimeInterval = 7 * 24 * 60 * 60
    static func snapshot(events: [BrainUsageEvent], quota: BrainUsageQuota, now: Date = Date()) -> BrainUsageSnapshot {
        BrainUsageSnapshot(fiveHour: window(events: events, interval: fiveHourInterval, quota: quota.fiveHour, now: now), sevenDay: window(events: events, interval: sevenDayInterval, quota: quota.sevenDay, now: now))
    }
    static func window(events: [BrainUsageEvent], interval: TimeInterval, quota: Int, now: Date) -> BrainUsageWindow {
        let start = now.addingTimeInterval(-interval); var byKind: [BrainUsageEvent.Kind: Int] = [:]
        for kind in BrainUsageEvent.Kind.allCases { byKind[kind] = 0 }
        let selected = events.filter { $0.date > start && $0.date <= now }
        for event in selected { byKind[event.kind, default: 0] += event.points }
        let nextRefreshDate = selected.min(by: { $0.date < $1.date })?.date.addingTimeInterval(interval)
        return BrainUsageWindow(points: byKind.values.reduce(0, +), quota: quota, byKind: byKind, nextRefreshDate: nextRefreshDate)
    }
    static func localQuota(readiness: HRVReadiness, bodyStatus: BodyStatus, age: Int, averageScoreRate: Double?) -> BrainUsageQuota {
        var factor = 1.0
        switch readiness.category { case .excellent: factor += 0.20; case .low: factor -= 0.25; default: break }
        if let sleep = bodyStatus.lastNightSleepHours { if sleep < 6 { factor -= 0.20 } else if sleep >= 8 { factor += 0.10 } }
        if let score = averageScoreRate, score < 0.65 { factor += 0.05 }; if age < 13 { factor -= 0.10 }; if age >= 22 { factor -= 0.05 }
        return BrainUsageQuota(fiveHour: Int((120 * factor).rounded()), sevenDay: Int((600 * factor).rounded()))
    }
}
