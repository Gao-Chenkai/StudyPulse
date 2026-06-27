import AppIntents
import Foundation

/// Returns the latest HRV-based readiness suggestion without opening the app.
struct CheckReadinessIntent: AppIntent {

    static let title: LocalizedStringResource = "Check Study Readiness"

    static let description = IntentDescription(
        "Check your HRV-based study readiness and suggestions.",
        categoryName: "Health"
    )

    static let openAppWhenRun: Bool = false

    func perform() async throws -> some ReturnsValue<String> {
        guard let cache = IntentDataLoader.loadHealthCache(),
              let suggestion = cache.readinessSuggestion,
              cache.readinessCategory != nil else {
            return .result(
                value: "Study readiness data is not available yet. Open StudyPulse and enable HealthKit to get personalized suggestions."
            )
        }

        return .result(value: suggestion)
    }
}
