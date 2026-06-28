//
//  AppStyle.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/6/6.
//

import SwiftUI

// MARK: - Style Config
nonisolated enum AppStyle {
    case minimal, literature, tech
    
    var cardCornerRadius: CGFloat {
        switch self {
        case .minimal: 12
        case .literature: 16
        case .tech: 10
        }
    }
    
    var cardBorderWidth: CGFloat {
        switch self {
        case .minimal: 0
        case .literature: 0
        case .tech: 1.5
        }
    }
    
    var sectionSpacing: CGFloat {
        switch self {
        case .minimal: 16
        case .literature: 20
        case .tech: 14
        }
    }
    
    var buttonCornerRadius: CGFloat {
        switch self {
        case .minimal: 12
        case .literature: 16
        case .tech: 10
        }
    }
    
    var statCardCornerRadius: CGFloat {
        switch self {
        case .minimal: 10
        case .literature: 14
        case .tech: 8
        }
    }
    
    var isDark: Bool {
        switch self {
        case .minimal, .literature: false
        case .tech: true
        }
    }
    
    /// Background gradient for tech style root views
    @ViewBuilder
    func rootBackground() -> some View {
        switch self {
        case .minimal, .literature:
            Color(.systemGroupedBackground)
        case .tech:
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
nonisolated enum CardBG {
    case card, exam, stat, quote, gradeRow, section
    
    @ViewBuilder
    func view(for style: AppStyle) -> some View {
        switch style {
        case .minimal:
            AnyView(Color(.secondarySystemGroupedBackground))
        case .literature:
            AnyView(Color(.secondarySystemGroupedBackground))
        case .tech:
            AnyView(techBackground)
        }
    }
    
    @ViewBuilder
    private var techBackground: some View {
        switch self {
        case .card:
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.08, green: 0.06, blue: 0.2).opacity(0.95),
                    Color(red: 0.12, green: 0.06, blue: 0.25).opacity(0.9)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .exam:
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.06, green: 0.04, blue: 0.15),
                    Color(red: 0.1, green: 0.05, blue: 0.2)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .stat:
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.06, blue: 0.22),
                    Color(red: 0.08, green: 0.05, blue: 0.18)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .quote:
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.08, green: 0.04, blue: 0.2),
                    Color(red: 0.15, green: 0.05, blue: 0.25)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .gradeRow:
            Color(red: 0.08, green: 0.06, blue: 0.15).opacity(0.8)
        case .section:
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
extension AppStyle {
    /// Primary text color (white for tech, system for others)
    func primaryTextColor() -> Color {
        isDark ? .white : .primary
    }
    
    /// Secondary text color
    func secondaryTextColor() -> Color {
        isDark ? .white.opacity(0.6) : .secondary
    }
    
    /// Tertiary text color
    func tertiaryTextColor() -> Color {
        isDark ? .white.opacity(0.4) : Color(.tertiaryLabel)
    }
    
    /// Accent button color (cyan-purple gradient for tech)
    @ViewBuilder
    func accentButtonBackground() -> some View {
        switch self {
        case .minimal, .literature:
            Color.accentColor
        case .tech:
            LinearGradient(
                gradient: Gradient(colors: [Color.cyan, Color.purple]),
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
    
    /// Neon glow border (cyan-purple gradient for tech, invisible for others)
    @ViewBuilder
    func neonBorder(width: CGFloat? = nil) -> some View {
        if isDark {
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
