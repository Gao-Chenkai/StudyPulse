import Foundation

struct HabitInsight: Identifiable, Equatable, Sendable {
    let id: UUID
    let patternKind: PatternKind
    let weekday: Int
    let hourSlot: HourSlot
    let title: String
    let description: String
    let icon: String
    let color: String
    let priority: Int
    let confidence: Double

    enum PatternKind: String, Codable, Sendable { case peakEfficiency, procrastination, streakDay, weakDay }

    enum HourSlot: Int, Codable, Sendable, CaseIterable, Hashable {
        case morning, midday, afternoon, evening, night

        nonisolated var displayName: String {
            ["morning", "midday", "afternoon", "evening", "night"][rawValue].localized()
        }

        nonisolated static func from(hour: Int) -> HourSlot {
            switch hour {
            case 6..<11: return .morning
            case 11..<14: return .midday
            case 14..<17: return .afternoon
            case 17..<21: return .evening
            default: return .night
            }
        }
    }
}

enum HabitInsightEngine {
    private struct Bucket {
        var sessions: [StudySession] = []
        var dates = Set<Date>()
    }

    nonisolated static func computeInsights(sessions: [StudySession], now: Date = Date()) -> [HabitInsight] {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -90, to: now) ?? now
        let recent = sessions.filter { $0.startDate >= cutoff && $0.startDate <= now }
        guard recent.count >= 3 else { return [] }

        var buckets: [String: Bucket] = [:]
        for session in recent {
            let weekday = calendar.component(.weekday, from: session.startDate)
            let slot = HabitInsight.HourSlot.from(hour: calendar.component(.hour, from: session.startDate))
            let key = "\(weekday)-\(slot.rawValue)"
            var bucket = buckets[key, default: Bucket()]
            bucket.sessions.append(session)
            bucket.dates.insert(calendar.startOfDay(for: session.startDate))
            buckets[key] = bucket
        }

        let globalAverage = recent.reduce(0.0) { $0 + Double($1.durationSeconds) / 60.0 } / Double(recent.count)
        var candidates: [HabitInsight] = []
        for (key, bucket) in buckets {
            let components = key.split(separator: "-")
            guard bucket.sessions.count >= 3, components.count == 2,
                  let weekday = Int(components[0]), let slotRaw = Int(components[1]),
                  let slot = HabitInsight.HourSlot(rawValue: slotRaw) else { continue }
            let durations = bucket.sessions.map { Double($0.durationSeconds) / 60.0 }
            let average = durations.reduce(0, +) / Double(durations.count)
            let completedRatio = Double(bucket.sessions.filter(\.completed).count) / Double(bucket.sessions.count)
            let peakRatio = Double(bucket.sessions.filter { $0.intensity == .peak || $0.intensity == .deepFocus }.count) / Double(bucket.sessions.count)
            let confidence = min(1, Double(bucket.sessions.count) / 10) * max(0.25, peakRatio + completedRatio * 0.5)
            if peakRatio >= 0.4 && average >= 30 && average > globalAverage {
                candidates.append(make(.peakEfficiency, weekday, slot, average, confidence))
            } else if completedRatio < 0.5 || average < 15 {
                candidates.append(make(.procrastination, weekday, slot, average, confidence))
            }
        }

        var daily: [(weekday: Int, dates: Set<Date>, minutes: Double)] = []
        for weekday in 1...7 {
            let weekdaySessions = recent.filter { calendar.component(.weekday, from: $0.startDate) == weekday }
            let dates = Set(weekdaySessions.map { calendar.startOfDay(for: $0.startDate) })
            if dates.count >= 5 {
                daily.append((weekday, dates, weekdaySessions.reduce(0) { $0 + Double($1.durationSeconds) / 60 }))
            }
        }
        if let best = daily.max(by: { $0.minutes < $1.minutes }) { candidates.append(make(.streakDay, best.weekday, .morning, best.minutes, min(1, Double(best.dates.count) / 10))) }
        if let weak = daily.min(by: { $0.minutes < $1.minutes }) { candidates.append(make(.weakDay, weak.weekday, .morning, weak.minutes, min(1, Double(weak.dates.count) / 10))) }
        return candidates.sorted { $0.confidence > $1.confidence }.prefix(3).map { $0 }
    }

    nonisolated static func bestSlotForToday(sessions: [StudySession], now: Date = Date()) -> HabitInsight? {
        let weekday = Calendar.current.component(.weekday, from: now)
        let relevant = sessions.filter { Calendar.current.component(.weekday, from: $0.startDate) == weekday }
        let insights = computeInsights(sessions: relevant, now: now)
        if let local = insights.first(where: { $0.patternKind == .peakEfficiency }) { return local }
        return computeInsights(sessions: sessions, now: now).first(where: { $0.patternKind == .peakEfficiency })
    }

    nonisolated static func notificationBody(for insight: HabitInsight) -> String {
        let weekday = Calendar.current.weekdaySymbols[insight.weekday - 1]
        return String(format: "今日最佳学习窗口：%@%@（你的历史峰值时段，优先安排深度学习）".localized(), weekday, insight.hourSlot.displayName)
    }

    private nonisolated static func make(_ kind: HabitInsight.PatternKind, _ weekday: Int, _ slot: HabitInsight.HourSlot, _ average: Double, _ confidence: Double) -> HabitInsight {
        let weekdayName = Calendar.current.shortWeekdaySymbols[weekday - 1]
        let title: String
        let icon: String
        let color: String
        switch kind {
        case .peakEfficiency: title = "\(weekdayName)\(slot.displayName)效率最高"; icon = "bolt.fill"; color = "green"
        case .procrastination: title = "\(weekdayName)\(slot.displayName)容易拖延"; icon = "clock.badge.exclamationmark"; color = "orange"
        case .streakDay: title = "\(weekdayName)学习持续性最好"; icon = "flame.fill"; color = "blue"
        case .weakDay: title = "\(weekdayName)是学习薄弱日"; icon = "calendar.badge.exclamationmark"; color = "red"
        }
        let description = kind == .procrastination ? "该时段平均学习约\(Int(average))分钟，建议先安排一个 15 分钟小任务，降低启动阻力。" : "该模式来自最近 90 天的学习记录，建议把重要任务优先放在这个时段。"
        return HabitInsight(id: UUID(), patternKind: kind, weekday: weekday, hourSlot: slot, title: title, description: description, icon: icon, color: color, priority: kind == .peakEfficiency ? 1 : 2, confidence: confidence)
    }
}
