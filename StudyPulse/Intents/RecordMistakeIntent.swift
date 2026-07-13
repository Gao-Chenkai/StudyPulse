import AppIntents
import Foundation

/// Opens the app to a pre-filled NewMistakeSetView for confirmation.
/// 打开 App 跳转到预填好的 NewMistakeSetView,用户确认后保存。
struct RecordMistakeIntent: AppIntent {

    static let title: LocalizedStringResource = "Record Mistake"

    static let description = IntentDescription(
        "Record a mistake note for a subject.",
        categoryName: "Mistakes"
    )

    /// 执行后自动打开 App 跳转到 NewMistakeSetView
    /// Auto-open the app after invocation to land on NewMistakeSetView.
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Title")
    var title_: String

    @Parameter(title: "Subject")
    var subject: SubjectEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Record mistake '\(\.$title_)' in \(\.$subject)")
    }

    func perform() async throws -> some IntentResult {
        // 把动作放入 IntentActionStore,等 ContentView 弹出预填好的 NewMistakeSetView
        // Enqueue the action in IntentActionStore so ContentView can present
        // a pre-filled NewMistakeSetView for the user to confirm in UI.
        let action = IntentAction.recordMistake(
            subject: subject.id,
            title: title_
        )
        IntentActionStore.setPending(action)
        return .result()
    }
}
