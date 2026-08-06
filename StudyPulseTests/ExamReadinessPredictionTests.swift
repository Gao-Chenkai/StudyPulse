import XCTest
@testable import StudyPulse

@MainActor
final class ExamReadinessPredictionTests: XCTestCase {
    private let now: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 6
        components.hour = 12
        components.timeZone = TimeZone.current
        return Calendar.current.date(from: components) ?? Date()
    }()

    private func date(daysAgo: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -daysAgo, to: now) ?? now
    }

    private func snapshot(
        daysAgo: Int,
        hrv: Double? = 60,
        rhr: Double? = 60,
        respiratoryRate: Double? = 14,
        deepSleep: Double? = 1,
        remSleep: Double? = 1.5,
        exercise: Double? = 30
    ) -> DailyHealthSnapshot {
        DailyHealthSnapshot(
            date: date(daysAgo: daysAgo),
            hrv: hrv,
            restingHeartRate: rhr,
            respiratoryRate: respiratoryRate,
            sleepHours: 8,
            deepSleepHours: deepSleep,
            remSleepHours: remSleep,
            exerciseMinutes: exercise
        )
    }

    private func session(daysAgo: Int, minutes: Int, intensity: StudySession.SessionIntensity) -> StudySession {
        StudySession(
            id: UUID(),
            startDate: date(daysAgo: daysAgo),
            durationSeconds: minutes * 60,
            intensity: intensity,
            completed: true
        )
    }

    private func stableSnapshots() -> [DailyHealthSnapshot] {
        (0..<14).map { daysAgo in
            snapshot(daysAgo: daysAgo)
        }
    }

    private func burnoutAssessment(
        snapshots: [DailyHealthSnapshot] = [],
        sessions: [StudySession] = [],
        diaryEntries: [DiaryEntry] = []
    ) -> BurnoutAssessment {
        BurnoutDetectionEngine.assess(
            snapshots: snapshots.isEmpty ? stableSnapshots() : snapshots,
            sessions: sessions,
            diaryEntries: diaryEntries,
            baselines: .empty,
            age: 25,
            healthAuthorized: true,
            now: now
        )
    }

    private func exam(daysFromNow: Int) -> Exam {
        Exam(
            name: "Physics",
            date: Calendar.current.date(byAdding: .day, value: daysFromNow, to: now) ?? now,
            importance: 4,
            subject: "Physics",
            examName: "Physics",
            masteryDegree: 0
        )
    }

    func testRecoveryTrend_detectsDirectionAndNeedsThreeValidPoints() {
        let rising = (0..<5).map { offset in
            snapshot(daysAgo: 4 - offset, hrv: 45 + Double(offset * 10))
        }
        let result = RecoveryTrendEngine.analyze(
            snapshots: rising,
            baselines: .empty,
            age: 25,
            now: now
        )
        XCTAssertGreaterThan(result.trendSlope, 0)
        XCTAssertGreaterThan(result.confidence, 0)

        let short = RecoveryTrendEngine.analyze(
            snapshots: [snapshot(daysAgo: 1), snapshot(daysAgo: 0)],
            baselines: .empty,
            age: 25,
            now: now
        )
        XCTAssertEqual(short.trendSlope, 0)
        XCTAssertEqual(short.confidence, 0)
    }

    func testRiskCategory_respectsBoundaries() {
        XCTAssertEqual(ExamDayReadinessEngine.riskCategory(predictedScore: 0.8, trendSlope: 0.01, loadRatio: 1), .strong)
        XCTAssertEqual(ExamDayReadinessEngine.riskCategory(predictedScore: 0.7, trendSlope: 0, loadRatio: 1), .steady)
        XCTAssertEqual(ExamDayReadinessEngine.riskCategory(predictedScore: 0.4, trendSlope: 0, loadRatio: 1), .steady)
        XCTAssertEqual(ExamDayReadinessEngine.riskCategory(predictedScore: 0.39, trendSlope: 0, loadRatio: 1), .atRisk)
        XCTAssertEqual(ExamDayReadinessEngine.riskCategory(predictedScore: 0.25, trendSlope: 0, loadRatio: 1), .atRisk)
        XCTAssertEqual(ExamDayReadinessEngine.riskCategory(predictedScore: 0.249, trendSlope: 0, loadRatio: 1), .critical)
        XCTAssertEqual(ExamDayReadinessEngine.riskCategory(predictedScore: 0.8, trendSlope: -0.03, loadRatio: 2), .critical)
    }

    func testPredictionWindowAndOverloadPenalty() {
        let snapshots = (0..<10).map { offset in
            snapshot(daysAgo: 9 - offset, hrv: 90 - Double(offset * 6))
        }
        let overloadedSessions = (0..<7).map { day in
            session(daysAgo: day, minutes: 60, intensity: .peak)
        } + (7..<28).map { day in
            session(daysAgo: day, minutes: 10, intensity: .steady)
        }
        let overloaded = ExamDayReadinessEngine.predict(
            exams: [exam(daysFromNow: 5)],
            snapshots: snapshots,
            sessions: overloadedSessions,
            baselines: .empty,
            age: 25,
            now: now
        ).first
        let noOverload = ExamDayReadinessEngine.predict(
            exams: [exam(daysFromNow: 5)],
            snapshots: snapshots,
            sessions: [],
            baselines: .empty,
            age: 25,
            now: now
        ).first

        XCTAssertNotNil(overloaded?.predictedScore)
        XCTAssertLessThan(overloaded?.predictedScore ?? 1, noOverload?.predictedScore ?? 1)
        XCTAssertNil(
            ExamDayReadinessEngine.predict(
                exams: [exam(daysFromNow: 20)],
                snapshots: snapshots,
                sessions: [],
                baselines: .empty,
                age: 25,
                now: now
            ).first?.predictedScore
        )
        XCTAssertEqual(
            ExamDayReadinessEngine.predict(
                exams: [exam(daysFromNow: 0)],
                snapshots: snapshots,
                sessions: [],
                baselines: .empty,
                age: 25,
                now: now
            ).first?.predictedScore,
            RecoveryTrendEngine.analyze(snapshots: snapshots, baselines: .empty, age: 25, now: now).latestScore
        )
    }

    func testStudyLoad_usesIntensityWeightsAndBaselineRatio() {
        let result = StudyLoadEngine.analyze(
            sessions: [
                session(daysAgo: 0, minutes: 60, intensity: .peak),
                session(daysAgo: 0, minutes: 30, intensity: .light)
            ],
            now: now
        )
        XCTAssertEqual(result.loadScore, (90 + 21) / 7, accuracy: 0.0001)
        XCTAssertEqual(StudyLoadEngine.weight(for: .deepFocus), 1.2)
        XCTAssertEqual(StudyLoadEngine.weight(for: .recovery), 0.5)
    }

    func testBurnout_coldStartIsLowWithoutTriggers() {
        let result = BurnoutDetectionEngine.assess(
            snapshots: [snapshot(daysAgo: 0)],
            sessions: [session(daysAgo: 0, minutes: 90, intensity: .peak)],
            diaryEntries: [],
            baselines: .empty,
            age: 25,
            healthAuthorized: false,
            now: now
        )
        XCTAssertEqual(result.riskLevel, .low)
        XCTAssertTrue(result.triggers.isEmpty)
    }

    func testBurnout_rulesTriggerIndependently() {
        let loadSpikeSessions = (0..<7).map { daysAgo in
            session(daysAgo: daysAgo, minutes: 60, intensity: .peak)
        } + (7..<28).map { daysAgo in
            session(daysAgo: daysAgo, minutes: 10, intensity: .steady)
        }
        let loadSpike = burnoutAssessment(sessions: loadSpikeSessions)
        XCTAssertEqual(loadSpike.triggers.map(\.id), [.loadSpike])

        let decliningHRVSnapshots = (0..<14).map { daysAgo in
            snapshot(daysAgo: daysAgo, hrv: daysAgo >= 7 ? 70 : 30)
        }
        let hrvDecline = burnoutAssessment(snapshots: decliningHRVSnapshots)
        XCTAssertEqual(hrvDecline.triggers.map(\.id), [.hrvDecline])

        let elevatedRHRSnapshots = stableSnapshots().map { snapshot in
            guard Calendar.current.isDate(snapshot.date, inSameDayAs: now) else { return snapshot }
            return DailyHealthSnapshot(
                date: snapshot.date,
                hrv: snapshot.hrv,
                restingHeartRate: 65,
                respiratoryRate: snapshot.respiratoryRate,
                sleepHours: snapshot.sleepHours,
                deepSleepHours: snapshot.deepSleepHours,
                remSleepHours: snapshot.remSleepHours,
                exerciseMinutes: snapshot.exerciseMinutes
            )
        }
        let rhrElevation = burnoutAssessment(snapshots: elevatedRHRSnapshots)
        XCTAssertEqual(rhrElevation.triggers.map(\.id), [.rhrElevation])

        let sleepDebtSnapshots = stableSnapshots().map { snapshot in
            guard snapshot.date >= Calendar.current.date(byAdding: .day, value: -1, to: now)! else {
                return snapshot
            }
            return DailyHealthSnapshot(
                date: snapshot.date,
                hrv: snapshot.hrv,
                restingHeartRate: snapshot.restingHeartRate,
                respiratoryRate: snapshot.respiratoryRate,
                sleepHours: snapshot.sleepHours,
                deepSleepHours: 0.5,
                remSleepHours: 0.5,
                exerciseMinutes: snapshot.exerciseMinutes
            )
        }
        let sleepDebt = burnoutAssessment(snapshots: sleepDebtSnapshots)
        XCTAssertEqual(sleepDebt.triggers.map(\.id), [.sleepDebt])

        let previousDiary = (7...13).map { daysAgo in
            DiaryEntry(date: date(daysAgo: daysAgo), moodScore: 5, energyScore: 5)
        }
        let recentDiary = (0...6).map { daysAgo in
            DiaryEntry(date: date(daysAgo: daysAgo), moodScore: max(1, 4 - (6 - daysAgo)), energyScore: 2)
        }
        let moodDecline = burnoutAssessment(diaryEntries: previousDiary + recentDiary)
        XCTAssertEqual(moodDecline.triggers.map(\.id), [.moodDecline])

        let overtrainingSnapshots = stableSnapshots().map { snapshot in
            guard Calendar.current.isDate(snapshot.date, inSameDayAs: now) else { return snapshot }
            return DailyHealthSnapshot(
                date: snapshot.date,
                hrv: snapshot.hrv,
                restingHeartRate: snapshot.restingHeartRate,
                respiratoryRate: snapshot.respiratoryRate,
                sleepHours: snapshot.sleepHours,
                deepSleepHours: snapshot.deepSleepHours,
                remSleepHours: snapshot.remSleepHours,
                exerciseMinutes: 121
            )
        }
        let overtraining = burnoutAssessment(
            snapshots: overtrainingSnapshots,
            sessions: [session(daysAgo: 0, minutes: 60, intensity: .steady)]
        )
        XCTAssertEqual(overtraining.triggers.map(\.id), [.overtraining])
    }

    func testRecoveryPoint_matchesCalibratedSignalAverage() {
        let input = snapshot(daysAgo: 0, hrv: 60, rhr: 62, respiratoryRate: 15, deepSleep: 1.2, remSleep: 1.3)
        let point = RecoveryTrendEngine.point(
            for: input,
            baselines: .empty,
            age: 25,
            todayHRVCategory: .normal
        )
        let reference = AgeReference.compute(age: 25)
        let expectedSignals = [
            0.6,
            StudyReadinessAlgorithm.calibrated(
                value: 2.5,
                baseline: nil,
                range: reference.restorativeSleepHours
            ).score,
            StudyReadinessAlgorithm.calibrated(
                value: 62,
                baseline: nil,
                range: reference.restingHeartRate
            ).score,
            StudyReadinessAlgorithm.calibrated(
                value: 15,
                baseline: nil,
                range: reference.respiratoryRate
            ).score
        ]
        XCTAssertEqual(point.score, expectedSignals.reduce(0, +) / Double(expectedSignals.count), accuracy: 0.0001)
        XCTAssertTrue(point.isValid)
    }
}
