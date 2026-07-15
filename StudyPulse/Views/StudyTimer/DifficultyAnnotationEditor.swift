//
//  DifficultyAnnotationEditor.swift
//  StudyPulse
//
//  难题标注编辑器:用户在心率峰值处登记遇到的难题。
//  Difficulty annotation editor: log a difficulty encountered at a
//  high-heart-rate point during a study session.
//

import SwiftUI

// MARK: - DifficultyAnnotationEditor

struct DifficultyAnnotationEditor: View {
    /// 编辑模式:nil = 新建;非 nil = 编辑现有标注
    /// Edit mode: nil = new; non-nil = editing existing annotation.
    let existing: DifficultyAnnotation?
    let timestamp: Date
    let heartRate: Double?
    let subjects: [Subject]

    /// 保存回调
    /// Save callback.
    var onSave: (DifficultyAnnotation) -> Void
    /// 删除回调(仅编辑模式可见)
    /// Delete callback (edit mode only).
    var onDelete: ((DifficultyAnnotation) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var note: String = ""
    @State private var selectedSubjectId: UUID?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Time".localized())
                        Spacer()
                        Text(timestamp, format: .dateTime.hour().minute().second())
                            .foregroundColor(.secondary)
                    }
                    if let hr = heartRate {
                        HStack {
                            Label("Heart Rate".localized(), systemImage: "heart.fill")
                                .foregroundColor(.pink)
                            Spacer()
                            Text("\(Int(hr)) bpm")
                                .font(.system(.body, design: .rounded).weight(.semibold))
                                .foregroundColor(.pink)
                        }
                    }
                }

                Section("Difficulty".localized()) {
                    TextEditor(text: $note)
                        .frame(minHeight: 100)
                        .font(.body)
                    if note.isEmpty {
                        Text("Describe what you found difficult at this moment — e.g. a concept that tripped you up, a problem you couldn't solve, a distraction that broke focus.".localized())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Subject (optional)".localized()) {
                    Picker("Subject".localized(), selection: $selectedSubjectId) {
                        Text("None".localized()).tag(UUID?.none)
                        ForEach(subjects.filter(\.enabled)) { s in
                            Text(s.displayName).tag(Optional(s.id))
                        }
                    }
                    .pickerStyle(.menu)
                }

                if let existing = existing, let onDelete = onDelete {
                    Section {
                        Button(role: .destructive) {
                            onDelete(existing)
                            dismiss()
                        } label: {
                            Label("Delete Annotation".localized(), systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(existing == nil ? "Log Difficulty".localized() : "Edit Annotation".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel".localized()) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save".localized()) {
                        let annotation = DifficultyAnnotation(
                            id: existing?.id ?? UUID(),
                            timestamp: timestamp,
                            heartRate: heartRate,
                            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                            subjectId: selectedSubjectId
                        )
                        onSave(annotation)
                        dismiss()
                    }
                    .disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let existing = existing {
                    note = existing.note
                    selectedSubjectId = existing.subjectId
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("New annotation") {
    DifficultyAnnotationEditor(
        existing: nil,
        timestamp: Date(),
        heartRate: 112,
        subjects: [
            Subject(name: "Math", displayName: "数学", enabled: true, fullScore: 150),
            Subject(name: "Physics", displayName: "物理", enabled: true, fullScore: 100)
        ],
        onSave: { _ in }
    )
}

#Preview("Edit annotation") {
    DifficultyAnnotationEditor(
        existing: DifficultyAnnotation(
            id: UUID(),
            timestamp: Date(),
            heartRate: 105,
            note: "三角函数变换搞混了",
            subjectId: nil
        ),
        timestamp: Date(),
        heartRate: 105,
        subjects: [],
        onSave: { _ in },
        onDelete: { _ in }
    )
}
