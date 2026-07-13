import Foundation

/// App Intent 与 App 外壳之间的桥接类型,用于导航到预填好的表单。
/// Bridge between App Intents and the app shell for navigation to pre-filled forms.
enum IntentAction: Equatable, Sendable {
    case addGrade(subject: String, score: Double, examName: String?)  // 添加成绩 / Log a score.
    case recordMistake(subject: String, title: String)  // 记录错题 / Record a mistake.
}
