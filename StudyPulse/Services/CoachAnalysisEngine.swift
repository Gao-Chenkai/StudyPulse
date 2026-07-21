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
        var probability = probabilities.isEmpty ? 0 : zip(goal.subjects, probabilities).map { $0.0.weight * $0.1 }.reduce(0, +) / weightTotal
        let days = max(0, Calendar.current.dateComponents([.day], from: snapshot.now, to: goal.targetDate).day ?? 0)
        let completedMinutes = snapshot.sessions.filter { $0.completed }.reduce(0) { $0 + $1.durationSeconds / 60 }
        let recentMinutes = snapshot.sessions.filter { $0.completed && $0.startDate >= snapshot.now.addingTimeInterval(-7 * 86400) }.reduce(0) { $0 + $1.durationSeconds / 60 }
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
        if snapshot.healthSignals.readinessCategory == "low" { probability -= 0.08 }
        if snapshot.healthSignals.readinessCategory == "excellent" { probability += 0.03 }
        if let sleep = snapshot.healthSignals.sleepHours, sleep < 6 { probability -= 0.05 }
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
}
