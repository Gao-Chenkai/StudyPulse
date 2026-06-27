import AppIntents
import Foundation

/// Returns the average score for a subject over the last 6 months.
struct CheckSubjectAverageIntent: AppIntent {

    static let title: LocalizedStringResource = "Check Subject Average"

    static let description = IntentDescription(
        "Check your average score for a subject over the last 6 months.",
        categoryName: "Grades"
    )

    static let openAppWhenRun: Bool = false

    @Parameter(title: "Subject")
    var subject: SubjectEntity

    func perform() async throws -> some ReturnsValue<String> {
        let cutoff = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
        let grades = IntentDataLoader.loadGrades()
            .filter { $0.subject == subject.id && $0.date >= cutoff }

        guard !grades.isEmpty else {
            return .result(value: "No grades recorded for \(subject.displayName) in the last 6 months.")
        }

        let total = grades.reduce(0.0) { $0 + $1.score }
        let avg = total / Double(grades.count)
        let avgStr = String(format: "%.1f", avg)
        return .result(
            value: "Your average in \(subject.displayName) over the last 6 months is \(avgStr) from \(grades.count) grade entries."
        )
    }
}
