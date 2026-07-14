//
//  HRVStatusSuggestionSection.swift
//  StudyPulse
//
//  HRV 卡片底部的"恢复准备度建议"区块:本地建议 + LLM 增强 + AI debug 入口。
//  Bottom "readiness suggestion" block of the HRV card: local suggestion +
//  LLM enhancement + AI debug entry.
//
//  Phase 3 拆分 (2026-07-14):原 `HRVStatusCard.swift` 抽出,可独立预览。
//

import SwiftUI

/// HRV 卡片底部的"恢复准备度建议"区块。
/// "Readiness suggestion" block shown under the HRV card.
struct HRVStatusSuggestionSection: View {
    /// 当前的 StudySuggestion(可能是本地或 LLM 增强版本)
    /// Current `StudySuggestion` (local or LLM-enhanced).
    let suggestion: StudySuggestion?
    /// 是否正在请求 LLM(显示 loading)
    /// Whether the LLM request is in flight (shows a loading state).
    let isLoadingLLM: Bool
    /// 是否可以请求 LLM(冷却是否结束)
    /// Whether the LLM can be requested (cooldown gate).
    let canRequestLLM: Bool
    /// LLM debug 入口是否启用(DEBUG 才显示)
    /// Whether to show the LLM debug entry (DEBUG only).
    let showLLMDebug: Bool
    /// 点击"立刻分析"按钮 / Tap "Analyze now".
    let onAnalyze: () -> Void
    /// 点击 AI debug 入口 / Tap AI debug entry.
    let onDebug: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("AI Suggestion".localized())
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)

                Spacer()

                if showLLMDebug {
                    Button(action: onDebug) {
                        HStack(spacing: 3) {
                            Image(systemName: "ladybug.fill")
                                .font(.caption2)
                            Text("LLM Debug")
                                .font(.caption2)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.orange.opacity(0.15)))
                        .foregroundColor(.orange)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let s = suggestion {
                Text(s.title)
                    .font(.headline)
                Text(s.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("No suggestion yet — pull to refresh.".localized())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            HStack {
                Spacer()
                Button {
                    onAnalyze()
                } label: {
                    HStack(spacing: 6) {
                        if isLoadingLLM {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text("Analyze Now".localized())
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(canRequestLLM ? Color.purple.opacity(0.18) : Color.gray.opacity(0.15))
                    )
                    .foregroundColor(canRequestLLM ? .purple : .gray)
                }
                .buttonStyle(.plain)
                .disabled(isLoadingLLM)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.tertiarySystemBackground))
        )
    }
}

// MARK: - Preview / 独立预览入口

#Preview("Suggestion - Loaded") {
    let s = StudySuggestion(
        icon: "leaf.fill",
        title: "Light recovery, gentle focus",
        description: "HRV is below your 30-day baseline. Use a short Pomodoro (25min) instead of deep work today.",
        priority: .low,
        color: .blue
    )
    HRVStatusSuggestionSection(
        suggestion: s,
        isLoadingLLM: false,
        canRequestLLM: true,
        showLLMDebug: true,
        onAnalyze: {},
        onDebug: {}
    )
    .padding()
}

#Preview("Suggestion - Loading") {
    HRVStatusSuggestionSection(
        suggestion: nil,
        isLoadingLLM: true,
        canRequestLLM: false,
        showLLMDebug: false,
        onAnalyze: {},
        onDebug: {}
    )
    .padding()
}
