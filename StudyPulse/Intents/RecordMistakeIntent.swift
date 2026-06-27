import AppIntents
import Foundation

/// Opens the app to a pre-filled NewMistakeSetView for confirmation.
struct RecordMistakeIntent: AppIntent {

    static let title: LocalizedStringResource = "Record Mistake"

    static let description = IntentDescription(
        "Record a mistake note for a subject.",
        categoryName: "Mistakes"
    )

    static let openAppWhenRun: Bool = true

    @Parameter(title: "Title")
    var title_: String

    @Parameter(title: "Subject")
    var subject: SubjectEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Record mistake '\(\.$title_)' in \(\.$subject)")
    }

    func perform() async throws -> some IntentResult {
        let action = IntentAction.recordMistake(
            subject: subject.id,
            title: title_
        )
        await MainActor.run {
            DataManager.shared.pendingIntentAction = action
        }
        return .result()
    }
}
