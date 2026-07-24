import Foundation
import Testing
@testable import StudyPulse

@MainActor
struct BrainUsageEngineTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    @Test
    func testPointsUseFixedWeights() {
        let events = [
            BrainUsageEvent(date: now, kind: .mistakeReview, units: 2),
            BrainUsageEvent(date: now, kind: .gradeRecorded),
            BrainUsageEvent(date: now, kind: .focusMinutes, units: 10)
        ]
        let result = BrainUsageEngine.snapshot(events: events, quota: BrainUsageQuota(fiveHour: 100, sevenDay: 100), now: now)
        #expect(result.fiveHour.points == 21)
        #expect(result.sevenDay.points == 21)
    }

    @Test
    func testWindowsExcludeBoundaryAndOldEvents() {
        let events = [
            BrainUsageEvent(date: now.addingTimeInterval(-BrainUsageEngine.fiveHourInterval), kind: .gradeRecorded),
            BrainUsageEvent(date: now.addingTimeInterval(-BrainUsageEngine.fiveHourInterval + 1), kind: .gradeRecorded),
            BrainUsageEvent(date: now.addingTimeInterval(-BrainUsageEngine.sevenDayInterval - 1), kind: .focusMinutes, units: 30)
        ]
        let result = BrainUsageEngine.snapshot(events: events, quota: .default, now: now)
        #expect(result.fiveHour.points == 5)
        #expect(result.sevenDay.points == 10)
    }

    @Test
    func testProgressCapsAndCompletion() {
        let events = [BrainUsageEvent(date: now, kind: .focusMinutes, units: 500)]
        let result = BrainUsageEngine.snapshot(events: events, quota: BrainUsageQuota(fiveHour: 100, sevenDay: 200), now: now)
        #expect(result.fiveHour.progress == 1)
        #expect(result.fiveHour.isComplete)
        #expect(result.sevenDay.progress == 1)
        #expect(result.sevenDay.isComplete)
    }

    @Test
    func testLocalQuotaReducesForLowReadinessAndPoorSleep() {
        let normalReadiness = HRVReadiness(zScore: 0, todayHRV: 50, baselineMean: 50, baselineSampleCount: 20, category: .normal, suggestion: "")
        let lowReadiness = HRVReadiness(zScore: -2, todayHRV: 30, baselineMean: 50, baselineSampleCount: 20, category: .low, suggestion: "")
        let normalBody = BodyStatus(restingHeartRate: 60, latestHeartRate: 70, respiratoryRate: 14, lastNightSleepHours: 8, deepSleepHours: 1, remSleepHours: 2, sleepQuality: .good, exerciseMinutesToday: 20, isUsable: true)
        let poorBody = BodyStatus(restingHeartRate: 60, latestHeartRate: 70, respiratoryRate: 14, lastNightSleepHours: 5, deepSleepHours: nil, remSleepHours: nil, sleepQuality: .poor, exerciseMinutesToday: 0, isUsable: true)
        let normal = BrainUsageEngine.localQuota(readiness: normalReadiness, bodyStatus: normalBody, age: 16, averageScoreRate: 0.8)
        let low = BrainUsageEngine.localQuota(readiness: lowReadiness, bodyStatus: poorBody, age: 16, averageScoreRate: 0.8)
        #expect(low.fiveHour < normal.fiveHour)
        #expect(low.sevenDay < normal.sevenDay)
    }
}
