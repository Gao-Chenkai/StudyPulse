//
//  PlantAnimator.swift
//  StudyPulse
//
//  植物动画辅助 view：
//  - FloatingSparkle：飘动光点（flourish+ 出现）
//  - FallingLeaf：凋落叶（withered 时出现）
//  - StageTransitionDriver：阶段切换 spring
//
//  全部由 TimelineView 驱动或显式 @State + withAnimation。
//

import SwiftUI

// MARK: - Floating Sparkle

/// 单颗飘动光点。TimelineView(.animation) 驱动，60fps 平滑运动。
/// A single floating sparkle. Driven by TimelineView(.animation).
struct FloatingSparkle: View {
    let index: Int      // 用于相位差，避免多颗光点同步
    let color: Color
    let size: CGFloat
    let origin: CGPoint // 起点（茎顶或花朵中心）
    let radius: CGFloat // 飘动范围半径

    init(index: Int, color: Color, size: CGFloat = 4, origin: CGPoint, radius: CGFloat = 22) {
        self.index = index
        self.color = color
        self.size = size
        self.origin = origin
        self.radius = radius
    }

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let phase = CGFloat(t.truncatingRemainder(dividingBy: 4.0)) / 4.0
            let angle = (phase * 2 * .pi) + CGFloat(index) * (.pi * 2 / 5)
            let bob = sin(phase * 2 * .pi + CGFloat(index) * 0.6) * radius * 0.6
            let x = origin.x + cos(angle) * radius
            let y = origin.y + bob
            let opacity = 0.35 + 0.65 * abs(sin(phase * .pi * 2 + CGFloat(index)))
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .opacity(opacity)
                .position(x: x, y: y)
                .blur(radius: 1.2)
        }
    }
}

// MARK: - Falling Leaf

/// 单片凋落叶，重力下落。
/// A single withered falling leaf driven by gravity.
struct FallingLeaf: View {
    let index: Int
    let color: Color
    let startPoint: CGPoint
    let size: CGFloat

    @State private var dropOffset: CGFloat = 0
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1

    var body: some View {
        // 凋落叶：使用 .rotationEffect 替代 Shape rotation
        Path { p in
            let h: CGFloat = size * 2.2
            let w: CGFloat = size
            let midX: CGFloat = w / 2
            let topY: CGFloat = 0
            let bottomY: CGFloat = h
            let quarter: CGFloat = h * 0.25
            p.move(to: CGPoint(x: midX, y: topY))
            p.addQuadCurve(to: CGPoint(x: midX + w * 0.5, y: h * 0.5 - h * 0.05),
                           control: CGPoint(x: midX + w * 0.45, y: topY + quarter))
            p.addQuadCurve(to: CGPoint(x: midX, y: bottomY),
                           control: CGPoint(x: midX + w * 0.5, y: bottomY - quarter))
            p.addQuadCurve(to: CGPoint(x: midX - w * 0.5, y: h * 0.5 - h * 0.05),
                           control: CGPoint(x: midX - w * 0.5, y: bottomY - quarter))
            p.addQuadCurve(to: CGPoint(x: midX, y: topY),
                           control: CGPoint(x: midX - w * 0.45, y: topY + quarter))
            p.closeSubpath()
        }
        .fill(color)
        .rotationEffect(.degrees(rotation))
        .frame(width: size, height: size * 2.2)
        .position(x: startPoint.x + CGFloat(index) * 6,
                  y: startPoint.y + dropOffset)
        .opacity(opacity)
        .onAppear {
            let duration = 1.6 + Double(index) * 0.15
            withAnimation(.easeIn(duration: duration).delay(0.1 + Double(index) * 0.18)) {
                dropOffset = 80 + CGFloat(index) * 14
                rotation = Double.random(in: 60...180) * (index % 2 == 0 ? 1 : -1)
                opacity = 0
            }
        }
    }
}

// MARK: - Stage Transition Driver

/// 阶段切换的 spring + 缩放 + 透明度过渡修饰符。
/// Modifier that drives the stage-change spring transition.
struct StageTransitionDriver: ViewModifier {
    let stage: PlantStage

    func body(content: Content) -> some View {
        content
            .transition(.scale.combined(with: .opacity))
            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: stage)
    }
}

extension View {
    /// 应用阶段切换动画（spring 缩放+透明度）。
    /// Apply the stage-change spring + scale transition.
    func plantStageTransition(_ stage: PlantStage) -> some View {
        modifier(StageTransitionDriver(stage: stage))
    }
}

// MARK: - Previews

#Preview("Sparkles") {
    ZStack {
        Color.black.opacity(0.05)
        ForEach(0..<5, id: \.self) { i in
            FloatingSparkle(
                index: i,
                color: .yellow,
                size: 4,
                origin: CGPoint(x: 100, y: 100),
                radius: 30
            )
        }
    }
    .frame(width: 220, height: 200)
}

#Preview("FallingLeaf") {
    ZStack {
        ForEach(0..<3, id: \.self) { i in
            FallingLeaf(
                index: i,
                color: .brown,
                startPoint: CGPoint(x: 100, y: 50),
                size: 8
            )
        }
    }
    .frame(width: 220, height: 160)
}
