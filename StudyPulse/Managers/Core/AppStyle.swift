//
//  AppStyle.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/6/6.
//

import SwiftUI

// MARK: - Style Config
// MARK: - 风格配置 / Style config
/// 全局视觉风格枚举：minimal / literature / tech。
/// Global visual style: minimal / literature / tech.
nonisolated enum AppStyle {
    case minimal, literature, tech

    /// 卡片圆角半径。
    /// Card corner radius.
    var cardCornerRadius: CGFloat {
        switch self {
        case .minimal: 12
        case .literature: 16
        case .tech: 10
        }
    }

    /// 卡片描边宽度。
    /// Card border width.
    var cardBorderWidth: CGFloat {
        switch self {
        case .minimal: 0
        case .literature: 0
        case .tech: 1.5
        }
    }

    /// 区域之间的垂直间距。
    /// Vertical spacing between sections.
    var sectionSpacing: CGFloat {
        switch self {
        case .minimal: 16
        case .literature: 20
        case .tech: 14
        }
    }

    /// 按钮圆角半径。
    /// Button corner radius.
    var buttonCornerRadius: CGFloat {
        switch self {
        case .minimal: 12
        case .literature: 16
        case .tech: 10
        }
    }

    /// 统计卡圆角半径（比普通卡片略小）。
    /// Stat-card corner radius (slightly smaller than a regular card).
    var statCardCornerRadius: CGFloat {
        switch self {
        case .minimal: 10
        case .literature: 14
        case .tech: 8
        }
    }

    /// 是否为深色风格。
    /// Whether the style is dark-themed.
    var isDark: Bool {
        switch self {
        case .minimal, .literature: false
        case .tech: true
        }
    }

    /// Background gradient for tech style root views
    /// Tech 风格根视图的背景渐变。
    @ViewBuilder
    func rootBackground() -> some View {
        switch self {
        case .minimal, .literature:
            // 默认系统分组背景 / Default system grouped background
            Color(.systemGroupedBackground)
        case .tech:
            // 深蓝紫渐变 / Deep blue-purple gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color(red: 0.1, green: 0.05, blue: 0.2),
                    Color(red: 0.05, green: 0.08, blue: 0.18)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Card Background Provider
// MARK: - 卡片背景 / Card background
/// 按卡片角色提供合适的背景。
/// Provides the appropriate background per card role.
nonisolated enum CardBG {
    case card, exam, stat, quote, gradeRow, section

    @ViewBuilder
    func view(for style: AppStyle) -> some View {
        switch style {
        case .minimal:
            // minimal / literature 都用 system 二级分组背景
            // minimal / literature both use system secondary grouped background.
            AnyView(Color(.secondarySystemGroupedBackground))
        case .literature:
            AnyView(Color(.secondarySystemGroupedBackground))
        case .tech:
            // tech 走自定义渐变 / tech uses a custom gradient
            AnyView(techBackground)
        }
    }

    @ViewBuilder
    private var techBackground: some View {
        switch self {
        case .card:
            // 通用卡片：紫蓝渐变 / Generic card: blue-purple gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.08, green: 0.06, blue: 0.2).opacity(0.95),
                    Color(red: 0.12, green: 0.06, blue: 0.25).opacity(0.9)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .exam:
            // 考试卡：偏深蓝紫 / Exam card: deeper blue-purple
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.06, green: 0.04, blue: 0.15),
                    Color(red: 0.1, green: 0.05, blue: 0.2)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .stat:
            // 统计卡：暗紫调 / Stat card: dark purple
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.06, blue: 0.22),
                    Color(red: 0.08, green: 0.05, blue: 0.18)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .quote:
            // 金句卡：紫调更亮 / Quote card: brighter purple
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.08, green: 0.04, blue: 0.2),
                    Color(red: 0.15, green: 0.05, blue: 0.25)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .gradeRow:
            // 成绩行：单色半透明 / Grade row: semi-transparent solid
            Color(red: 0.08, green: 0.06, blue: 0.15).opacity(0.8)
        case .section:
            // Section 容器：与通用卡相同 / Section container: same as generic card
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.08, green: 0.06, blue: 0.2).opacity(0.95),
                    Color(red: 0.1, green: 0.05, blue: 0.22).opacity(0.9)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Style-aware Colors
// MARK: - 风格相关颜色 / Style-aware colors
extension AppStyle {
    /// Primary text color (white for tech, system for others)
    /// 主文本颜色（tech 用白色，其他用系统 primary）。
    func primaryTextColor() -> Color {
        isDark ? .white : .primary
    }

    /// Secondary text color
    /// 次要文本颜色。
    func secondaryTextColor() -> Color {
        isDark ? .white.opacity(0.6) : .secondary
    }

    /// Tertiary text color
    /// 三级文本颜色。
    func tertiaryTextColor() -> Color {
        isDark ? .white.opacity(0.4) : Color(.tertiaryLabel)
    }

    /// Accent button color (cyan-purple gradient for tech)
    /// 主按钮背景（tech 用青紫渐变）。
    @ViewBuilder
    func accentButtonBackground() -> some View {
        switch self {
        case .minimal, .literature:
            // 跟随系统 AccentColor / Follows the system AccentColor
            Color.accentColor
        case .tech:
            // tech 用青→紫渐变 / tech uses a cyan→purple gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.cyan, Color.purple]),
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    /// Neon glow border (cyan-purple gradient for tech, invisible for others)
    /// 霓虹描边（tech 用青紫渐变，其他风格不绘制）。
    @ViewBuilder
    func neonBorder(width: CGFloat? = nil) -> some View {
        if isDark {
            // width 为 nil 时按 cardCornerRadius 画圆角矩形，否则按 0 画矩形（线条/分隔等场景）
            // width=nil draws a rounded rect with cardCornerRadius; otherwise a plain rect (lines/dividers).
            RoundedRectangle(cornerRadius: width != nil ? 0 : cardCornerRadius)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.cyan.opacity(0.3), Color.purple.opacity(0.3)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: width ?? 1
                )
        } else {
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.clear, lineWidth: 0)
        }
    }

    /// Stat card border (cyan micro-glow for tech)
    /// 统计卡描边（tech 用青色微光）。
    @ViewBuilder
    func statCardBorder(cornerRadius: CGFloat? = nil) -> some View {
        if isDark {
            RoundedRectangle(cornerRadius: cornerRadius ?? statCardCornerRadius)
                .stroke(Color.cyan.opacity(0.25), lineWidth: 1)
        } else {
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.clear, lineWidth: 0)
        }
    }

    /// Cyan border for small items (tech only)
    /// 小物件的青色描边（仅 tech）。
    @ViewBuilder
    func cyanBorder(cornerRadius: CGFloat) -> some View {
        if isDark {
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.cyan.opacity(0.2), lineWidth: 0.5)
        } else {
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.clear, lineWidth: 0)
        }
    }

    /// Exam card border (tech: cyan+purple, others: purple)
    /// 考试卡描边（tech 青紫，其他风格单紫色）。
    @ViewBuilder
    func cardBorder(cornerRadius: CGFloat? = nil) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius ?? cardCornerRadius)
            .stroke(
                isDark
                    ? AnyShapeStyle(LinearGradient(gradient: Gradient(colors: [Color.cyan.opacity(0.5), Color.purple.opacity(0.5)]), startPoint: .leading, endPoint: .trailing))
                    : AnyShapeStyle(Color.purple.opacity(0.5)),
                lineWidth: cardBorderWidth
            )
    }
}
