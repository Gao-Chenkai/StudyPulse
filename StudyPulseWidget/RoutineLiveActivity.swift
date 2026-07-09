//
//  RoutineLiveActivity.swift
//  StudyPulseWidget
//
//  例程 Live Activity:Lock Screen + Dynamic Island 渲染。
//
//  Created for Plans & Routines spec (2026-07-09).
//

import SwiftUI
import ActivityKit
import WidgetKit

// 注:Widget target 内的 `String.localized()` 在 StudyTimerLiveActivity.swift
// 声明为 fileprivate,这里直接复用 NSLocalizedString 保证可访问。
private extension String {
    func wLocalized() -> String {
        NSLocalizedString(self, comment: "")
    }
}

struct RoutineLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RoutineActivityAttributes.self) { context in
            // Lock Screen / banner
            RoutineLockScreenView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "repeat.circle.fill")
                        .foregroundColor(Color(hex: context.attributes.colorHex))
                        .font(.title2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(formatRemaining(context.state.remainingSeconds))
                        .font(.caption.monospacedDigit().bold())
                        .foregroundColor(tierColor(context.state.tier))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.attributes.title)
                            .font(.headline)
                            .lineLimit(1)
                        if let sub = context.state.currentItemTitle {
                            Text(sub)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        ProgressView(value: context.state.progress)
                            .tint(Color(hex: context.attributes.colorHex))
                    }
                }
            } compactLeading: {
                Image(systemName: "repeat.circle.fill")
                    .foregroundColor(Color(hex: context.attributes.colorHex))
            } compactTrailing: {
                Text(formatRemaining(context.state.remainingSeconds))
                    .monospacedDigit()
                    .font(.caption2.bold())
            } minimal: {
                Image(systemName: "repeat.circle.fill")
                    .foregroundColor(Color(hex: context.attributes.colorHex))
            }
        }
    }

    private func formatRemaining(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        let m = seconds / 60
        return "\(m)m"
    }

    private func tierColor(_ tier: RoutineContentState.Tier) -> Color {
        switch tier {
        case .steady:   return .green
        case .warning:  return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Lock Screen View

private struct RoutineLockScreenView: View {
    let attributes: RoutineActivityAttributes
    let state: RoutineContentState

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(hex: attributes.colorHex).opacity(0.25))
                    .frame(width: 44, height: 44)
                Image(systemName: "repeat.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Color(hex: attributes.colorHex))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(attributes.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                if let sub = state.currentItemTitle {
                    Text(sub)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
                ProgressView(value: state.progress)
                    .tint(Color(hex: attributes.colorHex))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatRemaining(state.remainingSeconds))
                    .font(.title3.monospacedDigit().bold())
                    .foregroundColor(tierColor(state.tier))
                Text("left".wLocalized())
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(16)
    }

    private func formatRemaining(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        let m = seconds / 60
        let h = m / 60
        if h > 0 { return "\(h)h\(m % 60)m" }
        return "\(m)m"
    }

    private func tierColor(_ tier: RoutineContentState.Tier) -> Color {
        switch tier {
        case .steady:   return .green
        case .warning:  return .orange
        case .critical: return .red
        }
    }
}
