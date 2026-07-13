import AppIntents
import Foundation

/// Opens the app to a pre-filled AddGradeView so the user can confirm and save.
/// 打开 App 跳转到预填好的 AddGradeView,用户确认后保存。
struct AddGradeIntent: AppIntent {

    static let title: LocalizedStringResource = "Log Score"

    static let description = IntentDescription(
        "Log a test score for a subject.",
        categoryName: "Grades"
    )

    /// 执行后自动打开 App 跳转到 AddGradeView
    /// Auto-open the app after invocation to land on AddGradeView.
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
        // 不直接落库,而是把动作放入 IntentActionStore;
        // ContentView 监听后会弹出预填好的 AddGradeView,等用户在 UI 上确认。
        // Don't write to the store directly — instead enqueue the action in
        // IntentActionStore; ContentView observes it and presents a
        // pre-filled AddGradeView for the user to confirm in UI.
        let action = IntentAction.addGrade(
            subject: subject.id,
            score: score,
            examName: examName
        )
        IntentActionStore.setPending(action)
        return .result()
    }
}
