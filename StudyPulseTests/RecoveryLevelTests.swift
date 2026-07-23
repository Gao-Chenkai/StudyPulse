import SwiftUI
import Testing
@testable import StudyPulse

@MainActor
struct RecoveryLevelTests {
    @Test("Recovery score uses the rounded six-axis average")
    func recoveryScore() {
        let values = makeValues([0.75, 0.50, 0.34, 0.20, 0.80, 0.60])

        #expect(values.recoveryScore == 53)
        #expect(values.recoveryLevel == .good)
    }

    @Test("Recovery level thresholds cover all score bands")
    func thresholds() {
        #expect(RecoveryLevel(score: 100) == .excellent)
        #expect(RecoveryLevel(score: 75) == .excellent)
        #expect(RecoveryLevel(score: 74) == .good)
        #expect(RecoveryLevel(score: 50) == .good)
        #expect(RecoveryLevel(score: 49) == .critical)
        #expect(RecoveryLevel(score: 34) == .critical)
        #expect(RecoveryLevel(score: 33) == .poor)
        #expect(RecoveryLevel(score: 0) == .poor)
    }

    private func makeValues(_ scores: [Double]) -> BodyRadarValues {
        BodyRadarValues(
            hrv: scores[0],
            heartRate: scores[1],
            sleep: scores[2],
            exercise: scores[3],
            respiratory: scores[4],
            psychologicalStability: scores[5],
            hrvValueText: "--",
            heartRateValueText: "--",
            sleepValueText: "--",
            exerciseValueText: "--",
            respiratoryValueText: "--",
            psychologicalStabilityValueText: "--",
            hrvColor: .secondary,
            heartRateColor: .secondary,
            sleepColor: .secondary,
            exerciseColor: .secondary,
            respiratoryColor: .secondary,
            psychologicalStabilityColor: .secondary
        )
    }
}
