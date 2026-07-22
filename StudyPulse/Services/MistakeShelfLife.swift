import Foundation

nonisolated enum MistakeShelfLifeStatus: String, Codable, CaseIterable {
    case fresh, expiring, expired, recurrentlyFailing

    var title: String {
        switch self {
        case .fresh: return "新鲜"
        case .expiring: return "临期"
        case .expired: return "过期"
        case .recurrentlyFailing: return "反复失效"
        }
    }
}

nonisolated struct MistakeShelfLifeEstimate: Equatable {
    let status: MistakeShelfLifeStatus
    let remainingFraction: Double
    let expectedForgettingRange: ClosedRange<Date>
    let suggestedReviewDate: Date
    let anchorDate: Date
    let estimatedDays: Double

    var isActionable: Bool { status != .fresh }
}

/// 根据错因类型、最近复习、掌握度、难度、曝光与历史遗忘情况估算复习窗口。
nonisolated enum MistakeShelfLife {
    static func estimate(for mistake: MistakeNote, now: Date = Date()) -> MistakeShelfLifeEstimate {
        let state = mistake.reviewState
        let anchor = state?.lastReviewDate ?? mistake.date
        let baseDays = Double(max(1, state?.intervalDays ?? 3))
        let errorTypeFactor: Double = {
            let reason = mistake.errorReason.lowercased()
            let highRiskTerms = ["忘", "概念", "审题", "入口", "forget", "concept", "misread"]
            return highRiskTerms.contains(where: { reason.contains($0) }) ? 0.82 : 1.0
        }()
        let masteryFactor = 0.65 + min(1, max(0, mistake.masteryScore)) * 0.9
        let difficultyFactor = mistake.difficulty > 0
            ? max(0.55, 1.15 - Double(mistake.difficulty) * 0.11) : 1.0
        let lapseFactor = pow(0.78, Double(state?.lapses ?? 0))
        let exposureFactor = min(1.15, 1.0 + Double(max(0, mistake.exposureCount)) * 0.015)
        let estimatedDays = max(1.0, min(60.0, baseDays * masteryFactor * difficultyFactor * lapseFactor * exposureFactor * errorTypeFactor))
        let suggested = anchor.addingTimeInterval(estimatedDays * 86_400)
        let uncertainty = max(86_400.0, estimatedDays * 86_400 * 0.20)
        let range = (suggested - uncertainty)...(suggested + uncertainty)
        let total = max(86_400.0, suggested.timeIntervalSince(anchor))
        let remaining = min(1, max(0, suggested.timeIntervalSince(now) / total))

        let repeatedlyFailing = (state?.lapses ?? 0) >= 2 && mistake.masteryScore < 0.45
        let status: MistakeShelfLifeStatus
        if repeatedlyFailing { status = .recurrentlyFailing }
        else if now >= suggested { status = .expired }
        else if remaining <= 0.40 { status = .expiring }
        else { status = .fresh }

        return MistakeShelfLifeEstimate(status: status, remainingFraction: remaining,
                                        expectedForgettingRange: range, suggestedReviewDate: suggested,
                                        anchorDate: anchor, estimatedDays: estimatedDays)
    }
}
