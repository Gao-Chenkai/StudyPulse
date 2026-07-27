import SwiftUI

struct ExamReversePlannerHomeCard: View {
    @Environment(RepositoryContainer.self) private var container
    let onOpen: () -> Void

    private var latestGoal: ExamGoal? {
        container.examPlanRepo.goals.sorted { $0.createdAt > $1.createdAt }.first
    }

    private var daysRemaining: Int? {
        guard let latestGoal else { return nil }
        return max(0, Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: latestGoal.examDate)
        ).day ?? 0)
    }

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: DesignToken.Spacing.medium) {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .font(.title2)
                        .foregroundStyle(.indigo)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("exam.reverse.planner.title".localized())
                            .font(DesignToken.Font.titleSmall)
                            .foregroundStyle(.primary)
                        Text("exam.reverse.planner.subtitle".localized())
                            .font(DesignToken.Font.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }

                if let goal = latestGoal, let daysRemaining {
                    HStack(spacing: DesignToken.Spacing.medium) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(goal.examName)
                                .font(DesignToken.Font.bodyBold)
                                .lineLimit(1)
                            Text(goal.subject)
                                .font(DesignToken.Font.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(String(format: "exam.reverse.planner.gap".localized(), goal.targetScore - goal.currentScore))
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(.teal)
                            Text(String(format: "exam.reverse.planner.days".localized(), daysRemaining))
                                .font(DesignToken.Font.caption)
                                .foregroundStyle(daysRemaining <= 3 ? .red : .secondary)
                        }
                    }
                    .padding(DesignToken.Spacing.medium)
                    .background(Color.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: DesignToken.CornerRadius.medium))
                } else {
                    Label("exam.reverse.planner.cta".localized(), systemImage: "plus.circle.fill")
                        .font(DesignToken.Font.bodyBold)
                        .foregroundStyle(.indigo)
                }
            }
            .padding(DesignToken.Spacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSkin()
        }
        .buttonStyle(.plain)
    }
}
