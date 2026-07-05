//
//  QuickActionsCard.swift
//  StudyPulse
//
//  主页快捷操作卡:登记成绩 / 新建考试 / 新建错题 3 个入口。
//
//  Extracted from HomeView.swift during card-extraction refactor (2026-07-05).
//

import SwiftUI

/// 主页"快捷操作"卡片:3 个常用入口。
struct QuickActionsCard: View {
    @Environment(RepositoryContainer.self) private var container
    @State private var showingAddGrade = false
    @State private var showingNewExam = false
    @State private var showingNewMistake = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions".localized())
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)

            HStack(spacing: 12) {
                QuickActionButton(
                    title: "Add Grade".localized(),
                    icon: "plus.circle.fill",
                    color: .cyan,
                    action: { showingAddGrade = true }
                )

                QuickActionButton(
                    title: "New Exam".localized(),
                    icon: "calendar.badge.plus",
                    color: .purple,
                    action: { showingNewExam = true }
                )

                QuickActionButton(
                    title: "New Mistake".localized(),
                    icon: "pencil.tip.crop.circle.badge.plus",
                    color: .orange,
                    action: { showingNewMistake = true }
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(
            color: Color.black.opacity(0.05),
            radius: 10,
            x: 0,
            y: 4
        )
        .sheet(isPresented: $showingAddGrade) {
            AddGradeView()
                .environment(container)
                .adaptiveSheet()
        }
        .sheet(isPresented: $showingNewExam) {
            NewExamSetView()
                .adaptiveSheet()
        }
        .sheet(isPresented: $showingNewMistake) {
            NewMistakeSetView()
                .environment(container)
                .adaptiveSheet()
        }
    }
}

// MARK: - 快捷操作按钮

/// QuickActionsCard 内的单个操作按钮(图标 + 标题 + 点击缩放反馈)。
struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.2), color.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 60)

                    Image(systemName: icon)
                        .font(.system(size: 28))
                        .foregroundColor(color)
                }

                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 缩放按钮样式

/// QuickActionButton 使用的按下缩放反馈。
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
