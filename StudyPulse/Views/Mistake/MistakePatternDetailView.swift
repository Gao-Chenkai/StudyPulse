import SwiftUI
import Charts

struct MistakePatternDetailView: View {
    let summary: MistakePatternSummary
    @Environment(RepositoryContainer.self) private var container

    private var topMistakes: [MistakeNote] { MistakePatternEngine.topMistakes(for: summary) }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Label(summary.pattern.displayName, systemImage: "scope")
                        .font(.title2.bold())
                    Text(summary.pattern.explanation).foregroundStyle(.secondary)
                    HStack {
                        metric("mistake.pattern.metric.count".localized(), String(format: "mistake.pattern.count.value".localized(), summary.count))
                        metric("mistake.pattern.metric.recent".localized(), String(format: "mistake.pattern.count.value".localized(), summary.recentCount))
                        metric("mistake.pattern.metric.risk".localized(), String(format: "mistake.pattern.risk.value".localized(), Int(summary.riskScore * 100)))
                    }
                }
            }

            Section("mistake.pattern.detail.profile".localized()) {
                LabeledContent("mistake.pattern.detail.first".localized(), value: format(summary.firstDate))
                LabeledContent("mistake.pattern.detail.latest".localized(), value: format(summary.latestDate))
                LabeledContent("mistake.pattern.detail.subjects".localized(), value: summary.subjects.joined(separator: "、"))
                LabeledContent("mistake.pattern.detail.averageMastery".localized(), value: String(format: "mistake.pattern.risk.value".localized(), Int(summary.averageMastery * 100)))
            }

            Section("mistake.pattern.detail.mastery".localized()) {
                Chart {
                    ForEach(summary.relatedMistakes.flatMap(\.masteryHistory).sorted { $0.timestamp < $1.timestamp }) { entry in
                        LineMark(x: .value("mistake.pattern.chart.date".localized(), entry.timestamp), y: .value("mistake.pattern.chart.mastery".localized(), entry.score))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(.blue)
                        PointMark(x: .value("mistake.pattern.chart.date".localized(), entry.timestamp), y: .value("mistake.pattern.chart.mastery".localized(), entry.score))
                            .foregroundStyle(entry.quality == 1 ? .red : .blue)
                    }
                }
                .chartYScale(domain: 0...1)
                .frame(height: 180)
            }

            Section("mistake.pattern.detail.topMistakes".localized()) {
                ForEach(topMistakes) { mistake in
                    NavigationLink(destination: MistakeSetDetailView(mistakeSet: mistake).environment(container)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(mistake.title).font(.body.weight(.semibold))
                            Text(String(format: "mistake.pattern.detail.mistakeMeta".localized(), mistake.subject.isEmpty ? "mistake.pattern.uncategorized".localized() : mistake.subject, Int(mistake.masteryScore * 100)))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if !summary.relatedPatterns.isEmpty {
                Section("mistake.pattern.detail.related".localized()) {
                    Text(summary.relatedPatterns.map(\.displayName).joined(separator: "、"))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(summary.pattern.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).font(.headline)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func format(_ date: Date?) -> String {
        date?.formatted(date: .abbreviated, time: .omitted) ?? "—"
    }
}
