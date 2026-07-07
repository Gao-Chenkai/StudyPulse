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

                // "New Mistake" 在 iPad 上走 NavigationLink 直接推到 HomeView 的 NavigationStack,
                // 配合传 false 让 NewMistakeSetView 不再包自己的 stack;iPhone 继续走 sheet。
                // On iPad, push NewMistakeSetView directly onto HomeView's stack
                // (useInternalNavigationStack: false). iPhone still uses the sheet.
                if UIDevice.current.userInterfaceIdiom == .pad {
                    QuickActionButton(
                        title: "New Mistake".localized(),
                        icon: "pencil.tip.crop.circle.badge.plus",
                        color: .orange,
                        destination: {
                            NewMistakeSetView(usesInternalNavigationStack: false)
                                .environment(container)
                                .adaptiveSheet()
                        }
                    )
                } else {
                    QuickActionButton(
                        title: "New Mistake".localized(),
                        icon: "pencil.tip.crop.circle.badge.plus",
                        color: .orange,
                        action: { showingNewMistake = true }
                    )
                }
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
        .debugLayoutBoundsAuto()
    }
}

// MARK: - 快捷操作按钮

/// QuickActionsCard 内的单个操作按钮(图标 + 标题 + 点击缩放反馈)。
/// 在 iPad 上,如果提供 `navigationDestination`,按钮会渲染为 `NavigationLink`
/// 直接推到父级 NavigationStack,这样能给用户"安全感",不会误触关掉整个表单页。
struct QuickActionButton<Destination: View>: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    @ViewBuilder let destination: (() -> Destination)?

    /// 默认 action 模式(走 sheet / 自定义 action)。
    init(
        title: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) where Destination == EmptyView {
        self.title = title
        self.icon = icon
        self.color = color
        self.action = action
        self.destination = nil
    }

    /// iPad 模式:提供 destination 后按钮渲染为 NavigationLink,直接推到父级 stack。
    /// iPad mode: when `destination` is provided the button becomes a
    /// `NavigationLink` pushed onto the parent stack, avoiding the sheet
    /// dismissal and giving the user a sense of "groundedness" while editing.
    init(
        title: String,
        icon: String,
        color: Color,
        destination: @escaping () -> Destination
    ) {
        self.title = title
        self.icon = icon
        self.color = color
        self.action = {}
        self.destination = destination
    }

    @State private var isPressed = false

    /// 共享的图标 + 标题 内容,被 Button 和 NavigationLink 共用。
    @ViewBuilder
    private var labelContent: some View {
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

    var body: some View {
        if let destination {
            // iPad: NavigationLink 直接推到父级 NavigationStack
            // iPad: push onto the parent stack via NavigationLink
            NavigationLink {
                destination()
            } label: {
                labelContent
            }
            .buttonStyle(ScaleButtonStyle())
            .frame(maxWidth: .infinity)
        } else {
            // iPhone / 无 destination: 走 Button + 自定义 action
            // iPhone / no destination: regular Button + action
            Button(action: action) {
                labelContent
            }
            .buttonStyle(ScaleButtonStyle())
            .frame(maxWidth: .infinity)
        }
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
