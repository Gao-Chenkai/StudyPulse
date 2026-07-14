//
//  FitnessRingView.swift
//  StudyPulse
//
//  iOS Activity-ring 风格的同心进度环:单环,带色彩梯度。
//  An iOS Activity-ring style concentric progress ring with a color
//  gradient based on progress.
//
//  Phase 3 拆分 (2026-07-14):原 `HRVStatusCard.swift` 抽出,可独立预览。
//

import SwiftUI

/// iOS Activity-ring 风格的同心进度环。
/// An iOS Activity-ring style concentric progress ring.
struct FitnessRingView: View {
    /// 进度(0-1)
    /// Progress (0-1).
    let progress: Double
    /// 环线宽 / Line width.
    var lineWidth: CGFloat = 4
    /// 环尺寸(用于 frame 内的留白)/ Ring size.
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(Color.secondary.opacity(0.18), lineWidth: lineWidth)

            // Foreground progress
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(
                    AngularGradient(
                        colors: gradientColors,
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: progress)
        }
        .frame(width: size, height: size)
    }

    private var gradientColors: [Color] {
        switch progress {
        case ..<0.34: return [.red, .orange]
        case ..<0.7:  return [.orange, .yellow]
        case ..<1.0:  return [.green, .mint]
        default:      return [.mint, .green]
        }
    }

    /// Color used by the surrounding tile to match the ring state.
    /// 外层 tile 用来匹配 ring 状态的颜色。
    static func colorFor(progress: Double) -> Color {
        // 进度阈值:<0.34 红,<0.7 橙,<1.0 蓝,其余绿
        // Progress thresholds: <0.34 red, <0.7 orange, <1.0 blue, otherwise green.
        switch progress {
        case ..<0.34: return .red
        case ..<0.7:  return .orange
        case ..<1.0:  return .blue
        default:      return .green
        }
    }
}

// MARK: - Preview / 独立预览入口

#Preview("Fitness Ring") {
    HStack(spacing: 16) {
        FitnessRingView(progress: 0.25, size: 50)
        FitnessRingView(progress: 0.5, size: 50)
        FitnessRingView(progress: 0.85, size: 50)
        FitnessRingView(progress: 1.0, size: 50)
    }
    .padding()
}
