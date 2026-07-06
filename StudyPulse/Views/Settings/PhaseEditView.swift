//
//  PhaseEditView.swift
//  StudyPulse
//
//  阶段创建 / 编辑表单 + 目标管理。
//  Phase create / edit form with goals list.
//

import SwiftUI

/// 新建或编辑一个 study phase。
/// Create or edit a study phase, including its goal list.
struct PhaseEditView: View {
    @Environment(RepositoryContainer.self) private var container
    @Environment(\.presentationMode) var presentationMode

    /// nil = 新建模式
    let phase: StudyPhase?
    /// 新建第一个 phase 时,弹窗询问「是否把现有数据归入此 phase?」
    /// Prompt user to bulk-assign existing unassigned data when creating the first phase.
    let onCreate: ((StudyPhase, Bool) -> Void)?

    @State private var name: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Calendar.current.date(byAdding: .month, value: 4, to: Date()) ?? Date()
    @State private var goals: [PhaseGoal] = []
    @State private var assignExistingData: Bool = true

    private var isEditing: Bool { phase != nil }

    init(phase: StudyPhase? = nil, onCreate: ((StudyPhase, Bool) -> Void)? = nil) {
        self.phase = phase
        self.onCreate = onCreate
        if let p = phase {
            _name = State(initialValue: p.name)
            _startDate = State(initialValue: p.startDate)
            _endDate = State(initialValue: p.endDate)
            _goals = State(initialValue: p.goals)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                basicSection
                if !isEditing && container.phaseRepo.hasUnassignedData {
                    Section {
                        Toggle(isOn: $assignExistingData) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Assign existing data".localized())
                                    .font(.body)
                                Text("Link unassigned grades, mistakes, exams, and tasks to this phase.".localized())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text("Existing Data".localized())
                    }
                }
                goalsSection
            }
            .navigationTitle(isEditing
                             ? "Edit Phase".localized()
                             : "New Phase".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel".localized()) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save".localized()) {
                        save()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .containerBackground(.clear, for: .navigation)
            .debugModeContainer()
            .debugLayoutBoundsAuto()
        }
    }

    // MARK: - Basic Info

    private var basicSection: some View {
        Section(header: Text("Phase Info".localized())) {
            HStack {
                Text("Name".localized())
                TextField("e.g. 2026 春季学期", text: $name)
                    .multilineTextAlignment(.trailing)
            }
            DatePicker("Start Date".localized(), selection: $startDate, displayedComponents: .date)
            DatePicker("End Date".localized(), selection: $endDate, in: startDate..., displayedComponents: .date)
        }
    }

    // MARK: - Goals

    private var goalsSection: some View {
        Section(
            header: Text("Goals".localized()),
            footer: Text("Set a target score per subject. You can edit later.".localized())
        ) {
            ForEach($goals) { $goal in
                GoalRowView(goal: $goal, subjects: container.subjectRepo.subjects)
            }
            .onDelete { offsets in
                goals.remove(atOffsets: offsets)
            }
            Button {
                goals.append(PhaseGoal(subject: defaultSubjectName, targetScore: 0))
            } label: {
                Label("Add Goal".localized(), systemImage: "plus.circle.fill")
            }
        }
    }

    private var defaultSubjectName: String {
        container.subjectRepo.subjects.first(where: { $0.enabled })?.name ?? ""
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if var p = phase {
            p.name = trimmed
            p.startDate = startDate
            p.endDate = endDate
            p.goals = goals
            container.phaseRepo.update(p)
        } else {
            let new = StudyPhase(
                name: trimmed,
                startDate: startDate,
                endDate: endDate,
                goals: goals
            )
            container.phaseRepo.add(new)
            onCreate?(new, assignExistingData)
        }
    }
}

/// 单条目标的编辑行。
/// One editable goal row.
private struct GoalRowView: View {
    @Binding var goal: PhaseGoal
    let subjects: [Subject]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Picker("", selection: $goal.subject) {
                    ForEach(subjects) { s in
                        Text(s.displayName.isEmpty ? s.name : s.displayName).tag(s.name)
                    }
                }
                .labelsHidden()
                Spacer()
                TextField("Target", value: $goal.targetScore, format: .number.precision(.fractionLength(0...1)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 70)
            }
            TextField("Notes (e.g. 期末数学 ≥ 120)", text: $goal.notes, axis: .vertical)
                .font(.caption)
                .lineLimit(1...2)
        }
        .padding(.vertical, 2)
    }
}
