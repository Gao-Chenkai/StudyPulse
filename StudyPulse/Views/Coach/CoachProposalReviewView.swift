import SwiftUI

struct CoachProposalReviewView: View {
    @Environment(\.dismiss) private var dismiss
    let proposal: CoachProposal
    let onConfirm: ([CoachPlanItem]) -> Void
    @State private var items: [CoachPlanItem]

    init(proposal: CoachProposal, onConfirm: @escaping ([CoachPlanItem]) -> Void) {
        self.proposal = proposal; self.onConfirm = onConfirm
        _items = State(initialValue: proposal.items)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Proposal".localized()) {
                    Text(proposal.conclusion)
                    if !proposal.rationale.isEmpty { Text(proposal.rationale).font(.footnote).foregroundStyle(.secondary) }
                }
                Section(header: Text("Choose plan items".localized()), footer: Text("Edit the title or objective before confirming.".localized())) {
                    ForEach(items.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle(isOn: Binding(get: { items[index].importance > 0 }, set: { items[index].importance = $0 ? max(3, items[index].importance) : 0 })) {
                                TextField("Task title".localized(), text: $items[index].title)
                            }
                            TextField("Objective".localized(), text: $items[index].objective, axis: .vertical)
                                .font(.footnote)
                            Text(items[index].subject).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Review proposal".localized())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel".localized()) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm".localized()) {
                        onConfirm(items.filter { $0.importance > 0 && !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
                        dismiss()
                    }
                    .disabled(!items.contains { $0.importance > 0 })
                }
            }
        }
    }
}
