import Foundation

nonisolated struct CoachDataSnapshot: Sendable {
    let grades: [Grade]
    let mistakes: [MistakeNote]
    let tasks: [TaskItem]
    let exams: [Exam]
    let sessions: [StudySession]
    let now: Date
    let healthDataAvailable: Bool
    let healthSignals: CoachHealthSignals

    init(grades: [Grade], mistakes: [MistakeNote], tasks: [TaskItem], exams: [Exam],
         sessions: [StudySession] = [], now: Date = Date(), healthDataAvailable: Bool = false,
         healthSignals: CoachHealthSignals = .empty) {
        self.grades = grades; self.mistakes = mistakes; self.tasks = tasks; self.exams = exams
        self.sessions = sessions; self.now = now; self.healthDataAvailable = healthDataAvailable; self.healthSignals = healthSignals
    }
}

nonisolated struct CoachHealthSignals: Sendable, Equatable {
    let sleepHours: Double?
    let restingHeartRate: Double?
    let respiratoryRate: Double?
    let exerciseMinutes: Double?
    let readinessCategory: String?
    let hrvZScore: Double?
    let todayHRV: Double?
    let latestHeartRate: Double?
    let restorativeSleepHours: Double?
    let psychologicalStability: Double?
    let moodScore: Double?
    let energyScore: Double?

    static let empty = CoachHealthSignals(
        sleepHours: nil, restingHeartRate: nil, respiratoryRate: nil, exerciseMinutes: nil,
        readinessCategory: nil, hrvZScore: nil, todayHRV: nil, latestHeartRate: nil,
        restorativeSleepHours: nil, psychologicalStability: nil, moodScore: nil, energyScore: nil
    )
}

enum CoachAnalysisEngine {
    static func analyze(goal: CoachGoal, snapshot: CoachDataSnapshot,
                        predictor: any ScorePredictor = ScorePredictorFactory.active) -> CoachAnalysis {
        let predictions = goal.subjects.map { target in
            let history = snapshot.grades.filter { $0.subject == target.subject }
            let mistakes = snapshot.mistakes.filter { $0.subject == target.subject }
            let context = MistakeContext.build(from: mistakes)
            let result = predictor.predict(history: history, mistakeContext: context,
                                           examDate: goal.targetDate, fullScore: target.fullScore)
            let latest = history.max(by: { $0.date < $1.date })?.score ?? target.baselineScore
            let predicted = result?.predicted ?? latest
            let lower = result?.lowerBound ?? max(0, predicted - target.fullScore * 0.2)
            let upper = result?.upperBound ?? min(target.fullScore, predicted + target.fullScore * 0.2)
            let confidence = result.map { $0.isLowConfidence ? 0.35 : min(1, Double($0.usedSampleSize) / 6) } ?? 0.2
            return CoachSubjectPrediction(subject: target.subject, predicted: predicted,
                                          lowerBound: lower, upperBound: upper,
                                          targetScore: target.targetScore, confidence: confidence,
                                          sampleSize: history.count)
        }

        let weightTotal = max(0.0001, goal.subjects.map(\.weight).reduce(0, +))
        func weighted(_ key: (CoachSubjectPrediction) -> Double) -> Double {
            zip(goal.subjects, predictions).map { $0.0.weight * key($0.1) }.reduce(0, +) / weightTotal
        }
        let predicted = weighted(\.predicted)
        let lower = weighted(\.lowerBound)
        let upper = weighted(\.upperBound)
        let target = goal.subjects.map { $0.weight * $0.targetScore }.reduce(0, +) / weightTotal
        let probabilities = zip(goal.subjects, predictions).map { subject, prediction in
            let spread = max(1, prediction.upperBound - prediction.lowerBound)
            return max(0, min(1, 0.5 + (prediction.predicted - subject.targetScore) / spread))
        }
        let trajectoryProbability = probabilities.isEmpty ? 0 : zip(goal.subjects, probabilities).map { $0.0.weight * $0.1 }.reduce(0, +) / weightTotal
        let days = max(0, Calendar.current.dateComponents([.day], from: snapshot.now, to: goal.targetDate).day ?? 0)
        let completedMinutes = snapshot.sessions.filter { $0.completed }.reduce(0) { $0 + $1.durationSeconds / 60 }
        let recentMinutes = snapshot.sessions.filter { $0.completed && $0.startDate >= snapshot.now.addingTimeInterval(-7 * 86400) }.reduce(0) { $0 + $1.durationSeconds / 60 }

        // Probability is intentionally a weighted evidence model. The score trajectory
        // remains the strongest signal, but execution, mistakes and recovery all have
        // an explicit contribution so the Coach does not ignore behavior data.
        let mistakeProbability = mistakeReadiness(
            grades: snapshot.grades, mistakes: snapshot.mistakes
        )
        let studyProbability = studyExecution(
            recentMinutes: Double(recentMinutes), dailyMinutes: goal.dailyAvailableMinutes
        )
        let taskProbability = taskExecution(tasks: snapshot.tasks, now: snapshot.now)
        let executionProbability = studyProbability * 0.6 + taskProbability * 0.4
        let healthProbability = healthReadiness(snapshot.healthSignals, available: snapshot.healthDataAvailable)
        var probability = predictions.isEmpty ? 0 :
            trajectoryProbability * 0.45 +
            mistakeProbability * 0.20 +
            executionProbability * 0.20 +
            healthProbability * 0.15
        var risks: [String] = []
        var evidence: [String] = []
        if days < 14 && target > predicted { risks.append("The target gap is large with limited time remaining.") }
        if goal.dailyAvailableMinutes == 0 { risks.append("No daily study time has been allocated.") }
        if completedMinutes == 0 { risks.append("There is no completed focus-session history yet.") }
        else { evidence.append("Recorded (completedMinutes) completed focus minutes.") }
        if recentMinutes < goal.dailyAvailableMinutes * 3 { risks.append("Recent study time is below the available-time budget.") }
        if let sleep = snapshot.healthSignals.sleepHours {
            if sleep < 6 { risks.append("Sleep recovery is low; the plan should use shorter focused blocks.") }
            else if sleep >= 8 { evidence.append("Sleep recovery supports sustained learning today (\(String(format: "%.1f", sleep))h).") }
        }
        if snapshot.healthSignals.readinessCategory == "low" { risks.append("HealthKit readiness is low today.") }
        if snapshot.healthSignals.readinessCategory == "excellent" { evidence.append("HealthKit readiness is excellent today.") }
        if let exercise = snapshot.healthSignals.exerciseMinutes, exercise >= 20 { evidence.append("Recent movement supports today's learning capacity.") }
        if let z = snapshot.healthSignals.hrvZScore, z < -1 { risks.append("HRV is below the personal baseline (z=\(String(format: "%.2f", z))).") }
        if let restorative = snapshot.healthSignals.restorativeSleepHours, restorative < 2 { risks.append("Deep and REM sleep are below the recovery target.") }
        probability = min(1, max(0, probability))
        for p in predictions where p.predicted < p.targetScore { risks.append("(p.subject) is below its target trajectory.") }
        if risks.isEmpty { evidence.append("All tracked subjects are currently on or above target trajectory.") }
        let decision: CoachDecision
        if predictions.isEmpty { decision = .insufficientData }
        else if days < 14 && lower < target * 0.8 { decision = .notFeasible }
        else if probability < 0.45 { decision = .adjustStrategy }
        else { decision = .continueGoal }
        let fingerprint = "g(snapshot.grades.count)-m(snapshot.mistakes.count)-t(snapshot.tasks.count)-s(snapshot.sessions.count)-(Int(snapshot.now.timeIntervalSince1970 / 86400))"
        return CoachAnalysis(goalID: goal.id, goalVersion: goal.version, decision: decision,
                             weightedPredicted: predicted, weightedLowerBound: lower,
                             weightedUpperBound: upper, successProbability: probability,
                             predictions: predictions, risks: risks, evidence: evidence,
                             dataFingerprint: fingerprint, healthDataAvailable: snapshot.healthDataAvailable)
    }

