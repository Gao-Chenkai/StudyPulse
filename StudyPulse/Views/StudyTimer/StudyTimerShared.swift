//
//  StudyTimerShared.swift
//  StudyPulse
//
//  Shared types and helpers used by the full-screen Study Timer modules
//  (TimerCard / SettingsSheet / HistoryList) in Views/StudyTimer/.
//

import SwiftUI
import os

// MARK: - Floating Orb

/// A single ambient particle that floats upward while the timer runs.
struct FloatingOrb: Identifiable {
    let id = UUID()
    var xRatio: CGFloat     // 0...1 horizontal position ratio
    var size: CGFloat
    var speed: Double        // seconds for one full cycle
    var phase: Double        // 0...1 starting phase
    var opacity: Double
}

// MARK: - Color Theme

/// Color theme for the timer ring, orbs, glow, and start button.
enum ColorTheme: String, CaseIterable, Identifiable {
    case aurora, sunset, ocean, forest, lavender, neon

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .aurora: return "Aurora".localized()
        case .sunset: return "Sunset".localized()
        case .ocean: return "Ocean".localized()
        case .forest: return "Forest".localized()
        case .lavender: return "Lavender".localized()
        case .neon: return "Neon".localized()
        }
    }

    var colors: [Color] {
        switch self {
        case .aurora:
            return [Color(red: 0.2, green: 0.8, blue: 0.5), Color(red: 0.1, green: 0.6, blue: 0.9), Color(red: 0.5, green: 0.3, blue: 0.9)]
        case .sunset:
            return [Color(red: 1.0, green: 0.4, blue: 0.2), Color(red: 1.0, green: 0.6, blue: 0.1), Color(red: 0.9, green: 0.2, blue: 0.5)]
        case .ocean:
            return [Color(red: 0.1, green: 0.5, blue: 0.9), Color(red: 0.0, green: 0.8, blue: 0.8), Color(red: 0.2, green: 0.3, blue: 0.9)]
        case .forest:
            return [Color(red: 0.2, green: 0.7, blue: 0.3), Color(red: 0.1, green: 0.5, blue: 0.2), Color(red: 0.6, green: 0.8, blue: 0.2)]
        case .lavender:
            return [Color(red: 0.6, green: 0.4, blue: 0.9), Color(red: 0.8, green: 0.3, blue: 0.7), Color(red: 0.4, green: 0.5, blue: 1.0)]
        case .neon:
            return [Color(red: 0.0, green: 1.0, blue: 0.5), Color(red: 1.0, green: 0.0, blue: 0.5), Color(red: 0.5, green: 0.0, blue: 1.0)]
        }
    }

    var primaryColor: Color { colors[0] }

    var icon: String {
        switch self {
        case .aurora: return "sparkles"
        case .sunset: return "sun.max.fill"
        case .ocean: return "water.waves"
        case .forest: return "leaf.fill"
        case .lavender: return "flower"
        case .neon: return "bolt.fill"
        }
    }
}

// MARK: - Intensity Helpers

/// Map the readiness algorithm's `StudyIntensity` to the icon / title shown
/// in the recommendation header.
enum StudyIntensityUI {
    static var icon: String {
        switch StudyTimerManager.shared.recommendedIntensity {
        case .peak: return "bolt.heart.fill"
        case .deepFocus: return "brain.head.profile"
        case .steady: return "chart.bar.fill"
        case .light: return "book.closed.fill"
        case .recovery: return "bed.double.fill"
        }
    }

    static var title: String {
        switch StudyTimerManager.shared.recommendedIntensity {
        case .peak: return "Peak Performance".localized()
        case .deepFocus: return "Deep Focus".localized()
        case .steady: return "Steady Rhythm".localized()
        case .light: return "Light Review".localized()
        case .recovery: return "Recovery".localized()
        }
    }
}

/// Reverse-map a `StudySuggestion` to a `StudyIntensity` by title match.
func intensityFromSuggestion(_ suggestion: StudySuggestion) -> StudyIntensity {
    let t = suggestion.title
    if t == "Peak Performance".localized() || t == "\u{5DC5}\u{5CF0}\u{53D1}\u{6325}\u{65E5}" { return .peak }
    if t.hasPrefix("Deep Focus") || t.hasPrefix("\u{6DF1}\u{5EA6}\u{5B66}\u{4E60}") || t == "\u{9002}\u{5408}\u{6DF1}\u{5EA6}\u{5B66}\u{4E60}".localized() { return .deepFocus }
    if t.hasPrefix("Steady") || t.hasPrefix("\u{7A33}\u{6001}") { return .steady }
    if t.hasPrefix("Light") || t.hasPrefix("\u{8F7B}\u{91CF}") || t.contains("Mistakes") || t.contains("\u{9519}\u{9898}") { return .light }
    if t.hasPrefix("Recovery") || t.hasPrefix("Rest") || t.contains("\u{6062}\u{590D}") || t.contains("\u{4F11}\u{606F}") { return .recovery }
    return .steady
}

// MARK: - Native Glass Circle

/// Liquid-glass circle used at the center of the timer ring in immersive
/// landscape mode. Falls back to `.regularMaterial` on iOS < 26.
@ViewBuilder
func nativeGlassCircle(diameter: CGFloat, opacity: Double = 1.0) -> some View {
    if #available(iOS 26.0, *) {
        Color.clear
            .frame(width: diameter, height: diameter)
            .glassEffect(.regular, in: Circle())
            .opacity(opacity)
    } else {
        Circle()
            .fill(.regularMaterial)
            .frame(width: diameter, height: diameter)
            .opacity(opacity)
    }
}
