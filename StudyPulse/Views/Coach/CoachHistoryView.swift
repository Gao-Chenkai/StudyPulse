import SwiftUI
import Charts

struct CoachHistoryView: View {
    @ObservedObject var viewModel: CoachViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                let analyses = viewModel.container.coachRepo.analyses
                    .filter { $0.goalID == viewModel.selectedGoal?.id }
                    .sorted { $0.calculatedAt < $1.calculatedAt }
                Section("Analysis trend".localized()) {
                    if analyses.count < 2 {
                        Text("Run Coach on more than one day to see a trend.".localized()).foregroundStyle(.secondary)
                    } else {
                        Chart(analyses) { analysis in
                            LineMark(x: .value("Date".localized(), analysis.calculatedAt), y: .value("Prediction".localized(), analysis.weightedPredicted))
                                .foregroundStyle(.blue)
                                .interpolationMethod(.catmullRom)
                            PointMark(x: .value("Date".localized(), analysis.calculatedAt), y: .value("Prediction".localized(), analysis.weightedPredicted))
                                .foregroundStyle(.blue)
                        }
                        .chartYAxis { AxisMarks(position: .leading) }
                        .frame(height: 190)
                    }
                }
                if let goal = viewModel.selectedGoal, !goal.history.isEmpty {
                    Section("Goal versions") {
                        ForEach(goal.history.sorted { $0.version > $1.version }) { version in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(String(format: "Version %d".localized(), version.version)).font(.headline)
                                Text(version.changeNote.isEmpty ? "No change note".localized() : version.changeNote).font(.callout)
                                Text(String(format: "%d subjects · %@".localized(), version.subjects.count, version.targetDate.formatted(date: .abbreviated, time: .omitted))).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section("Proposal history") {
                    let items = viewModel.proposals.filter { $0.goalID == viewModel.selectedGoal?.id }
                    if items.isEmpty { Text("No previous proposals".localized()).foregroundStyle(.secondary) }
                    ForEach(items) { proposal in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack { Text(proposalStatusLabel(proposal.status)); Spacer(); Text(proposal.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary) }
                            Text(proposal.conclusion).font(.callout)
                            if let reason = proposal.failureReason { Text(reason).font(.caption).foregroundStyle(.orange) }
                            if let alternative = proposal.alternative, !alternative.isEmpty { Text("Alternative: %@".localized().replacingOccurrences(of: "%@", with: alternative)).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }
            }
            .navigationTitle("Coach History".localized())
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done".localized()) { dismiss() } } }
        }
    }

    private func proposalStatusLabel(_ status: CoachProposalStatus) -> String {
        status.rawValue.capitalized.localized()
    }
}
