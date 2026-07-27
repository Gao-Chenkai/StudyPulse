import SwiftUI

struct ExamPlanResultView: View {
    let goal: ExamGoal
    let plan: ExamPlan
    let onRegenerate: () -> Void
    let onDelete: () -> Void
    let onEditGoal: () -> Void

    private var daysRemaining: Int {
        max(0, Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: goal.examDate)
        ).day ?? 0)
    }

    private var sortedWeakPoints: [WeakPoint] {
        plan.weakPoints.sorted { $0.priority < $1.priority }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignToken.Spacing.large) {
                heroCard
                section(title: "exam.reverse.planner.weak.points".localized(), icon: "target") {
                    if plan.weakPoints.isEmpty {
                        Text("exam.reverse.planner.empty.weak.points".localized())
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(sortedWeakPoints) { point in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(point.priority)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 24, height: 24)
                                    .background(Color.indigo, in: Circle())
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(point.topic)
                                        .font(DesignToken.Font.bodyBold)
                                    Text(String(format: "exam.reverse.planner.mastery".localized(), point.mastery * 100))
                                        .font(DesignToken.Font.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(String(format: "+%.1f", point.possibleScoreGain))
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(.teal)
                            }
                            if point.id != sortedWeakPoints.last?.id {
                                Divider()
                            }
                        }
                    }
                }
                section(title: "exam.reverse.planner.phases".localized(), icon: "arrow.trianglehead.branch") {
                    ForEach(Array(plan.phases.enumerated()), id: \.element.id) { index, phase in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(spacing: 0) {
                                Circle().fill(Color.teal).frame(width: 12, height: 12)
                                if index < plan.phases.count - 1 {
                                    Rectangle().fill(Color.teal.opacity(0.25)).frame(width: 2, height: 44)
                                }
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(phase.name).font(DesignToken.Font.bodyBold)
                                    Spacer()
                                    Text(phase.dayRange).font(DesignToken.Font.caption).foregroundStyle(.secondary)
                                }
                                Text(phase.goal).font(DesignToken.Font.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                section(title: "exam.reverse.planner.daily.tasks".localized(), icon: "calendar") {
                    if plan.dailyTasks.isEmpty {
                        Text("exam.reverse.planner.empty.daily.tasks".localized()).foregroundStyle(.secondary)
                    } else {
                        ForEach(plan.dailyTasks) { task in
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(String(format: "exam.reverse.planner.day".localized(), task.dayOffset))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.indigo)
                                    Spacer()
                                    Text("\(task.durationMinutes) min")
                                        .font(DesignToken.Font.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(task.taskTitle).font(DesignToken.Font.bodyBold)
                                if !task.reason.isEmpty {
                                    Text("\("exam.reverse.planner.reason".localized()): \(task.reason)")
                                        .font(DesignToken.Font.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                actionButtons
            }
            .padding(.horizontal, DesignToken.Spacing.secondaryHorizontal)
            .padding(.vertical, DesignToken.Spacing.large)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.badge.clock").foregroundStyle(.indigo)
                Text(goal.examName).font(DesignToken.Font.titleSmall)
                Spacer()
            }
            Text(String(format: "exam.reverse.planner.days".localized(), daysRemaining))
                .font(DesignToken.Font.caption)
                .foregroundStyle(daysRemaining <= 3 ? .red : .secondary)
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("\(goal.currentScore.cleanScore)").font(.title2.weight(.bold).monospacedDigit())
                Image(systemName: "arrow.right").foregroundStyle(.secondary)
                Text("\(goal.targetScore.cleanScore)").font(.title2.weight(.bold).monospacedDigit()).foregroundStyle(.indigo)
                Spacer()
                Text(String(format: "exam.reverse.planner.improve".localized(), plan.improvementTarget))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.teal)
            }
            if !plan.summary.isEmpty {
                Text(plan.summary).font(DesignToken.Font.body).foregroundStyle(.secondary)
            }
        }
        .padding(DesignToken.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSkin()
    }

    private func section<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DesignToken.Spacing.medium) {
            Label(title, systemImage: icon).font(DesignToken.Font.titleSmall)
            content()
        }
        .padding(DesignToken.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSkin()
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button(action: onRegenerate) {
                Label("exam.reverse.planner.regenerate".localized(), systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
            HStack {
                Button("exam.reverse.planner.edit.goal".localized(), action: onEditGoal)
                    .frame(maxWidth: .infinity)
                Button("exam.reverse.planner.delete".localized(), role: .destructive, action: onDelete)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }
}

private extension Double {
    var cleanScore: String {
        truncatingRemainder(dividingBy: 1) == 0 ? String(Int(self)) : String(format: "%.1f", self)
    }
}
