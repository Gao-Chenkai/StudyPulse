import SwiftUI

struct ExamGoalEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ExamReversePlannerViewModel

    let existingGoal: ExamGoal?
    let initialGoal: ExamGoal?
    let onSaved: (ExamGoal) -> Void

    @State private var examName: String
    @State private var selectedSubject: String
    @State private var examDate: Date
    @State private var currentScore: String
    @State private var targetScore: String
    @State private var fullScore: String

    init(
        viewModel: ExamReversePlannerViewModel,
        existingGoal: ExamGoal? = nil,
        initialGoal: ExamGoal? = nil,
        onSaved: @escaping (ExamGoal) -> Void
    ) {
        self._viewModel = Bindable(viewModel)
        self.existingGoal = existingGoal
        self.initialGoal = initialGoal
        self.onSaved = onSaved
        let goal = existingGoal ?? initialGoal
        _examName = State(initialValue: goal?.examName ?? "")
        _selectedSubject = State(initialValue: goal?.subject ?? viewModel.subjects.first?.name ?? "")
        _examDate = State(initialValue: goal?.examDate ?? Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date())
        _currentScore = State(initialValue: goal.map { String($0.currentScore) } ?? "")
        _targetScore = State(initialValue: goal.map { String($0.targetScore) } ?? "")
        _fullScore = State(initialValue: goal.map { String($0.fullScore) } ?? String(viewModel.subjects.first?.fullScore ?? 100))
    }

    private var parsedCurrentScore: Double? { Double(currentScore.trimmingCharacters(in: .whitespacesAndNewlines)) }
    private var parsedTargetScore: Double? { Double(targetScore.trimmingCharacters(in: .whitespacesAndNewlines)) }
    private var parsedFullScore: Double? { Double(fullScore.trimmingCharacters(in: .whitespacesAndNewlines)) }

    private var canSave: Bool {
        !examName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !selectedSubject.isEmpty &&
            parsedCurrentScore != nil && parsedTargetScore != nil && parsedFullScore ?? 0 > 0
    }

    var body: some View {
        Form {
            Section("exam.reverse.planner.goal.section".localized()) {
                TextField("exam.reverse.planner.exam.name".localized(), text: $examName)
                SubjectPickerView(selectedSubject: $selectedSubject, subjects: viewModel.subjects)
                DatePicker("exam.reverse.planner.exam.date".localized(), selection: $examDate, in: Date()..., displayedComponents: .date)
            }

            Section("exam.reverse.planner.score.section".localized()) {
                scoreField("exam.reverse.planner.current.score".localized(), text: $currentScore)
                scoreField("exam.reverse.planner.target.score".localized(), text: $targetScore)
                scoreField("exam.reverse.planner.full.score".localized(), text: $fullScore)
            }

            Section {
                Button {
                    save()
                } label: {
                    Text("保存目标".localized())
                        .frame(maxWidth: .infinity)
                }
                .disabled(!canSave)
            }
        }
        .navigationTitle(existingGoal == nil ? "exam.reverse.planner.new.goal".localized() : "exam.reverse.planner.edit.goal".localized())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("取消".localized()) { dismiss() }
            }
        }
    }

    private func scoreField(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .keyboardType(.decimalPad)
    }

    private func save() {
        guard let currentScore = parsedCurrentScore,
              let targetScore = parsedTargetScore,
              let fullScore = parsedFullScore,
              fullScore > 0 else { return }
        let goal = ExamGoal(
            id: existingGoal?.id ?? UUID(),
            examName: examName.trimmingCharacters(in: .whitespacesAndNewlines),
            subject: selectedSubject,
            examDate: examDate,
            currentScore: min(max(0, currentScore), fullScore),
            targetScore: min(max(0, targetScore), fullScore),
            fullScore: fullScore,
            phaseId: existingGoal?.phaseId,
            createdAt: existingGoal?.createdAt ?? Date()
        )
        viewModel.saveGoal(goal)
        onSaved(goal)
        dismiss()
    }
}
