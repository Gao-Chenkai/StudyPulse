import AppIntents
import Foundation

/// Returns the next 5 upcoming exams as a spoken dialog without opening the app.
struct CheckUpcomingExamsIntent: AppIntent {

    static let title: LocalizedStringResource = "Check Upcoming Exams"

    static let description = IntentDescription(
        "See your next 5 upcoming exams.",
        categoryName: "Exams"
    )

    static let openAppWhenRun: Bool = false

    func perform() async throws -> some ReturnsValue<String> {
        let now = Date()
        let allExams = IntentDataLoader.loadExams()
            .filter { ($0.examEndDate ?? $0.examDate) >= now }
            .sorted { $0.examDate < $1.examDate }
        let allComp = IntentDataLoader.loadComprehensiveExams()
            .filter { ($0.examEndDate ?? $0.examDate) >= now }
            .sorted { $0.examDate < $1.examDate }

        if allExams.isEmpty && allComp.isEmpty {
            return .result(value: "You have no upcoming exams. Great job staying ahead!")
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        var lines: [String] = []
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

        let prefix = "You have \(allExams.count + allComp.count) upcoming exams. "
        return .result(value: prefix + "Here are the next ones: " + lines.joined(separator: "; "))
    }
}
