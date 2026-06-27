import AppIntents
import Foundation

/// Opens the app to a pre-filled AddGradeView so the user can confirm and save.
struct AddGradeIntent: AppIntent {

    static let title: LocalizedStringResource = "Log Score"

    static let description = IntentDescription(
        "Log a test score for a subject.",
        categoryName: "Grades"
    )

    static let openAppWhenRun: Bool = true

    @Parameter(title: "Subject")
    var subject: SubjectEntity

    @Parameter(title: "Score")
    var score: Double

    @Parameter(title: "Exam Name")
    var examName: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$score) in \(\.$subject)") {
            \.$examName
        }
    }

    func perform() async throws -> some IntentResult {
        let action = IntentAction.addGrade(
            subject: subject.id,
            score: score,
            examName: examName
        )
        await MainActor.run {
            DataManager.shared.pendingIntentAction = action
        }
        return .result()
    }
}
