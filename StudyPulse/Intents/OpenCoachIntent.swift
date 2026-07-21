import AppIntents
import Foundation

struct OpenCoachIntent: AppIntent {
    static let title: LocalizedStringResource = "Open AI Coach"
    static let description = IntentDescription("Open the AI Coach for a study goal.", categoryName: "Coach")
    static let openAppWhenRun = true
    @Parameter(title: "Goal ID") var goalID: String?

    func perform() async throws -> some IntentResult {
        IntentActionStore.setPending(.openCoach(goalID: goalID.flatMap(UUID.init(uuidString:))))
        return .result()
    }
}
