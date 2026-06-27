//
//  StudyTimerLiveActivity.swift
//  StudyPulseWidget
//
//  Live Activity configuration for the StudyPulse Pomodoro timer.
//  Renders the Lock Screen banner and the four Dynamic Island
//  presentations (compact leading/trailing, expanded, minimal).
//
//  The design is intentionally minimal — each region carries at
//  most one piece of information so the Live Activity never
//  overflows the available safe area on the lock screen or the
//  Dynamic Island pill.
//

import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Localized String Helper

/// Widget extension does not have access to the main app's
/// `StringsLocalized.swift` extension, so we add a local copy that
/// resolves through the widget bundle's `Localizable.strings`.
extension String {
    fileprivate func localized() -> String {
        NSLocalizedString(self, comment: "")
    }
}

// MARK: - Widget Configuration

struct StudyTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StudyTimerActivityAttributes.self) { context in
            StudyTimerLockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.35))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    StudyTimerExpandedLeading(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    StudyTimerExpandedTrailing(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    StudyTimerExpandedBottom(context: context)
                }
            } compactLeading: {
                StudyTimerCompactLeading(context: context)
            } compactTrailing: {
                StudyTimerCompactTrailing(context: context)
            } minimal: {
                StudyTimerMinimalView(context: context)
            }
            .keylineTint(Color(hex: context.state.colorHex))
        }
    }
}

// MARK: - Lock Screen Banner

private struct StudyTimerLockScreenView: View {
    let context: ActivityViewContext<StudyTimerActivityAttributes>

    private var accent: Color { Color(hex: context.state.colorHex) }
    private var isTerminal: Bool {
        context.state.tier == "completed" || context.state.tier == "ended"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            mainRow
            progressBar
        }
        .padding(14)
        .background(lockScreenBackground)
    }

    private var header: some View {
        HStack(spacing: 6) {
            StudyTimerBrandMark(size: 16)
            Text(context.state.intensityLabel)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(statusSubtitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var statusSubtitle: String {
        switch context.state.tier {
        case "completed": return "Session Complete".localized()
        case "ended":     return "Session Ended".localized()
        case "paused":    return "Paused".localized()
        default:          return String(format: "%d min".localized(), context.attributes.totalMinutes)
        }
    }

    private var mainRow: some View {
        Text(timerText(from: context.state))
            .font(.system(size: 36, weight: .bold, design: .monospaced))
            .foregroundStyle(.primary)
            .monospacedDigit()
            .contentTransition(.numericText())
            .lineLimit(1)
    }

    private var progressBar: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(accent.opacity(0.18))
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(accent)
                .frame(width: lockScreenProgressWidth * progress(from: context.state))
        }
        .frame(width: lockScreenProgressWidth, height: 8)
    }

    /// Lock Screen 进度条固定宽度（比父容器窄，让整体更克制）。
    private let lockScreenProgressWidth: CGFloat = 280

    private var lockScreenBackground: some View {
        ZStack {
            Color.black.opacity(0.22)
            RadialGradient(
                colors: [accent.opacity(0.28), accent.opacity(0.0)],
                center: .topTrailing,
                startRadius: 4,
                endRadius: 200
            )
            .blendMode(.plusLighter)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        )
    }
}

// MARK: - Dynamic Island (Expanded)

private struct StudyTimerExpandedLeading: View {
    let context: ActivityViewContext<StudyTimerActivityAttributes>
    private var accent: Color { Color(hex: context.state.colorHex) }

    var body: some View {
        HStack(spacing: 4) {
            StudyTimerBrandMark(size: 16)
            Text(context.state.intensityLabel)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Circle()
                .fill(accent)
                .frame(width: 5, height: 5)
                .opacity(context.state.tier == "paused" ? 0 : 1)
        }
        .padding(.leading, 4)
        .layoutPriority(0)
    }
}

private struct StudyTimerExpandedTrailing: View {
    let context: ActivityViewContext<StudyTimerActivityAttributes>

    var body: some View {
        Text(timerText(from: context.state))
            .font(.system(size: 18, weight: .bold, design: .monospaced))
            .foregroundStyle(.primary)
            .monospacedDigit()
            .contentTransition(.numericText())
            .lineLimit(1)
            .layoutPriority(1)
    }
}

