//
//  RoutineEditorSheet.swift
//  StudyPulse
//
//  例程编辑器(新建 / 编辑)。
//  字段:title / type / subject / weekdays / start / end / enabled。
//
//  Created for Plans & Routines spec (2026-07-09).
//

import SwiftUI

struct RoutineEditorSheet: View {
    let container: RepositoryContainer
    let editing: Routine?  // nil = 新建,非 nil = 编辑

    @Environment(\.dismiss) private var dismiss

    // Form state
    @State private var title: String = ""
    @State private var type: RoutineType = .mistakeReview
    @State private var subject: String = ""
    @State private var weekdays: Set<Int> = []
    @State private var startTime: Date = defaultStart
    @State private var endTime: Date = defaultEnd
    @State private var enabled: Bool = true
    @State private var showDeleteConfirm: Bool = false
    @State private var validationError: String? = nil

    private static let defaultStart: Date = {
        var comps = DateComponents()
        comps.hour = 19
        comps.minute = 0
        return Calendar.current.date(from: comps) ?? Date()
    }()
    private static let defaultEnd: Date = {
        var comps = DateComponents()
        comps.hour = 21
        comps.minute = 0
        return Calendar.current.date(from: comps) ?? Date()
    }()

    private var isEditing: Bool { editing != nil }

    private var availableSubjects: [String] {
        let subs = container.subjectRepo.subjects.map { $0.name }
        let mistakeSubs = container.mistakeRepo.mistakeSets.map { $0.subject }
        return Array(Set(subs + mistakeSubs)).sorted()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Title".localized()) {
                    TextField("e.g. Math mistake review".localized(), text: $title)
                        .textInputAutocapitalization(.sentences)
                }

                Section("Type".localized()) {
                    Picker("Type".localized(), selection: $type) {
                        ForEach(RoutineType.allCases) { t in
                            Label(t.displayName, systemImage: t.icon).tag(t)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Subject".localized()) {
                    Picker("Subject".localized(), selection: $subject) {
                        Text("None".localized()).tag("")
                        ForEach(availableSubjects, id: \.self) { s in
                            Text(s.localized()).tag(s)
                        }
                    }
                }

                Section("Weekdays".localized()) {
                    WeekdayChipPicker(selected: $weekdays)
                }

                Section("Time".localized()) {
                    DatePicker("Start".localized(), selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("End".localized(), selection: $endTime, displayedComponents: .hourAndMinute)
                }

                Section {
                    Toggle("Enabled".localized(), isOn: $enabled)
                }

                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete routine".localized(), systemImage: "trash")
                        }
                    }
                }

                if let err = validationError {
                    Section {
                        Label(err, systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit routine".localized() : "New routine".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel".localized()) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save".localized()) { save() }
                }
            }
            .onAppear(perform: loadIfEditing)
            .confirmationDialog(
                "Delete this routine?".localized(),
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete".localized(), role: .destructive) { deleteRoutine() }
                Button("Cancel".localized(), role: .cancel) { }
            } message: {
                Text("Future instances will be removed.".localized())
            }
        }
    }

    // MARK: - Actions

    private func loadIfEditing() {
        guard let r = editing else { return }
        title = r.title
        type = r.type
        subject = r.subject ?? ""
        weekdays = Set(r.weekdays)
        startTime = r.startTime
        endTime = r.endTime
        enabled = r.enabled
    }

    private func save() {
        // 校验
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationError = "Title is required.".localized()
            return
        }
        guard !weekdays.isEmpty else {
            validationError = "Select at least one weekday.".localized()
            return
        }
        guard endTime > startTime else {
            validationError = "End time must be after start time.".localized()
            return
        }
        validationError = nil

        let subjectValue: String? = subject.isEmpty ? nil : subject
        if let existing = editing {
            var updated = existing
            updated.title = title
            updated.type = type
            updated.subject = subjectValue
            updated.weekdays = Array(weekdays).sorted()
            updated.startTime = startTime
            updated.endTime = endTime
            updated.enabled = enabled
            container.updateRoutine(updated)
        } else {
            let new = Routine(
                title: title,
                type: type,
                subject: subjectValue,
                weekdays: Array(weekdays).sorted(),
                startTime: startTime,
                endTime: endTime,
                enabled: enabled
            )
            container.addRoutine(new)
        }
        dismiss()
    }

    private func deleteRoutine() {
        guard let r = editing else { return }
        container.deleteRoutine(r.id)
        dismiss()
    }
}

// MARK: - Weekday Chip Picker

private struct WeekdayChipPicker: View {
    @Binding var selected: Set<Int>

    private let labels: [(Int, String)] = [
        (1, "S"), (2, "M"), (3, "T"),
        (4, "W"), (5, "T"), (6, "F"), (7, "S")
    ]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(labels, id: \.0) { item in
                chip(item)
            }
        }
    }

    private func chip(_ item: (Int, String)) -> some View {
        let isOn = selected.contains(item.0)
        return Button {
            if isOn { selected.remove(item.0) } else { selected.insert(item.0) }
        } label: {
            Text(item.1)
                .font(.subheadline.bold())
                .frame(width: 34, height: 34)
                .background(
                    Circle().fill(isOn ? Color.indigo : Color.secondary.opacity(0.18))
                )
                .foregroundColor(isOn ? .white : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(weekdayName(item.0))
    }

    private func weekdayName(_ wd: Int) -> String {
        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return names[(wd - 1) % 7]
    }
}
