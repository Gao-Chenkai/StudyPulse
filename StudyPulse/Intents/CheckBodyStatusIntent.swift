import AppIntents
import Foundation

/// Returns today's body-status summary (sleep, heart rate, exercise) without opening the app.
struct CheckBodyStatusIntent: AppIntent {

    static let title: LocalizedStringResource = "Check Body Status"

    static let description = IntentDescription(
        "Check your body status — sleep, heart rate, and exercise for today.",
        categoryName: "Health"
    )

    static let openAppWhenRun: Bool = false

    func perform() async throws -> some ReturnsValue<String> {
        guard let cache = IntentDataLoader.loadHealthCache() else {
            return .result(
                value: "Body status data is not available yet. Open StudyPulse and enable HealthKit."
            )
        }

        var parts: [String] = []
        if let sleep = cache.sleepHours {
            let h = String(format: "%.1f", sleep)
            let quality = cache.sleepQuality ?? "unknown"
            parts.append("Sleep: \(h) hours (\(quality))")
        }
        if let hr = cache.restingHeartRate {
            parts.append("Resting heart rate: \(Int(hr)) bpm")
        }
        if let ex = cache.exerciseMinutes {
            parts.append("Exercise today: \(Int(ex)) minutes")
        }

        guard !parts.isEmpty else {
            return .result(value: "No body status data available for today.")
        }

        return .result(value: "Today's status — " + parts.joined(separator: ". ") + ".")
    }
}
