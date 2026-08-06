//
//  ExamReadinessPrediction.swift
//  StudyPulse
//
//  由现有健康快照、学习会话和日记派生考前状态预测与倦怠评估。
//  No persistence is introduced here; all calculations are pure and reusable.
//

import Foundation

// MARK: - Public outputs

nonisolated struct ExamDayReadiness: Identifiable, Equatable {
    let examID: UUID
    let examName: String
    let examDate: Date
    let daysRemaining: Int
    /// 预计状态 0-1。考试距离超过 14 天，或数据不足时为 nil。
    let predictedScore: Double?
    /// 恢复趋势，每天的分数变化量。
    let trendSlope: Double
    /// 最近 7 天有有效恢复信号的天数占比。
    let confidence: Double
    let riskCategory: RiskCategory
    let advice: String
    let reasoningLines: [String]

    var id: UUID { examID }
}

nonisolated enum RiskCategory: String, Equatable, Sendable {
    case strong
    case steady
    case atRisk
    case critical
}

nonisolated struct BurnoutAssessment: Equatable {
    let riskLevel: RiskLevel
    let loadScore: Double
    let recoveryScore: Double
    let trendSlope: Double
    let triggers: [Trigger]
    let advice: String

    nonisolated enum RiskLevel: String, Equatable {
        case low, watch, high
    }

    nonisolated struct Trigger: Identifiable, Equatable {
        let id: TriggerKind
        let severity: Int
        let detail: String
    }

    nonisolated enum TriggerKind: String, CaseIterable, Equatable {
        case loadSpike
        case hrvDecline
        case rhrElevation
        case sleepDebt
        case moodDecline
        case overtraining
    }
}

nonisolated struct DailyRecoveryPoint: Equatable, Identifiable {
    let date: Date
    let score: Double
    let isValid: Bool

    var id: Date { date }
}

nonisolated struct DailyLoadPoint: Equatable, Identifiable {
    let date: Date
    let weightedMinutes: Double
    let intensity: StudySession.SessionIntensity?

    var id: Date { date }
}

// MARK: - Internal summaries

nonisolated struct RecoveryTrendResult: Equatable {
    let points: [DailyRecoveryPoint]
    let trendSlope: Double
    let confidence: Double
    let latestScore: Double?
    let validPointCount: Int
}

nonisolated struct StudyLoadSummary: Equatable {
    let points: [DailyLoadPoint]
    let loadScore: Double
    let baselineLoadScore: Double
    let loadRatio: Double
    let highIntensityStreak: Int
    let recentStudyDays: Int
}

// MARK: - Recovery trend

