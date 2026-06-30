//
//  TodoRowView.swift
//  StudyPulse
//
//  「待办」页统一行卡片：渲染 Exam / Comprehensive Exam / Homework / Reading 四种类型。
//  Unified row used by the Todo page to render exam / comprehensive exam / homework / reading entries.
//

import SwiftUI

// MARK: - TodoRowView

/// 统一行：传入一个 TodoEntry 渲染。
/// Renders a single todo entry with a type label and importance / completion state.
struct TodoRowView: View {
    let entry: TodoEntry
    /// 点击行时的回调（由父视图用来 push 详情）
    var onTap: (() -> Void)? = nil
    /// 点击作业/阅读行的完成按钮时的回调
    var onToggleCompletion: (() -> Void)? = nil
    @State private var animateIn = false

    private var daysRemaining: Int {
        let components = Calendar.current.dateComponents([.day], from: Date(), to: entry.date)
        return max(0, components.day ?? 0)
    }

    private var timeProgress: Double {
        // 距截止 0~30 天线性映射，超过 30 天视为 1
        min(Double(daysRemaining) / 30.0, 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                // 完成态勾选（仅作业 / 阅读）
                if entry.kind == .homework || entry.kind == .reading {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            onToggleCompletion?()
                        }
                    } label: {
                        Image(systemName: entry.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundColor(entry.isCompleted ? Color(.systemGreen) : Color(.tertiaryLabel))
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title)
                        .font(.headline)
                        .strikethrough(entry.isCompleted, color: Color(.secondaryLabel))
                        .foregroundColor(entry.isCompleted ? Color(.secondaryLabel) : Color(.label))
                        .lineLimit(2)
                    if !entry.subject.isEmpty {
                        Text(entry.subject.localized())
                            .font(.caption)
                            .foregroundColor(Color(.secondaryLabel))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                typeTag
            }

            // 日期范围（多日考试 / 单日）
            dateRow
                .font(.caption)
                .foregroundColor(Color(.secondaryLabel))

            // 进度 / 剩余时间
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Time Left".localized())
                        .font(.caption2)
                        .foregroundColor(Color(.secondaryLabel))
                    ProgressView(value: timeProgress, total: 1.0)
                        .tint(timeLeftColor)
                        .scaleEffect(x: 1, y: 1.2, anchor: .center)
                    Text(daysRemaining > 0 ? "\(daysRemaining) " + "days".localized() : timeLeftLabel)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(daysRemaining > 2 ? Color(.secondaryLabel) : Color(.systemRed))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if entry.kind == .exam || entry.kind == .comprehensiveExam {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mastery".localized())
                            .font(.caption2)
                            .foregroundColor(Color(.secondaryLabel))
                        ProgressView(value: Double(masteryDegree), total: 100.0)
                            .tint(masteryColor)
                            .scaleEffect(x: 1, y: 1.2, anchor: .center)
                        Text("\(masteryDegree)%")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(masteryDegree <= 5 ? Color(.systemRed) : Color(.secondaryLabel))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reminder".localized())
                            .font(.caption2)
                            .foregroundColor(Color(.secondaryLabel))
                        Text(reminderTimeText)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(reminderColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemGroupedBackground))

                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        LinearGradient(
                            colors: [
                                typeColor.opacity(0.25),
                                typeColor.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .shadow(
            color: Color.black.opacity(0.05),
            radius: 6,
            x: 0,
            y: 3
        )
        .opacity(entry.isCompleted ? 0.55 : 1.0)
        .hoverHighlight()
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 15)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                animateIn = true
            }
        }
    }

    // MARK: - 子组件

    /// 顶部右侧类型标签（Exam / Homework / Reading）
    @ViewBuilder
    private var typeTag: some View {
        Text(typeShortLabel)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(typeColor.opacity(0.15))
            )
            .foregroundColor(typeColor)
    }

    /// 顶部日期行：单日 / 多日
    @ViewBuilder
    private var dateRow: some View {
        if let end = entry.endDate, !Calendar.current.isDate(entry.date, inSameDayAs: end) {
            Text("\(entry.date.formatted(date: .abbreviated, time: .omitted)) - \(end.formatted(date: .abbreviated, time: .omitted))")
        } else {
            Text("\(entry.date.formatted(date: .abbreviated, time: .shortened))")
        }
    }

    // MARK: - 派生量

    private var masteryDegree: Int {
        if let exam = entry.exam { return exam.masteryDegree }
        if let comp = entry.comprehensiveExam { return comp.masteryDegree }
        return 0
    }

    private var typeColor: Color {
        switch entry.kind {
        case .exam: return Color(.systemBlue)
        case .comprehensiveExam: return Color(.systemPurple)
        case .homework: return Color(.systemGreen)
        case .reading: return Color(.systemIndigo)
        }
    }

    private var typeShortLabel: String {
        switch entry.kind {
        case .exam: return "Exam".localized()
        case .comprehensiveExam: return "Compre.".localized()
        case .homework: return "Homework".localized()
        case .reading: return "Reading".localized()
        }
    }

    private var timeLeftLabel: String {
        switch entry.kind {
        case .homework, .reading: return "Due today".localized()
        case .exam, .comprehensiveExam: return "Today!".localized()
        }
    }

    private var timeLeftColor: Color {
        if daysRemaining <= 1 {
            return Color(.systemRed)
        } else if daysRemaining <= 3 {
            return Color(.systemOrange)
        } else {
            return Color(.systemGreen)
        }
    }

    private var masteryColor: Color {
        if masteryDegree <= 20 { return Color(.systemRed) }
        if masteryDegree <= 60 { return Color(.systemOrange) }
        return Color(.systemGreen)
    }

    private var reminderColor: Color {
        guard let task = entry.taskItem else { return Color(.secondaryLabel) }
        if entry.isCompleted { return Color(.secondaryLabel) }
        if task.reminderDate < Date() { return Color(.systemRed) }
        let hours = Calendar.current.dateComponents([.hour], from: Date(), to: task.reminderDate).hour ?? 0
        if hours <= 24 { return Color(.systemOrange) }
        return Color(.systemBlue)
    }

    private var reminderTimeText: String {
        guard let task = entry.taskItem else { return "—" }
        return task.reminderDate.formatted(date: .abbreviated, time: .shortened)
    }
}
