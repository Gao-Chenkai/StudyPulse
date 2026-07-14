//
//  DueReviewBanner.swift
//  StudyPulse
//
//  "待复习" 横幅:突出显示到期的错题数量,引导用户进入闪卡模式。
//  "Due review" banner: surfaces the number of due mistakes and nudges the
//  user into the flashcard study flow.
//
//  Phase 3 拆分 (2026-07-14):原 `MistakeView.swift` 抽出,独立可预览。
//

import SwiftUI

/// 「待复习」横幅:突出显示到期的错题数量,引导用户进入闪卡模式
/// "Due review" banner: surfaces the number of due mistakes and
/// nudges the user into the flashcard study flow.
struct DueReviewBanner: View {
    /// 概览数据(包含 due / upcoming)
    /// Overview payload (due / upcoming counts).
    let overview: SRSOverview
    /// 点击回调(进入闪卡模式)
    /// Tap callback (jumps to flashcard mode).
    let onStart: () -> Void

    var body: some View {
        Button(action: onStart) {
            bannerContent
        }
        .buttonStyle(.plain)
        .debugLayoutBoundsAuto()
    }

    @ViewBuilder
    private var bannerContent: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 48, height: 48)
                Image(systemName: "rectangle.stack.fill")
                    .font(.title3)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Time to Review".localized())
                        .font(.headline)
                        .foregroundColor(.primary)
                    if overview.dueCount > 0 {
                        Text("\(overview.dueCount)")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.red))
                    }
                }
                let subtitle = String(format: "%d due · %d upcoming this week".localized(), overview.dueCount, overview.upcomingCount)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.12), Color.blue.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(LinearGradient(
                    colors: [.purple.opacity(0.35), .blue.opacity(0.20)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ), lineWidth: 1)
        )
    }
}

// MARK: - Preview / 独立预览入口

#Preview("Has Due") {
    DueReviewBanner(overview: SRSOverview(dueCount: 5, upcomingCount: 12, totalEnrolled: 30)) {}
        .padding()
}

#Preview("No Due") {
    DueReviewBanner(overview: SRSOverview(dueCount: 0, upcomingCount: 4, totalEnrolled: 30)) {}
        .padding()
}
