import AppIntents
import Foundation

/// Returns the next 5 upcoming exams as a spoken dialog without opening the app.
/// 直接返回接下来 5 场考试的话术,不打开 App。
struct CheckUpcomingExamsIntent: AppIntent {

    static let title: LocalizedStringResource = "Check Upcoming Exams"

    static let description = IntentDescription(
        "See your next 5 upcoming exams.",
        categoryName: "Exams"
    )

    /// 后台执行,直接拼一段话术返回(Siri 朗读)
    /// Run in background and return a spoken summary (read by Siri).
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some ReturnsValue<String> {
        let now = Date()
        // 普通考试 / 综合考试分别拉取;过滤已结束(examEndDate ?? examDate < now)并按时间升序
        // Load regular and comprehensive exams separately, filter out finished
        // ones (examEndDate ?? examDate < now), sort by date ascending.
        let allExams = IntentDataLoader.loadExams()
            .filter { ($0.examEndDate ?? $0.examDate) >= now }
            .sorted { $0.examDate < $1.examDate }
        let allComp = IntentDataLoader.loadComprehensiveExams()
            .filter { ($0.examEndDate ?? $0.examDate) >= now }
            .sorted { $0.examDate < $1.examDate }

        // 两类都没有 → 鼓励一下
        // No upcoming exams of either kind — encourage the user.
        if allExams.isEmpty && allComp.isEmpty {
            return .result(value: "You have no upcoming exams. Great job staying ahead!")
        }

        // 仅显示日期(无时间),用 .medium 风格
        // Date only (no time), .medium style.
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        var lines: [String] = []
        // 上限 5 条:综合考试补齐剩余名额
        // Cap at 5: comprehensive exams fill the remaining slots.
        let max = 5
        for exam in allExams.prefix(max) {
            let dateStr = formatter.string(from: exam.examDate)
            lines.append("\(exam.name) (\(exam.subject)) — \(dateStr)")
        }
        for comp in allComp.prefix(max - lines.count) {
            let dateStr = formatter.string(from: comp.examDate)
            let subjects = comp.subject.joined(separator: ", ")
            lines.append("\(comp.name) (\(subjects)) — \(dateStr)")
        }

        // 总数 + Top 列表,作为 Siri 朗读内容
        // Total count + top list as the spoken dialog.
        let prefix = "You have \(allExams.count + allComp.count) upcoming exams. "
        return .result(value: prefix + "Here are the next ones: " + lines.joined(separator: "; "))
    }
}
