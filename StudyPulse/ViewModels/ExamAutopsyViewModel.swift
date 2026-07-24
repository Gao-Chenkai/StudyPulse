import Foundation
import SwiftUI
import PhotosUI

@MainActor
@Observable
final class ExamAutopsyViewModel {
    private(set) var record: ExamAutopsy
    var selectedItems: [PhotosPickerItem] = []
    var isWorking = false
    var errorMessage: String?
    private let container: RepositoryContainer

    init(exam: Exam, container: RepositoryContainer) {
        self.container = container
        self.record = container.examAutopsyRepo.record(for: exam.id) ?? ExamAutopsy(examId: exam.id, subject: exam.subject)
    }

    func addImages(_ items: [PhotosPickerItem]) async {
        for item in items { if let data = try? await item.loadTransferable(type: Data.self) { record.paperImages.append(data) } }
        persist()
    }

    func addManualItem() { record.items.append(ExamAutopsyItem(source: .userConfirmed, isConfirmed: true)); persist() }
    func update(_ item: ExamAutopsyItem) {
        guard let i = record.items.firstIndex(where: { $0.id == item.id }) else { return }
        record.items[i] = item
        if var report = record.report {
            report.reasonCounts = Dictionary(grouping: record.items.filter { $0.isConfirmed }, by: { $0.reason.rawValue }).mapValues(\.count)
            record.report = report
        }
        persist()
    }

    func analyze(exam: Exam) async {
        guard !record.paperImages.isEmpty else { errorMessage = "Add at least one paper image first."; return }
        isWorking = true; record.isAnalyzing = true; record.lastError = nil; persist()
        let history = historyContext(exam: exam)
        do {
            let result = try await ExamAutopsyLLM.analyze(images: record.paperImages, context: history, config: container.envManager.llmConfig)
            let confirmed = record.items.filter { $0.isConfirmed }
            record.items = result.items.map { item in
                if let exact = confirmed.first(where: { $0.id == item.id }) { return exact }
                if !item.questionNumber.isEmpty,
                   let matching = confirmed.first(where: { $0.questionNumber == item.questionNumber }) { return matching }
                return item
            }
            record.report = result.report
            record.isAnalyzing = false; isWorking = false; persist()
        } catch { record.isAnalyzing = false; record.lastError = error.localizedDescription; errorMessage = error.localizedDescription; isWorking = false; persist() }
    }

    func importConfirmed(exam: Exam) {
        for item in record.items where item.isConfirmed && !item.question.isEmpty {
            if record.importedMistakeIds.contains(item.id) { continue }
            let mistake = MistakeNote(id: UUID(), title: "Q\(item.questionNumber)", subject: exam.subject, originalQuestion: item.question, source: "Exam Autopsy · \(exam.name)", errorReason: item.behavior.isEmpty ? item.reason.rawValue : item.behavior, wrongSolution: item.userAnswer, correctSolution: item.correctAnswer, questionImages: record.paperImages)
            container.mistakeRepo.add(mistake); record.importedMistakeIds.append(item.id)
        }
        persist()
    }

    func importTasks(exam: Exam) {
        for item in record.items where item.isConfirmed && !item.repairSuggestion.isEmpty && !record.importedTaskIds.contains(item.id) {
            let task = TaskItem(title: "修复：Q\(item.questionNumber) · \(item.repairSuggestion.prefix(60))", type: .homework, dueDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(), reminderDate: Date(), subject: exam.subject, notes: item.repairSuggestion)
            container.taskRepo.add(task, syncToReminders: false, reminderResult: nil); record.importedTaskIds.append(item.id)
        }
        persist()
    }

    private func persist() { record.updatedAt = Date(); container.examAutopsyRepo.upsert(record) }
    private func historyContext(exam: Exam) -> String {
        let grades = container.gradeRepo.grades.filter { $0.subject == exam.subject }.sorted { $0.date > $1.date }.prefix(8)
        let exams = container.examRepo.examSets.filter { $0.subject == exam.subject && $0.id != exam.id }.prefix(8)
        let mistakes = container.mistakeRepo.mistakeSets.filter { $0.subject == exam.subject }.prefix(12)
        return "历史成绩：\(grades.map { "\($0.examName):\($0.score)" }.joined(separator: ", "))；历史考试：\(exams.map(\.name).joined(separator: ", "))；历史错题标签/原因：\(mistakes.map { ($0.tags + [$0.errorReason]).joined(separator: "/") }.joined(separator: "; "))"
    }
}
