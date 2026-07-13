import AppIntents
import Foundation

/// Returns the average score for a subject over the last 6 months.
/// 返回指定学科最近 6 个月的平均分。
struct CheckSubjectAverageIntent: AppIntent {

    static let title: LocalizedStringResource = "Check Subject Average"

    static let description = IntentDescription(
        "Check your average score for a subject over the last 6 months.",
        categoryName: "Grades"
    )

    /// 后台执行,直接返回一段话术(Siri / 灵动岛朗读)
    /// Run in background and return a spoken summary (read by Siri / Dynamic Island).
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Subject")
    var subject: SubjectEntity

    func perform() async throws -> some ReturnsValue<String> {
        // 6 个月窗口 = 现在 - 6 month
        // 6-month window: now minus 6 calendar months.
        let cutoff = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
        // 仅统计:学科匹配 + 时间在窗口内
        // Filter: matching subject AND date inside the window.
        let grades = IntentDataLoader.loadGrades()
            .filter { $0.subject == subject.id && $0.date >= cutoff }

        // 窗口内无数据 → 让用户知道
        // No grades in window — let the user know.
        guard !grades.isEmpty else {
            return .result(value: "No grades recorded for \(subject.displayName) in the last 6 months.")
        }

        // 算术平均(不区分权重);保留 1 位小数
        // Arithmetic mean (unweighted); formatted to 1 decimal.
        let total = grades.reduce(0.0) { $0 + $1.score }
        let avg = total / Double(grades.count)
        let avgStr = String(format: "%.1f", avg)
        return .result(
            value: "Your average in \(subject.displayName) over the last 6 months is \(avgStr) from \(grades.count) grade entries."
        )
    }
}
