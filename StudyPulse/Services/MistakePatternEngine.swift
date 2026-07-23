import Foundation

nonisolated enum MistakePatternEngine {
    static let recentWindowDays = 14
    static let minimumOccurrences = 2

    private struct Rule {
        let pattern: MistakePattern
        let terms: [String]
    }

    private static let rules: [Rule] = [
        Rule(pattern: .conditionOmission, terms: ["条件", "限制", "前提", "范围", "x>0", "x > 0", "忽略条件", "未考虑条件", "condition", "constraint"]),
        Rule(pattern: .conceptConfusion, terms: ["概念", "混淆", "区别", "定义", "性质", "concept", "confus"]),
        Rule(pattern: .formulaMisuse, terms: ["公式", "套用", "误用", "定理", "formula", "theorem"]),
        Rule(pattern: .calculationError, terms: ["计算", "算错", "符号", "小数", "运算", "calculation", "arithmetic", "careless"]),
        Rule(pattern: .unitError, terms: ["单位", "量纲", "unit", "dimension"]),
        Rule(pattern: .incompleteReading, terms: ["审题", "读题", "漏读", "看漏", "题意", "misread", "reading"]),
        Rule(pattern: .logicJump, terms: ["跳步", "逻辑", "推理", "未说明", "logic", "step"]),
        Rule(pattern: .boundaryOmission, terms: ["边界", "端点", "特殊情况", "极端", "boundary", "edge case"]),
        Rule(pattern: .memoryError, terms: ["忘记", "记错", "背错", "记忆", "忘了", "forgot", "memory"]),
        Rule(pattern: .unclearExpression, terms: ["表达", "书写", "不清", "歧义", "表述", "expression", "unclear"]),
        Rule(pattern: .methodSelection, terms: ["方法", "思路", "策略", "选错", "method", "approach", "strategy"])
    ]

    static func classify(_ mistake: MistakeNote, userState: MistakePatternUserState? = nil) -> MistakePatternMatch? {
        if let pattern = userState?.pattern {
            return MistakePatternMatch(pattern: pattern, confidence: 1, evidence: "用户确认")
        }
        let fields = [mistake.errorReason, mistake.wrongSolution, mistake.correctSolution] + mistake.tags
        let searchable = fields.map(normalize).filter { !$0.isEmpty }.joined(separator: " ")
        guard !searchable.isEmpty else { return nil }
        let candidates: [MistakePatternMatch] = rules.compactMap { rule in
            let hits = rule.terms.filter { searchable.contains(normalize($0)) }
            guard !hits.isEmpty else { return nil }
            return MistakePatternMatch(pattern: rule.pattern, confidence: min(0.99, 0.58 + Double(hits.count) * 0.12), evidence: hits.joined(separator: ", "))
        }
        return candidates.sorted {
            if $0.confidence != $1.confidence { return $0.confidence > $1.confidence }
            return $0.pattern.rawValue < $1.pattern.rawValue
        }.first
    }

    static func summaries(
        from mistakes: [MistakeNote],
        now: Date = Date(),
        userStates: [UUID: MistakePatternUserState] = [:]
    ) -> [MistakePatternSummary] {
        var buckets: [MistakePattern: [MistakeNote]] = [:]
        for mistake in mistakes {
            if let state = userStates[mistake.id], state.ignored || state.resolved { continue }
            guard let match = classify(mistake, userState: userStates[mistake.id]), match.pattern != .other else { continue }
            buckets[match.pattern, default: []].append(mistake)
        }
        let cutoff = Calendar.current.date(byAdding: .day, value: -recentWindowDays, to: now) ?? now
        let summaries = buckets.compactMap { pattern, notes -> MistakePatternSummary? in
            guard notes.count >= minimumOccurrences else { return nil }
            let recent = notes.filter { $0.date >= cutoff }.count
            let subjects = Array(Set(notes.map { $0.subject.isEmpty ? "Uncategorized" : $0.subject })).sorted()
            let failureCount = notes.reduce(0) { $0 + ($1.reviewState?.lapses ?? 0) + $1.masteryHistory.filter { $0.quality == 1 }.count }
            let failureRate = min(1, Double(failureCount) / Double(max(1, notes.count * 2)))
            let masteryRisk = 1 - min(1, max(0, notes.map(\.masteryScore).reduce(0, +) / Double(notes.count)))
            let risk = min(1, max(0,
                min(1, Double(notes.count) / 8) * 0.35 +
                min(1, Double(recent) / 3) * 0.25 +
                min(1, Double(subjects.count) / 3) * 0.15 +
                failureRate * 0.15 + masteryRisk * 0.10
            ))
            return MistakePatternSummary(pattern: pattern, count: notes.count, subjects: subjects, recentCount: recent, riskScore: risk, relatedMistakes: notes.sorted { $0.date > $1.date }, relatedPatterns: [])
        }
        let sorted = summaries.sorted {
            if $0.riskScore != $1.riskScore { return $0.riskScore > $1.riskScore }
            if $0.count != $1.count { return $0.count > $1.count }
            return $0.pattern.rawValue < $1.pattern.rawValue
        }
        return sorted.map { summary in
            let subjectSet = Set(summary.subjects)
            let associations = sorted.filter { $0.pattern != summary.pattern && !subjectSet.isDisjoint(with: $0.subjects) }.map(\.pattern)
            return MistakePatternSummary(pattern: summary.pattern, count: summary.count, subjects: summary.subjects, recentCount: summary.recentCount, riskScore: summary.riskScore, relatedMistakes: summary.relatedMistakes, relatedPatterns: associations)
        }
    }

    static func topMistakes(for summary: MistakePatternSummary, limit: Int = 3) -> [MistakeNote] {
        summary.relatedMistakes.sorted {
            let lhs = (1 - $0.masteryScore) + Double($0.reviewState?.lapses ?? 0) * 0.2
            let rhs = (1 - $1.masteryScore) + Double($1.reviewState?.lapses ?? 0) * 0.2
            return lhs == rhs ? $0.date > $1.date : lhs > rhs
        }.prefix(max(0, limit)).map { $0 }
    }

    private static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "　", with: "")
    }
}