nonisolated enum RecoveryTrendEngine {
    /// 将每日健康信号压成与 `StudyReadinessAlgorithm.calibrated` 同口径的恢复分。
    static func analyze(
        snapshots: [DailyHealthSnapshot],
        baselines: PersonalBaselines,
        age: Int?,
        now: Date = Date(),
        days: Int = 14,
        todayHRVCategory: HRVReadiness.Category? = nil
    ) -> RecoveryTrendResult {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -(max(1, days) - 1), to: calendar.startOfDay(for: now)) ?? now
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        let filtered = snapshots
            .filter { $0.date >= start && $0.date < end }
            .sorted { $0.date < $1.date }

        let points = filtered.map { snapshot in
            point(
                for: snapshot,
                baselines: baselines,
                age: age,
                todayHRVCategory: calendar.isDate(snapshot.date, inSameDayAs: now) ? todayHRVCategory : nil
            )
        }
        let validPoints = points.filter(\.isValid)
        let slope = linearRegressionSlope(points: validPoints)
        let recentStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now
        let recentValidCount = validPoints.filter { $0.date >= recentStart }.count
        let confidence = validPoints.count < 3 ? 0 : Double(recentValidCount) / 7.0
        let latestScore = validPoints
            .filter { $0.date <= now }
            .max { $0.date < $1.date }?
            .score

        return RecoveryTrendResult(
            points: points,
            trendSlope: slope,
            confidence: min(1, max(0, confidence)),
            latestScore: latestScore,
            validPointCount: validPoints.count
        )
    }

    /// 暴露单日计算，便于回归测试与其它本地派生功能复用。
    static func point(
        for snapshot: DailyHealthSnapshot,
        baselines: PersonalBaselines,
        age: Int?,
        todayHRVCategory: HRVReadiness.Category? = nil
    ) -> DailyRecoveryPoint {
        let ageReference = age.map(AgeReference.compute) ?? .adult
        let hrvScore = hrvScore(
            value: snapshot.hrv,
            baseline: baselines.hrv,
            range: ageReference.hrv,
            category: todayHRVCategory
        )
        let sleep = calibrated(
            value: restorativeSleep(from: snapshot),
            baseline: baselines.restorativeSleepHours,
            range: ageReference.restorativeSleepHours
        )
        let rhr = calibrated(
            value: snapshot.restingHeartRate,
            baseline: baselines.restingHeartRate,
            range: ageReference.restingHeartRate
        )
        let respiratory = calibrated(
            value: snapshot.respiratoryRate,
            baseline: baselines.respiratoryRate,
            range: ageReference.respiratoryRate
        )

        let scores = [hrvScore, sleep, rhr, respiratory].compactMap { $0 }
        guard !scores.isEmpty else {
            return DailyRecoveryPoint(date: snapshot.date, score: 0.5, isValid: false)
        }
        return DailyRecoveryPoint(
            date: snapshot.date,
            score: scores.reduce(0, +) / Double(scores.count),
            isValid: true
        )
    }

    private static func calibrated(
        value: Double?,
        baseline: PersonalBaselineStats?,
        range: AgeReference.Range
    ) -> Double? {
        guard value != nil else { return nil }
        return StudyReadinessAlgorithm.calibrated(
            value: value,
            baseline: baseline,
            range: range
        ).score
    }

    private static func hrvScore(
        value: Double?,
        baseline: PersonalBaselineStats?,
        range: AgeReference.Range,
        category: HRVReadiness.Category?
    ) -> Double? {
        guard let value else { return nil }
        if let category {
            switch category {
            case .excellent: return 1.0
            case .normal: return 0.6
            case .low: return 0.3
            default: break
            }
        }
        if let baseline, baseline.sampleCount >= StudyReadinessAlgorithm.minPersonalSamples {
            let z = (value - baseline.mean) / max(baseline.stdDev, 0.0001)
            if z > 1 { return 1.0 }
            if z < -1 { return 0.3 }
            return 0.6
        }
        return StudyReadinessAlgorithm.calibrated(
            value: value,
            baseline: nil,
            range: range
        ).score
    }

    private static func restorativeSleep(from snapshot: DailyHealthSnapshot) -> Double? {
        switch (snapshot.deepSleepHours, snapshot.remSleepHours) {
        case let (deep?, rem?): return deep + rem
        case let (deep?, nil): return deep
        case let (nil, rem?): return rem
        default: return nil
        }
    }

    private static func linearRegressionSlope(points: [DailyRecoveryPoint]) -> Double {
        guard points.count >= 3 else { return 0 }
        let origin = points[0].date
        let xs = points.map { $0.date.timeIntervalSince(origin) / 86_400 }
        let ys = points.map(\.score)
        let xMean = xs.reduce(0, +) / Double(xs.count)
        let yMean = ys.reduce(0, +) / Double(ys.count)
        let covariance = zip(xs, ys).reduce(0) { $0 + ($1.0 - xMean) * ($1.1 - yMean) }
        let variance = xs.reduce(0) { $0 + pow($1 - xMean, 2) }
        guard variance > 0 else { return 0 }
        return covariance / variance
    }
}

// MARK: - Study load

