//
//  KnowledgeRepairTaskService.swift
//  StudyPulse
//

import Foundation

nonisolated struct KnowledgeRepairTaskDraft: Equatable, Sendable {
    var title: String
    var subject: String
    var notes: String
    var dueDate: Date
    var reminderDate: Date
    var importance: Int

    func makeTask() -> TaskItem? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return nil }
        return TaskItem(
            title: trimmedTitle,
            type: .homework,
            dueDate: dueDate,
            reminderDate: reminderDate,
            subject: subject.trimmingCharacters(in: .whitespacesAndNewlines),
            importance: importance,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

nonisolated enum KnowledgeRepairTaskFactory {
    static func defaultDraft(
        for faultLine: KnowledgeFaultLine,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> KnowledgeRepairTaskDraft {
        let defaultDue = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: now)
            .flatMap { $0 > now ? $0 : calendar.date(byAdding: .day, value: 1, to: $0) }
            ?? now.addingTimeInterval(3600)
        let defaultReminder = calendar.date(byAdding: .minute, value: -15, to: defaultDue) ?? defaultDue
        return KnowledgeRepairTaskDraft(
            title: String(format: "knowledge.fault.task.defaultTitle".localized(), faultLine.foundationConcept),
            subject: faultLine.subjects.first ?? "",
            notes: String(format: "knowledge.fault.task.defaultNotes".localized(), faultLine.prerequisiteConcept, faultLine.foundationConcept),
            dueDate: defaultDue,
            reminderDate: defaultReminder,
            importance: 3
        )
    }
}

@MainActor
protocol KnowledgeRepairReminderProviding: AnyObject {
    func addTaskToReminders(
        title: String,
        dueDate: Date,
        alarmDate: Date,
        notes: String,
        subject: String?
    ) async throws -> (calendarItemId: String, calendarId: String)
}

@MainActor
final class DefaultKnowledgeRepairReminderProvider: KnowledgeRepairReminderProviding {
    func addTaskToReminders(
        title: String,
        dueDate: Date,
        alarmDate: Date,
        notes: String,
        subject: String?
    ) async throws -> (calendarItemId: String, calendarId: String) {
        try await CalendarManager.shared.addTaskToReminders(
            title: title,
            dueDate: dueDate,
            alarmDate: alarmDate,
            notes: notes,
            subject: subject
        )
    }
}

nonisolated struct KnowledgeRepairTaskSaveOutcome: Sendable {
    let task: TaskItem
    let reminderWasSynced: Bool
    let reminderErrorMessage: String?
}

@MainActor
enum KnowledgeRepairTaskSaver {
    static func save(
        draft: KnowledgeRepairTaskDraft,
        syncToReminders: Bool,
        container: RepositoryContainer,
        reminderProvider: any KnowledgeRepairReminderProviding
    ) async -> KnowledgeRepairTaskSaveOutcome? {
        guard let task = draft.makeTask() else { return nil }

        guard syncToReminders else {
            container.addTask(task, syncToReminders: false)
            return KnowledgeRepairTaskSaveOutcome(
                task: task,
                reminderWasSynced: false,
                reminderErrorMessage: nil
            )
        }

        do {
            let result = try await reminderProvider.addTaskToReminders(
                title: task.title,
                dueDate: task.dueDate,
                alarmDate: task.reminderDate,
                notes: task.notes,
                subject: task.subject.isEmpty ? nil : task.subject
            )
            container.addTask(task, syncToReminders: true, reminderResult: result)
            return KnowledgeRepairTaskSaveOutcome(
                task: task,
                reminderWasSynced: true,
                reminderErrorMessage: nil
            )
        } catch {
            container.addTask(task, syncToReminders: false)
            return KnowledgeRepairTaskSaveOutcome(
                task: task,
                reminderWasSynced: false,
                reminderErrorMessage: error.localizedDescription
            )
        }
    }
}
