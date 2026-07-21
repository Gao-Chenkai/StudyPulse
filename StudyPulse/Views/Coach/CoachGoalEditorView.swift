import SwiftUI

struct CoachGoalEditorView: View {
    @Environment(RepositoryContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    struct Draft: Identifiable, Hashable {
        let id: UUID
        var subject: String
        var baseline: Double
        var target: Double
        var fullScore: Double
        var weight: Double
        init(_ value: CoachGoalSubject) { id = value.id; subject = value.subject; baseline = value.baselineScore; target = value.targetScore; fullScore = value.fullScore; weight = value.weight }
        var model: CoachGoalSubject { CoachGoalSubject(id: id, subject: subject, baselineScore: baseline, targetScore: target, fullScore: fullScore, weight: weight) }
    }

    let existing: CoachGoal?
    let onSave: (String, [CoachGoalSubject], Date, Int, String, String, String, UUID?) -> Void
    @State private var title: String
    @State private var subjects: [Draft]
    @State private var targetDate: Date
    @State private var dailyMinutes: Int
    @State private var purpose: String
    @State private var constraints: String
    @State private var changeNote: String = ""
    @State private var editingSubject: Draft?
    @State private var selectedComprehensiveExamID: UUID?

    init(existing: CoachGoal? = nil, onSave: @escaping (String, [CoachGoalSubject], Date, Int, String, String, String, UUID?) -> Void) {
        self.existing = existing; self.onSave = onSave
        _title = State(initialValue: existing?.title ?? "")
        _subjects = State(initialValue: existing?.subjects.map(Draft.init) ?? [Draft(CoachGoalSubject(subject: "", targetScore: 100))])
        _targetDate = State(initialValue: existing?.targetDate ?? Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date())
        _dailyMinutes = State(initialValue: existing?.dailyAvailableMinutes ?? 120)
        _purpose = State(initialValue: existing?.purpose ?? "")
        _constraints = State(initialValue: existing?.constraints ?? "")
        _selectedComprehensiveExamID = State(initialValue: existing?.comprehensiveExamID)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Goal".localized()) {
                    TextField("Goal title".localized(), text: $title)
                    DatePicker("Target date".localized(), selection: $targetDate, in: Date()..., displayedComponents: .date)
                    Stepper(String(format: "Daily minutes: %d".localized(), dailyMinutes), value: $dailyMinutes, in: 0...720, step: 15)
                    TextField("Purpose".localized(), text: $purpose, axis: .vertical)
                    TextField("Constraints".localized(), text: $constraints, axis: .vertical)
                }
                Section(header: Text("Target exam".localized()), footer: Text("Bind this goal to a comprehensive exam to compare progress with the multi-subject target.".localized())) {
                    Picker("Comprehensive exam".localized(), selection: $selectedComprehensiveExamID) {
                        Text("None".localized()).tag(UUID?.none)
                        ForEach(container.examRepo.comprehensiveExamSets) { exam in
                            Text(exam.name).tag(Optional(exam.id))
                        }
                    }
                }
                Section("Subjects and weights".localized()) {
                    ForEach(subjects) { draft in
                        Button { editingSubject = draft } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(draft.subject.isEmpty ? "New subject".localized() : draft.subject)
                                        .foregroundStyle(.primary)
                                    Text(String(format: "Baseline %@ · Target %@ · Weight %@ · %@".localized(),
                                                draft.baseline.formatted(), draft.target.formatted(), draft.weight.formatted(),
                                                contributionText(for: draft)))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) { subjects.removeAll { $0.id == draft.id } } label: {
                                Label("Delete".localized(), systemImage: "trash")
                            }
                        }
                    }
                    Button { subjects.append(Draft(CoachGoalSubject(subject: "", targetScore: 100))) } label: {
                        Label("Add subject".localized(), systemImage: "plus")
                    }
                }
                if existing != nil { TextField("What changed?".localized(), text: $changeNote, axis: .vertical) }
            }
            .navigationTitle((existing == nil ? "New Coach Goal" : "Edit Coach Goal").localized())
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Save".localized()) {
                let valid = subjects.filter { !$0.subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.weight > 0 }
                guard !valid.isEmpty else { return }
                onSave(title, valid.map(\.model), targetDate, dailyMinutes, purpose, constraints, changeNote, selectedComprehensiveExamID)
                dismiss()
            } } }
            .sheet(item: $editingSubject) { subject in
                CoachSubjectEditorSheet(subject: subject) { updated in
                    guard let index = subjects.firstIndex(where: { $0.id == updated.id }) else { return }
                    subjects[index] = updated
                }
            }
        }
    }

    private func contributionText(for draft: Draft) -> String {
        let total = subjects.reduce(0) { $0 + $1.weight }
        let contribution = total > 0 ? draft.weight / total : 0
        return String(format: "%.0f%% contribution".localized(), contribution * 100)
    }
}

private struct CoachSubjectEditorSheet: View {
    @Environment(RepositoryContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var draft: CoachGoalEditorView.Draft
    let onSave: (CoachGoalEditorView.Draft) -> Void

    init(subject: CoachGoalEditorView.Draft, onSave: @escaping (CoachGoalEditorView.Draft) -> Void) {
        _draft = State(initialValue: subject)
        self.onSave = onSave
    }

    private var availableSubjects: [Subject] {
        let enabled = container.subjectRepo.subjects.filter(\.enabled)
        guard !draft.subject.isEmpty,
              !enabled.contains(where: { $0.name == draft.subject }) else { return enabled }
        // Keep a legacy/deleted subject selectable while editing an existing goal.
        return enabled + [Subject(name: draft.subject, displayName: draft.subject, fullScore: draft.fullScore)]
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Subject".localized()) {
                    Picker("Subject".localized(), selection: $draft.subject) {
                        ForEach(availableSubjects, id: \.name) { subject in
                            Text(subject.displayName.localized()).tag(subject.name)
                        }
                    }
                }
                Section("Scores".localized()) {
                    scoreField("Baseline".localized(), value: $draft.baseline, placeholder: "0")
                    scoreField("Target".localized(), value: $draft.target, placeholder: "100")
                    scoreField("Full score".localized(), value: $draft.fullScore, placeholder: "100")
                }
                Section("Weight".localized()) {
                    scoreField("Weight".localized(), value: $draft.weight, placeholder: "1")
                    Text("Weights are normalized when the goal is analyzed.".localized())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Edit subject".localized())
            .onChange(of: draft.subject) { _, newValue in
                if let subject = container.subjectRepo.subjects.first(where: { $0.name == newValue }) {
                    draft.fullScore = subject.fullScore
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel".localized()) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save".localized()) {
                        guard !draft.subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                              draft.fullScore > 0, draft.weight > 0 else { return }
                        onSave(draft)
                        dismiss()
                    }
                }
            }
        }
    }

    private func scoreField(_ title: String, value: Binding<Double>, placeholder: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(placeholder, value: value, format: .number)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .frame(width: 100)
        }
    }
}