    private static func mistakeReadiness(grades: [Grade], mistakes: [MistakeNote]) -> Double {
        guard !mistakes.isEmpty else { return 0.5 }
        let countCeiling = max(10.0, Double(max(1, grades.count)) * 2.0)
        let countScore = 1 - min(1, Double(mistakes.count) / countCeiling)
        let context = MistakeContext.build(from: mistakes)
        let exposureScore = min(1, Double(context.totalExposureCount) / max(3, Double(mistakes.count) * 2))
        let masteryScore = max(0, min(1, context.averageMastery))
        return countScore * 0.30 + exposureScore * 0.35 + masteryScore * 0.35
    }

    private static func studyExecution(recentMinutes: Double, dailyMinutes: Int) -> Double {
        guard dailyMinutes > 0 else { return 0.5 }
        return min(1, max(0, recentMinutes / (Double(dailyMinutes) * 7)))
    }

    private static func taskExecution(tasks: [TaskItem], now: Date) -> Double {
        let cutoff = now.addingTimeInterval(-14 * 86400)
        let recentTasks = tasks.filter {
            ($0.createdAt >= cutoff && $0.createdAt <= now) ||
            ($0.dueDate >= cutoff && $0.dueDate <= now)
        }
        guard !recentTasks.isEmpty else { return 0.5 }
        return Double(recentTasks.filter(\.isCompleted).count) / Double(recentTasks.count)
    }

    private static func healthReadiness(_ signals: CoachHealthSignals, available: Bool) -> Double {
        guard available else { return 0.5 }
        var values: [Double] = []
        if let sleep = signals.sleepHours { values.append(min(1, max(0, (sleep - 4) / 4))) }
        if let z = signals.hrvZScore { values.append(min(1, max(0, 0.5 + z * 0.2))) }
        if let exercise = signals.exerciseMinutes { values.append(min(1, max(0, exercise / 30))) }
        if let restorative = signals.restorativeSleepHours { values.append(min(1, max(0, restorative / 3))) }
        if let psychological = signals.psychologicalStability { values.append(min(1, max(0, psychological))) }
        if let mood = signals.moodScore { values.append(min(1, max(0, (mood - 1) / 4))) }
        if let energy = signals.energyScore { values.append(min(1, max(0, (energy - 1) / 4))) }
        if let readiness = signals.readinessCategory {
            switch readiness {
            case "low": values.append(0.2)
            case "fair", "moderate": values.append(0.5)
            case "good": values.append(0.75)
            case "excellent": values.append(1.0)
            default: break
            }
        }
        return values.isEmpty ? 0.5 : values.reduce(0, +) / Double(values.count)
    }
}
