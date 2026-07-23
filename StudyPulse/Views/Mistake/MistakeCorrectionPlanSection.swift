import SwiftUI

struct MistakeCorrectionPlanSection: View {
    let summary: MistakePatternSummary?
    @Binding var plan: MistakeCorrectionPlan?

    private var today: MistakeCorrectionDay? {
        guard let plan else { return nil }
        let calendar = Calendar.current
        return plan.days.first { calendar.isDateInToday($0.date) } ?? plan.days.first { !$0.isCompleted } ?? plan.days.last
    }

    var body: some View {
        Section("mistake.correction.section".localized()) {
            if let summary {
                if plan == nil || plan?.pattern != summary.pattern {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("mistake.correction.instruction".localized())
                            .font(.subheadline).foregroundStyle(.secondary)
                        Button("mistake.correction.start".localized()) {
                            plan = MistakeCorrectionPlanStore.shared.start(summary: summary)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if let today {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(String(format: "mistake.correction.day".localized(), today.dayIndex)).font(.headline)
                            Spacer()
                            Text((today.isCompleted ? "mistake.correction.completed" : "mistake.correction.inProgress").localized())
                                .font(.caption)
                                .foregroundStyle(today.isCompleted ? .green : .orange)
                        }
                        ForEach(today.mistakeIDs, id: \.self) { id in
                            if let mistake = summary.relatedMistakes.first(where: { $0.id == id }) {
                                Button {
                                    MistakeCorrectionPlanStore.shared.toggle(mistakeID: id, on: today.dayIndex)
                                    plan = MistakeCorrectionPlanStore.shared.plan
                                } label: {
                                    HStack {
                                        Image(systemName: today.completedMistakeIDs.contains(id) ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(today.completedMistakeIDs.contains(id) ? .green : .secondary)
                                        Text(mistake.title).lineLimit(1)
                                        Spacer()
                                        Text(String(format: "mistake.correction.mastery".localized(), Int(mistake.masteryScore * 100)))
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Divider()
                        Text("mistake.correction.reflection".localized())
                            .font(.caption).foregroundStyle(.secondary)
                        HStack {
                            reflectionButton("mistake.correction.yes".localized(), value: true, day: today.dayIndex)
                            reflectionButton("mistake.correction.notYet".localized(), value: false, day: today.dayIndex)
                        }
                    }
                }
            } else {
                Text("mistake.correction.empty".localized())
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private func reflectionButton(_ title: String, value: Bool, day: Int) -> some View {
        Button(title) {
            MistakeCorrectionPlanStore.shared.setReflection(value, on: day)
            plan = MistakeCorrectionPlanStore.shared.plan
        }
        .buttonStyle(.bordered)
    }
}
