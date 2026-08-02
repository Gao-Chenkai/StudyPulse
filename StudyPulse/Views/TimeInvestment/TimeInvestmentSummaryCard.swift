import SwiftUI

struct TimeInvestmentSummaryCard: View {
    @Environment(RepositoryContainer.self) private var container

    private var aggregator: TimeInvestmentAggregator {
        TimeInvestmentAggregator(
            subjects: container.timeInvestmentRepo.subjects,
            subTasks: container.timeInvestmentRepo.subTasks,
            sessions: container.studySessionRepo.sessions
        )
    }

    private var streak: Int {
        StudyStreakCalculator.currentStreak(
            sessions: container.studySessionRepo.sessions.filter { $0.investmentTarget != nil }
        )
    }

    var body: some View {
        NavigationLink {
            TimeInvestmentView(container: container)
        } label: {
            VStack(alignment: .leading, spacing: DesignToken.Spacing.large) {
                HStack {
                    Label("time.investment.title".localized(), systemImage: "hourglass.bottomhalf.filled")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                    Spacer()
                    if !aggregator.unassignedSessions.isEmpty {
                        Label(
                            "\(aggregator.unassignedSessions.count)",
                            systemImage: "tray.full.fill"
                        )
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, DesignToken.Spacing.small)
                        .padding(.vertical, DesignToken.Spacing.tiny)
                        .foregroundStyle(.orange)
                        .background(.orange.opacity(0.12), in: Capsule())
                        .accessibilityLabel(
                            String(
                                format: "time.investment.unassigned.count".localized(),
                                aggregator.unassignedSessions.count
                            )
                        )
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: DesignToken.Spacing.medium) {
                    metric(
                        TimeInvestmentFormatter.hoursBadge(seconds: aggregator.totalAssignedSeconds),
                        label: "time.investment.total".localized(),
                        color: .blue
                    )
                    metric(
                        "\(container.timeInvestmentRepo.subjects.filter { !$0.isArchived }.count)",
                        label: "time.investment.activeProjects".localized(),
                        color: .purple
                    )
                    metric(
                        "\(streak)",
                        label: "time.investment.streakDays".localized(),
                        color: .orange
                    )
                }
            }
            .padding(DesignToken.Spacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSkin()
            .contentShape(Rectangle())
        }
        .buttonStyle(HoverableButtonStyle(hoverScale: 1.01))
        .accessibilityHint("time.investment.openHint".localized())
    }

    private func metric(_ value: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: DesignToken.Spacing.tiny) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
