//
//  KnowledgeRepairTaskSheet.swift
//  StudyPulse
//

import SwiftUI

struct KnowledgeRepairTaskSheet: View {
    let faultLine: KnowledgeFaultLine
    @Environment(RepositoryContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    @State private var draft: KnowledgeRepairTaskDraft
    @State private var syncToReminders = false
    @State private var isSaving = false
    @State private var showingResultAlert = false
    @State private var resultAlertMessage = ""
    private let reminderProvider: any KnowledgeRepairReminderProviding

    init(
        faultLine: KnowledgeFaultLine,
        reminderProvider: (any KnowledgeRepairReminderProviding)? = nil
    ) {
        self.faultLine = faultLine
        _draft = State(initialValue: KnowledgeRepairTaskFactory.defaultDraft(for: faultLine))
        self.reminderProvider = reminderProvider ?? DefaultKnowledgeRepairReminderProvider()
    }

    private var availableSubjects: [String] {
        container.subjectRepo.subjects.filter(\.enabled).map(\.name)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("knowledge.fault.task.section".localized()) {
                    TextField("knowledge.fault.task.title".localized(), text: $draft.title)
                    if availableSubjects.isEmpty {
                        TextField("Subject".localized(), text: $draft.subject)
                    } else {
                        Picker("Subject".localized(), selection: $draft.subject) {
                            Text("None".localized()).tag("")
                            ForEach(availableSubjects, id: \.self) { value in
                                Text(value.localized()).tag(value)
                            }
                        }
                    }
                    TextField("knowledge.fault.task.notes".localized(), text: $draft.notes, axis: .vertical)
                        .lineLimit(3...7)
                }

                Section("Schedule".localized()) {
                    DatePicker("Due Date".localized(), selection: $draft.dueDate)
                    DatePicker("Reminder Time".localized(), selection: $draft.reminderDate, in: ...draft.dueDate)
                }

                Section("Assessment".localized()) {
                    Stepper(value: $draft.importance, in: 1...5) {
                        HStack {
                            Text("Importance".localized())
                            Spacer()
                            Text("\(draft.importance) / 5")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Reminders".localized()) {
                    Toggle("Add to System Reminders".localized(), isOn: $syncToReminders)
                }
            }
            .adaptiveForm()
            .navigationTitle("knowledge.fault.task.title".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel".localized()) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save".localized()) { save() }
                        .fontWeight(.semibold)
                        .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
            .alert("Reminders".localized(), isPresented: $showingResultAlert) {
                Button("OK".localized()) { dismiss() }
            } message: {
                Text(resultAlertMessage)
            }
        }
    }

    private func save() {
        guard draft.makeTask() != nil else { return }
        isSaving = true

        Task {
            let outcome = await KnowledgeRepairTaskSaver.save(
                draft: draft,
                syncToReminders: syncToReminders,
                container: container,
                reminderProvider: reminderProvider
            )
            guard outcome != nil else {
                isSaving = false
                return
            }
            isSaving = false
            if let errorMessage = outcome?.reminderErrorMessage {
                resultAlertMessage = String(format: "Saved to StudyPulse, but Reminders sync failed: %@".localized(), errorMessage)
                showingResultAlert = true
            } else if syncToReminders {
                resultAlertMessage = "Saved and added to system Reminders.".localized()
                showingResultAlert = true
            } else {
                dismiss()
            }
        }
    }
}