private struct StudyTimerExpandedBottom: View {
    let context: ActivityViewContext<StudyTimerActivityAttributes>
    private var accent: Color { Color(hex: context.state.colorHex) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(accent.opacity(0.18))
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(accent)
                    .frame(width: max(4, geo.size.width * progress(from: context.state)))
            }
            .frame(height: 8)
        }
        .frame(height: 8)
    }
}

// MARK: - Dynamic Island (Compact & Minimal)

private struct StudyTimerCompactLeading: View {
    let context: ActivityViewContext<StudyTimerActivityAttributes>
    private var accent: Color { Color(hex: context.state.colorHex) }

    var body: some View {
        StudyTimerBrandMark(size: 16, systemImage: intensitySF)
    }

    private var intensitySF: String {
        switch context.state.tier {
        case "peak":      return "bolt.fill"
        case "deepFocus": return "brain.fill"
        case "steady":    return "chart.bar.fill"
        case "light":     return "book.fill"
        case "recovery":  return "bed.double.fill"
        case "paused":    return "pause.fill"
        case "completed": return "checkmark"
        case "ended":     return "xmark"
        default:          return "waveform.path.ecg"
        }
    }
}

private struct StudyTimerCompactTrailing: View {
    let context: ActivityViewContext<StudyTimerActivityAttributes>

    var body: some View {
        Text(timerText(from: context.state))
            .font(.system(size: 15, weight: .bold, design: .monospaced))
            .foregroundStyle(.primary)
            .monospacedDigit()
            .contentTransition(.numericText())
            .lineLimit(1)
    }
}

private struct StudyTimerMinimalView: View {
    let context: ActivityViewContext<StudyTimerActivityAttributes>

    var body: some View {
        StudyTimerBrandMark(size: 16)
    }
}

// MARK: - Reusable Design Primitives

/// Small rounded brand mark — blue→indigo gradient with an SF Symbol.
/// Used in the Lock Screen header, the expanded Dynamic Island
/// leading region, the compact leading region, and the minimal
/// presentation.
struct StudyTimerBrandMark: View {
    var size: CGFloat = 18
    var systemImage: String = "waveform.path.ecg"

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "0A84FF"), Color(hex: "5856D6")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: systemImage)
                .font(.system(size: size * 0.55, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

/// Minimal circular progress indicator (no inner icon) used on the
/// Lock Screen main row.
struct StudyTimerProgressRing: View {
    let progress: Double
    let accent: Color
    var size: CGFloat = 38
    var lineWidth: CGFloat = 4

    var body: some View {
        ZStack {
            Circle()
                .stroke(accent.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Helpers

private func timerText(from state: StudyTimerActivityAttributes.ContentState) -> String {
    let m = state.remainingSeconds / 60
    let s = state.remainingSeconds % 60
    return String(format: "%02d:%02d", m, s)
}

private func progress(from state: StudyTimerActivityAttributes.ContentState) -> Double {
    guard state.totalSeconds > 0 else { return 0 }
    let value = Double(state.totalSeconds - state.remainingSeconds) / Double(state.totalSeconds)
    return min(max(value, 0), 1)
}

// MARK: - Color(hex:)

extension Color {
    /// Initialise a `Color` from a 6-digit (RRGGBB) or 8-digit
    /// (RRGGBBAA) hex string. The leading `#` is optional.
    init(hex: String) {
        var trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("#") { trimmed.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: trimmed).scanHexInt64(&value)

        let r, g, b, a: Double
        switch trimmed.count {
        case 6:
            r = Double((value & 0xFF0000) >> 16) / 255.0
            g = Double((value & 0x00FF00) >>  8) / 255.0
            b = Double( value & 0x0000FF       ) / 255.0
            a = 1.0
        case 8:
            r = Double((value & 0xFF000000) >> 24) / 255.0
            g = Double((value & 0x00FF0000) >> 16) / 255.0
            b = Double((value & 0x0000FF00) >>  8) / 255.0
            a = Double( value & 0x000000FF       ) / 255.0
        default:
            r = 0.5; g = 0.5; b = 0.5; a = 1.0
        }
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}