nonisolated enum StudyLoadEngine {
    static func analyze(
        sessions: [StudySession],
        now: Date = Date(),
        recentDays: Int = 7,
        baselineDays: Int = 21
    ) -> StudyLoadSummary {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let recentStart = calendar.date(byAdding: .day, value: -(max(1, recentDays) - 1), to: today) ?? today
        let baselineStart = calendar.date(byAdding: .day, value: -max(1, baselineDays), to: recentStart) ?? recentStart
        let firstDay = baselineStart
        let lastDay = today
        let dayCount = max(1, calendar.dateComponents([.day], from: firstDay, to: lastDay).day ?? 0) + 1

        let eligible = sessions.filter {
            $0.completed && $0.durationSeconds > 0 && $0.startDate >= firstDay && $0.startDate <= now
        }
        var grouped: [Date: [StudySession]] = [:]
        for session in eligible {
            let day = calendar.startOfDay(for: session.startDate)
            grouped[day, default: []].append(session)
        }

        let points: [DailyLoadPoint] = (0..<dayCount).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: firstDay) else { return nil }
            let daySessions = grouped[date] ?? []
            guard !daySessions.isEmpty else {
                return DailyLoadPoint(date: date, weightedMinutes: 0, intensity: nil)
            }
            let weightedMinutes = daySessions.reduce(0.0) { total, session in
                total + Double(session.durationSeconds) / 60.0 * weight(for: session.intensity)
            }
            let highestIntensity = daySessions
                .map(\.intensity)
                .sorted { intensityRank($0) > intensityRank($1) }
                .first
            return DailyLoadPoint(
                date: date,
                weightedMinutes: weightedMinutes,
                intensity: highestIntensity
            )
        }

        let recentPoints = points.filter { $0.date >= recentStart }
        let baselinePoints = points.filter { $0.date >= baselineStart && $0.date < recentStart }
        let loadScore = average(recentPoints.map(\.weightedMinutes))
        let baselineLoadScore = average(baselinePoints.map(\.weightedMinutes))
        let loadRatio = baselineLoadScore > 0 ? loadScore / baselineLoadScore : 0
        let highIntensityStreak = maxHighIntensityStreak(points: recentPoints)
        let recentStudyDays = recentPoints.filter { $0.weightedMinutes > 0 }.count

        return StudyLoadSummary(
            points: points,
            loadScore: loadScore,
            baselineLoadScore: baselineLoadScore,
            loadRatio: loadRatio,
            highIntensityStreak: highIntensityStreak,
            recentStudyDays: recentStudyDays
        )
    }

    static func weight(for intensity: StudySession.SessionIntensity) -> Double {
        switch intensity {
        case .peak: return 1.5
        case .deepFocus: return 1.2
        case .steady: return 1.0
        case .light: return 0.7
        case .recovery: return 0.5
        }
    }

    private static func intensityRank(_ intensity: StudySession.SessionIntensity) -> Int {
        switch intensity {
        case .peak: return 5
        case .deepFocus: return 4
        case .steady: return 3
        case .light: return 2
        case .recovery: return 1
        }
    }

    private static func maxHighIntensityStreak(points: [DailyLoadPoint]) -> Int {
        var current = 0
        var maximum = 0
        for point in points {
            if point.weightedMinutes >= 45,
               point.intensity == .peak || point.intensity == .deepFocus {
                current += 1
                maximum = max(maximum, current)
            } else {
                current = 0
            }
        }
        return maximum
    }

    private static func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }
}

// MARK: - Exam prediction

