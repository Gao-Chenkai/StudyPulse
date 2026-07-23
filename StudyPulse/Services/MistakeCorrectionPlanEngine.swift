import Foundation

nonisolated enum MistakeCorrectionPlanEngine {
    static func makePlan(for summary: MistakePatternSummary, now: Date = Date(), calendar: Calendar = .current) -> MistakeCorrectionPlan {
        let candidates = MistakePatternEngine.topMistakes(for: summary, limit: max(3, summary.relatedMistakes.count))
        let ids = candidates.map(\.id)
        let days = (0..<7).map { index -> MistakeCorrectionDay in
            let selected = (0..<min(3, ids.count)).map { offset in ids[(index * 3 + offset) % ids.count] }
            let date = calendar.date(byAdding: .day, value: index, to: calendar.startOfDay(for: now)) ?? now
            return MistakeCorrectionDay(dayIndex: index + 1, date: date, mistakeIDs: selected, completedMistakeIDs: [])
        }
        return MistakeCorrectionPlan(id: UUID(), pattern: summary.pattern, startedAt: now, days: days)
    }
}