nonisolated enum ExamDayReadinessEngine {
    static let maximumPredictionWindow = 14

    static func predict(
        exams: [Exam],
        snapshots: [DailyHealthSnapshot],
        sessions: [StudySession],
        baselines: PersonalBaselines,
        age: Int?,
        now: Date = Date(),
        todayHRVCategory: HRVReadiness.Category? = nil
    ) -> [ExamDayReadiness] {
        let recovery = RecoveryTrendEngine.analyze(
            snapshots: snapshots,
            baselines: baselines,
            age: age,
            now: now,
            todayHRVCategory: todayHRVCategory
        )
        let load = StudyLoadEngine.analyze(sessions: sessions, now: now)
        return exams
            .map { makeReadiness(exam: $0, recovery: recovery, load: load, now: now) }
            .sorted { lhs, rhs in
                let lhsNear = lhs.daysRemaining >= 0 && lhs.daysRemaining <= maximumPredictionWindow
                let rhsNear = rhs.daysRemaining >= 0 && rhs.daysRemaining <= maximumPredictionWindow
                if lhsNear != rhsNear { return lhsNear }
                return lhs.examDate < rhs.examDate
            }
    }

    static func riskCategory(
        predictedScore: Double?,
        trendSlope: Double,
        loadRatio: Double
    ) -> RiskCategory {
        if let score = predictedScore {
            if score < 0.25 || (trendSlope < -0.02 && loadRatio > 1.5) { return .critical }
            if score < 0.4 { return .atRisk }
            if score >= 0.7 && trendSlope > 0 { return .strong }
            return .steady
        }
        if trendSlope < -0.02 && loadRatio > 1.5 { return .critical }
        if trendSlope < -0.02 { return .atRisk }
        return .steady
    }

    private static func makeReadiness(
        exam: Exam,
        recovery: RecoveryTrendResult,
        load: StudyLoadSummary,
        now: Date
    ) -> ExamDayReadiness {
        let calendar = Calendar.current
        let daysRemaining = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: exam.examDate)
        ).day ?? 0
        let score: Double?
        if daysRemaining <= 0 {
            score = recovery.latestScore
        } else if daysRemaining <= maximumPredictionWindow, let today = recovery.latestScore {
            let overloadPenalty = load.loadRatio > 1.5 && recovery.trendSlope < 0
                ? 0.05 * Double(min(daysRemaining, maximumPredictionWindow)) * (load.loadRatio - 1.5)
                : 0
            score = clamp(today + recovery.trendSlope * Double(daysRemaining) - overloadPenalty)
        } else {
            score = nil
        }
        let category = riskCategory(
            predictedScore: score,
            trendSlope: recovery.trendSlope,
            loadRatio: load.loadRatio
        )
        let advice = advice(for: category, daysRemaining: daysRemaining)
        var reasons: [String] = []
        if let score {
            reasons.append(String(format: "examReadiness.reason.score".localized(), score * 100))
        } else {
            reasons.append("examReadiness.reason.noScore".localized())
        }
        let trendKey: String
        if recovery.trendSlope > 0.005 {
            trendKey = "examReadiness.reason.trendUp"
        } else if recovery.trendSlope < -0.005 {
            trendKey = "examReadiness.reason.trendDown"
        } else {
            trendKey = "examReadiness.reason.trendFlat"
        }
        reasons.append(String(format: trendKey.localized(), recovery.trendSlope * 100))
        reasons.append(String(format: "examReadiness.reason.confidence".localized(), recovery.confidence * 100))
        if load.loadRatio > 1.5 {
            reasons.append(String(format: "examReadiness.reason.loadHigh".localized(), load.loadRatio))
        } else if load.recentStudyDays > 0 {
            reasons.append(String(format: "examReadiness.reason.studyDays".localized(), load.recentStudyDays))
        }
        if daysRemaining > maximumPredictionWindow {
            reasons.append("examReadiness.reason.longWindow".localized())
        }
        return ExamDayReadiness(
            examID: exam.id,
            examName: exam.name,
            examDate: exam.examDate,
            daysRemaining: daysRemaining,
            predictedScore: score,
            trendSlope: recovery.trendSlope,
            confidence: recovery.confidence,
            riskCategory: category,
            advice: advice,
            reasoningLines: Array(reasons.prefix(5))
        )
    }

    private static func advice(for category: RiskCategory, daysRemaining: Int) -> String {
        switch category {
        case .strong: return "examReadiness.advice.strong".localized()
        case .steady: return "examReadiness.advice.steady".localized()
        case .atRisk: return daysRemaining <= 3
                ? "examReadiness.advice.atRiskSoon".localized()
                : "examReadiness.advice.atRisk".localized()
        case .critical: return "examReadiness.advice.critical".localized()
        }
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

// MARK: - Burnout detection

nonisolated enum BurnoutDetectionEngine {
    static func assess(
        snapshots: [DailyHealthSnapshot],
        sessions: [StudySession],
        diaryEntries: [DiaryEntry],
        baselines: PersonalBaselines,
        age: Int?,
        healthAuthorized: Bool,
        now: Date = Date(),
        todayHRVCategory: HRVReadiness.Category? = nil
    ) -> BurnoutAssessment {
        let recovery = RecoveryTrendEngine.analyze(
            snapshots: snapshots,
            baselines: baselines,
            age: age,
            now: now,
            todayHRVCategory: todayHRVCategory
        )
        let validSnapshots = recovery.points.filter(\.isValid).count
        guard healthAuthorized, validSnapshots >= 7 else {
            return BurnoutAssessment(
                riskLevel: .low,
                loadScore: 0,
                recoveryScore: recovery.latestScore ?? 0.5,
                trendSlope: 0,
                triggers: [],
                advice: "burnout.coldStartHint".localized()
            )
        }

        let load = StudyLoadEngine.analyze(sessions: sessions, now: now)
        var triggers: [BurnoutAssessment.Trigger] = []
        if load.loadRatio > 1.5 && load.highIntensityStreak >= 3 {
            triggers.append(.init(
                id: .loadSpike,
                severity: 2,
                detail: String(format: "burnout.trigger.loadSpike".localized(), load.highIntensityStreak)
            ))
        }
        if recovery.trendSlope < -0.02 {
            triggers.append(.init(
                id: .hrvDecline,
                severity: 2,
                detail: String(format: "burnout.trigger.hrvDecline".localized(), recovery.trendSlope * 100)
            ))
        }

        let recentSnapshots = snapshotsInWindow(snapshots, days: 14, now: now)
        if restingHeartRateIsElevated(recentSnapshots, now: now) {
            triggers.append(.init(
                id: .rhrElevation,
                severity: 1,
                detail: "burnout.trigger.rhrElevation".localized()
            ))
        }
        if sleepDebtExists(recentSnapshots, baselines: baselines, age: age, now: now) {
            triggers.append(.init(
                id: .sleepDebt,
                severity: 1,
                detail: "burnout.trigger.sleepDebt".localized()
            ))
        }
        if moodDeclineExists(diaryEntries, now: now) {
            triggers.append(.init(
                id: .moodDecline,
                severity: 1,
                detail: "burnout.trigger.moodDecline".localized()
            ))
        }
        if overtrainingExists(recentSnapshots, load: load, now: now) {
            triggers.append(.init(
                id: .overtraining,
                severity: 2,
                detail: "burnout.trigger.overtraining".localized()
            ))
        }

        let totalSeverity = triggers.reduce(0) { $0 + $1.severity }
        let riskLevel: BurnoutAssessment.RiskLevel = totalSeverity >= 5
            ? .high
            : (totalSeverity >= 2 ? .watch : .low)
        let advice: String
        switch riskLevel {
        case .high: advice = "burnout.adviceHigh".localized()
        case .watch: advice = "burnout.adviceWatch".localized()
        case .low: advice = "burnout.adviceLow".localized()
        }
        return BurnoutAssessment(
            riskLevel: riskLevel,
            loadScore: load.loadScore,
            recoveryScore: recovery.latestScore ?? 0.5,
            trendSlope: recovery.trendSlope,
            triggers: triggers,
            advice: advice
        )
    }

    private static func snapshotsInWindow(
        _ snapshots: [DailyHealthSnapshot],
        days: Int,
        now: Date
    ) -> [DailyHealthSnapshot] {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: now)) ?? now
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        return snapshots
            .filter { $0.date >= start && $0.date < end }
            .sorted { $0.date > $1.date }
    }

    private static func restingHeartRateIsElevated(
        _ snapshots: [DailyHealthSnapshot],
        now: Date
    ) -> Bool {
        let calendar = Calendar.current
        guard let today = snapshots.first(where: { calendar.isDate($0.date, inSameDayAs: now) })?.restingHeartRate else {
            return false
        }
        let previous = snapshots
            .filter { !calendar.isDate($0.date, inSameDayAs: now) }
            .compactMap(\.restingHeartRate)
        guard !previous.isEmpty else { return false }
        let mean = previous.reduce(0, +) / Double(previous.count)
        return today > mean + 3
    }

    private static func sleepDebtExists(
        _ snapshots: [DailyHealthSnapshot],
        baselines: PersonalBaselines,
        age: Int?,
        now: Date
    ) -> Bool {
        let threshold = baselines.restorativeSleepHours.flatMap {
            $0.sampleCount >= StudyReadinessAlgorithm.minPersonalSamples ? $0.mean : nil
        } ?? (age.map(AgeReference.compute) ?? .adult).restorativeSleepHours.mid
        let recent = snapshots.prefix(5).compactMap { snapshot -> Double? in
            switch (snapshot.deepSleepHours, snapshot.remSleepHours) {
            case let (deep?, rem?): return deep + rem
            case let (deep?, nil): return deep
            case let (nil, rem?): return rem
            default: return nil
            }
        }
        return recent.count >= 2 && recent.filter { $0 < threshold }.count >= 2
    }

    private static func moodDeclineExists(_ entries: [DiaryEntry], now: Date) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let recentStart = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let previousStart = calendar.date(byAdding: .day, value: -13, to: today) ?? today
        let recent = entries.filter { $0.date >= recentStart && $0.date <= now }
        let previous = entries.filter { $0.date >= previousStart && $0.date < recentStart }
        guard !recent.isEmpty, !previous.isEmpty else { return false }
        let recentScores = recent.map(subjectiveScore)
        let previousMean = previous.map(subjectiveScore).reduce(0, +) / Double(previous.count)
        let recentMean = recentScores.reduce(0, +) / Double(recentScores.count)
        guard recentMean < previousMean else { return false }
        let sorted = recent.sorted { $0.date < $1.date }
        guard sorted.count >= 2 else { return false }
        let x = sorted.indices.map(Double.init)
        let y = sorted.map { subjectiveScore($0) }
        let xMean = x.reduce(0, +) / Double(x.count)
        let yMean = y.reduce(0, +) / Double(y.count)
        let denominator = x.reduce(0) { $0 + pow($1 - xMean, 2) }
        guard denominator > 0 else { return false }
        let slope = zip(x, y).reduce(0) { $0 + ($1.0 - xMean) * ($1.1 - yMean) } / denominator
        return slope < 0
    }

    private static func overtrainingExists(
        _ snapshots: [DailyHealthSnapshot],
        load: StudyLoadSummary,
        now: Date
    ) -> Bool {
        let calendar = Calendar.current
        let recentStart = calendar.date(byAdding: .day, value: -2, to: calendar.startOfDay(for: now)) ?? now
        let meanLoad = load.points
            .filter { $0.date >= recentStart }
            .map(\.weightedMinutes)
            .reduce(0, +) / 3.0
        guard meanLoad > 0 else { return false }
        return snapshots.contains { snapshot in
            guard snapshot.date >= recentStart else { return false }
            guard let exercise = snapshot.exerciseMinutes, exercise > 120 else { return false }
            let day = calendar.startOfDay(for: snapshot.date)
            let dayLoad = load.points.first { calendar.isDate($0.date, inSameDayAs: day) }?.weightedMinutes ?? 0
            return dayLoad >= meanLoad
        }
    }

    private static func subjectiveScore(_ entry: DiaryEntry) -> Double {
        Double(entry.moodScore + entry.energyScore) / 10.0
    }
}
