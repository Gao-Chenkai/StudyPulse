//
//  PlantCanvasView.swift
//  StudyPulse
//
//  主页植物 Canvas 渲染：7 层（花盆/泥土/茎/叶/花/光点/凋零覆盖）。
//  7 procedural layers drawn in a single SwiftUI Canvas for low overhead.
//
//  Layer order (bottom → top):
//  1. Pot (梯形)         2. Soil (泥土)
//  3. Stem (贝塞尔曲线)   4. Leaves (2-6 片, Ellipse + rotation)
//  5. Bud / Flower        6. Sparkles (flourish+)
//  7. Withered overlay + falling leaves
//

import SwiftUI

struct PlantCanvasView: View {
    let stage: PlantStage
    let petalColor: Color
    let accent: Color       // 来自 effectiveAccentColor（茎/叶色调）

    @State private var float: CGFloat = 0
    @Environment(\.colorScheme) private var colorScheme

    private let canvasSize = CGSize(width: 160, height: 200)

    var body: some View {
        Canvas { ctx, size in
            let potHeight: CGFloat = size.height * 0.30
            let potRect = CGRect(
                x: size.width * 0.18,
                y: size.height - potHeight,
                width: size.width * 0.64,
                height: potHeight
            )
            let potTopY = potRect.minY + 6   // rim
            let potCenterX = potRect.midX

            // ---------- Layer 1: 花盆 ----------
            drawPot(ctx: ctx, rect: potRect, potTopY: potTopY)

            // ---------- Layer 2: 泥土 ----------
            drawSoil(ctx: ctx, rect: CGRect(x: potRect.minX + 2, y: potTopY, width: potRect.width - 4, height: 6))

            // ---------- Layer 3: 茎（seed / withered 高度为 0 不绘）----------
            let stemTopY = drawStem(
                ctx: ctx,
                potTopY: potTopY,
                potCenterX: potCenterX,
                potTopWidth: potRect.width
            )

            // ---------- Layer 4: 叶片 ----------
            drawLeaves(ctx: ctx, potTopY: potTopY, potCenterX: potCenterX)

            // ---------- Layer 5: 花苞 / 花 ----------
            drawFlower(ctx: ctx, stemTopY: stemTopY, potCenterX: potCenterX)

            // ---------- Layer 6: 飘动光点（TimelineView 驱动，独立于 Canvas） ----------
            // 光点通过 overlay 单独添加（不在 Canvas 内）
            // ---------- Layer 7: 凋零覆盖 ----------
            if stage.isWithered {
                ctx.drawLayer { layer in
                    layer.opacity = 0.5
                    layer.fill(
                        Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 18),
                        with: .color(.gray)
                    )
                }
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .overlay(alignment: .top) {
            sparklesOverlay
        }
        .overlay {
            if stage == .withered {
                fallingLeavesOverlay
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                float = 1
            }
        }
        .plantStageTransition(stage)
        .accessibilityLabel(stage.localizedTitle)
    }

    // MARK: - Pot (Layer 1)

    private func drawPot(ctx: GraphicsContext, rect: CGRect, potTopY: CGFloat) {
        // 花盆主体（深陶土色 + 渐变高光）— Path 内联避免 Shape 协议 @MainActor 警告
        let potPath = Self.potPath(in: rect)
        let potGradient = Gradient(colors: [
            Color(red: 0.78, green: 0.48, blue: 0.36),
            Color(red: 0.62, green: 0.34, blue: 0.24),
        ])
        ctx.fill(
            potPath,
            with: .linearGradient(potGradient, startPoint: CGPoint(x: rect.minX, y: rect.minY), endPoint: CGPoint(x: rect.maxX, y: rect.maxY))
        )

        // 唇部（顶部横向条）
        let rimRect = CGRect(x: rect.minX - 3, y: rect.minY, width: rect.width + 6, height: 6)
        let rimPath = Path(roundedRect: rimRect, cornerRadius: 2)
        ctx.fill(rimPath, with: .color(Color(red: 0.55, green: 0.30, blue: 0.22)))

        // 高光
        let highlight = Path(ellipseIn: CGRect(x: rect.minX + 4, y: rect.minY + 10, width: 6, height: rect.height * 0.6))
        ctx.fill(highlight, with: .color(.white.opacity(0.18)))
    }

    // MARK: - Soil (Layer 2)

    private func drawSoil(ctx: GraphicsContext, rect: CGRect) {
        let path = Path(roundedRect: rect, cornerRadius: 2)
        ctx.fill(path, with: .color(Color(red: 0.36, green: 0.24, blue: 0.16)))
        // 一两颗小石子
        let dot1 = Path(ellipseIn: CGRect(x: rect.minX + rect.width * 0.3, y: rect.midY - 1, width: 3, height: 2))
        ctx.fill(dot1, with: .color(.black.opacity(0.25)))
        let dot2 = Path(ellipseIn: CGRect(x: rect.minX + rect.width * 0.65, y: rect.midY + 1, width: 2, height: 1.5))
        ctx.fill(dot2, with: .color(.black.opacity(0.25)))
    }

    // MARK: - Stem (Layer 3)

    /// 返回茎顶 Y，供 Layer 5 决定花的高度。
    @discardableResult
    private func drawStem(ctx: GraphicsContext, potTopY: CGFloat, potCenterX: CGFloat, potTopWidth: CGFloat) -> CGFloat {
        let stemHeight: CGFloat
        let stemWidth: CGFloat
        let baseY = potTopY
        let totalH: CGFloat = 130 // 茎的最大可达高度（不含花盆）
        let ratio = stage.stemHeightRatio
        stemHeight = totalH * ratio
        stemWidth = max(2.5, 5.5 * (0.4 + ratio * 0.6))
        if stemHeight < 4 { return baseY }

        let endY = baseY - stemHeight
        // 微弯贝塞尔（中间点稍向一侧偏）
        let midOffsetX: CGFloat = sin(float * .pi * 2) * 1.8
        let control1 = CGPoint(x: potCenterX + midOffsetX, y: baseY - stemHeight * 0.4)
        let control2 = CGPoint(x: potCenterX - midOffsetX, y: baseY - stemHeight * 0.7)
        let endPoint = CGPoint(x: potCenterX + sin(float * .pi * 2 + .pi / 2) * 1.2, y: endY)

        var stemPath = Path()
        stemPath.move(to: CGPoint(x: potCenterX - stemWidth / 2, y: baseY))
        stemPath.addCurve(
            to: CGPoint(x: endPoint.x - stemWidth / 2, y: endPoint.y),
            control1: CGPoint(x: control1.x - stemWidth / 2, y: control1.y),
            control2: CGPoint(x: control2.x - stemWidth / 2, y: control2.y)
        )
        stemPath.addLine(to: CGPoint(x: endPoint.x + stemWidth / 2, y: endPoint.y))
        stemPath.addCurve(
            to: CGPoint(x: potCenterX + stemWidth / 2, y: baseY),
            control1: CGPoint(x: control2.x + stemWidth / 2, y: control2.y),
            control2: CGPoint(x: control1.x + stemWidth / 2, y: control1.y)
        )
        stemPath.closeSubpath()

        // 渐变（茎根部更深，顶部更亮）
        let stemGradient = Gradient(colors: [
            accent.opacity(0.85),
            accent.opacity(0.55),
        ])
        ctx.fill(
            stemPath,
            with: .linearGradient(stemGradient, startPoint: CGPoint(x: potCenterX, y: baseY), endPoint: CGPoint(x: endPoint.x, y: endPoint.y))
        )
        return endPoint.y
    }

    // MARK: - Leaves (Layer 4)

    private func drawLeaves(ctx: GraphicsContext, potTopY: CGFloat, potCenterX: CGFloat) {
        let count = stage.leafCount
        guard count > 0 else { return }
        let totalH: CGFloat = 130 * stage.stemHeightRatio
        let stemTopY = potTopY - totalH
        let stepY = (potTopY - stemTopY) / CGFloat(max(count, 1))
        let leafSize = CGSize(width: 14, height: 28)

        for i in 0..<count {
            let t = CGFloat(i + 1) / CGFloat(count + 1)
            let yAtLeaf = potTopY - stepY * t * CGFloat(count)
            let side: CGFloat = (i % 2 == 0) ? -1 : 1
            let xOffset: CGFloat = side * (4 + 2 * t * 6)
            let _ = Double(side) * (30 + Double(t) * 25) + sin(Double(float * .pi * 2) + Double(i)) * 3 // 风动角度(目前为对称叶片,留作非对称版本扩展)
            let leafRect = CGRect(
                x: potCenterX + xOffset - leafSize.width / 2,
                y: yAtLeaf - leafSize.height / 2,
                width: leafSize.width,
                height: leafSize.height
            )
            let path = Self.leafPath(in: leafRect)
            // 叶片深绿 + 浅绿渐变
            let gradient = Gradient(colors: [
                accent.opacity(0.95),
                accent.opacity(0.7),
            ])
            ctx.fill(
                path,
                with: .linearGradient(gradient, startPoint: CGPoint(x: leafRect.minX, y: leafRect.minY), endPoint: CGPoint(x: leafRect.maxX, y: leafRect.maxY))
            )
        }
    }

    // MARK: - Flower (Layer 5)

    private func drawFlower(ctx: GraphicsContext, stemTopY: CGFloat, potCenterX: CGFloat) {
        let center = CGPoint(x: potCenterX, y: stemTopY - 4)
        if stage.hasBloom {
            // 完整花朵：5 片花瓣 + 中心
            let petalLength: CGFloat = 18
            let petalWidth: CGFloat = 9
            for i in 0..<5 {
                let angle = Double(i) * (2 * .pi / 5) - .pi / 2
                let cx = center.x + cos(angle) * 4
                let cy = center.y + sin(angle) * 4
                var ctx2 = ctx
                ctx2.translateBy(x: cx, y: cy)
                ctx2.rotate(by: .radians(angle + .pi / 2))
                let petalPath = Self.petalPath(in: CGRect(x: -petalWidth / 2, y: -petalLength / 2, width: petalWidth, height: petalLength))
                let petalGradient = Gradient(colors: [
                    petalColor,
                    petalColor.opacity(0.75),
                ])
                ctx2.fill(petalPath, with: .linearGradient(petalGradient, startPoint: CGPoint(x: 0, y: -petalLength / 2), endPoint: CGPoint(x: 0, y: petalLength / 2)))
            }
            // 花心
            let core = Path(ellipseIn: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8))
            ctx.fill(core, with: .color(Color(red: 0.98, green: 0.85, blue: 0.30)))
        } else if stage.hasBud {
            // 花苞：单一椭圆
            let bud = CGRect(x: center.x - 6, y: center.y - 8, width: 12, height: 16)
            let budPath = Path(ellipseIn: bud)
            let budGradient = Gradient(colors: [petalColor.opacity(0.85), petalColor])
            ctx.fill(budPath, with: .linearGradient(budGradient, startPoint: CGPoint(x: bud.midX, y: bud.minY), endPoint: CGPoint(x: bud.midX, y: bud.maxY)))
        }
    }

    // MARK: - Sparkles (Layer 6, overlay)

    @ViewBuilder
    private var sparklesOverlay: some View {
        if stage.hasSparkles {
            let origin = CGPoint(x: canvasSize.width * 0.5, y: canvasSize.height * 0.18)
            ZStack {
                ForEach(0..<5, id: \.self) { i in
                    FloatingSparkle(
                        index: i,
                        color: petalColor,
                        size: 3 + CGFloat(i % 3),
                        origin: origin,
                        radius: 30 + CGFloat(i) * 3
                    )
                }
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Falling Leaves (Layer 7, overlay)

    @ViewBuilder
    private var fallingLeavesOverlay: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                FallingLeaf(
                    index: i,
                    color: accent.opacity(0.7),
                    startPoint: CGPoint(x: canvasSize.width * 0.5, y: canvasSize.height * 0.55),
                    size: 6
                )
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .allowsHitTesting(false)
    }
}

// MARK: - Inline Path Helpers
// 全部以 static func 形式内联，避免 Shape 协议 @MainActor 警告
// All inlined as static functions to avoid Shape @MainActor warnings.

extension PlantCanvasView {
    /// 梯形花盆 path（顶部宽，底部窄 + 顶部横条）
    static func potPath(in rect: CGRect) -> Path {
        var p = Path()
        let topWidth = rect.width
        let bottomWidth = rect.width * 0.82
        let centerX = rect.midX
        let top = rect.minY
        let bottom = rect.maxY
        let rimHeight: CGFloat = 6
        let bodyTop = top + rimHeight
        p.move(to: CGPoint(x: centerX - topWidth / 2, y: bodyTop))
        p.addLine(to: CGPoint(x: centerX + topWidth / 2, y: bodyTop))
        p.addLine(to: CGPoint(x: centerX + bottomWidth / 2, y: bottom))
        p.addLine(to: CGPoint(x: centerX - bottomWidth / 2, y: bottom))
        p.closeSubpath()
        // 唇
        p.move(to: CGPoint(x: centerX - topWidth / 2 - 3, y: top))
        p.addLine(to: CGPoint(x: centerX + topWidth / 2 + 3, y: top))
        p.addLine(to: CGPoint(x: centerX + topWidth / 2, y: bodyTop))
        p.addLine(to: CGPoint(x: centerX - topWidth / 2, y: bodyTop))
        p.closeSubpath()
        return p
    }

    /// 单片叶子 path
    static func leafPath(in rect: CGRect, drawVein: Bool = true) -> Path {
        var p = Path()
        let h = rect.height
        let w = rect.width
        let mid = rect.midX
        let top = rect.minY
        let bottom = rect.maxY
        let quarter = h * 0.25
        p.move(to: CGPoint(x: mid, y: top))
        p.addQuadCurve(to: CGPoint(x: mid + w * 0.5, y: mid - h * 0.05),
                       control: CGPoint(x: mid + w * 0.45, y: top + quarter))
        p.addQuadCurve(to: CGPoint(x: mid, y: bottom),
                       control: CGPoint(x: mid + w * 0.5, y: bottom - quarter))
        p.addQuadCurve(to: CGPoint(x: mid - w * 0.5, y: mid - h * 0.05),
                       control: CGPoint(x: mid - w * 0.5, y: bottom - quarter))
        p.addQuadCurve(to: CGPoint(x: mid, y: top),
                       control: CGPoint(x: mid - w * 0.45, y: top + quarter))
        p.closeSubpath()
        if drawVein {
            p.move(to: CGPoint(x: mid, y: top + 2))
            p.addLine(to: CGPoint(x: mid, y: bottom - 2))
        }
        return p
    }

    /// 单片花瓣 path（泪滴形）
    static func petalPath(in rect: CGRect, roundness: CGFloat = 0.55) -> Path {
        var p = Path()
        let centerX = rect.midX
        let top = rect.minY
        let bottom = rect.maxY
        let sideWidth = rect.width * 0.5 * roundness
        let shoulderY = rect.midY + rect.height * 0.1
        p.move(to: CGPoint(x: centerX, y: bottom))
        p.addQuadCurve(to: CGPoint(x: centerX - sideWidth, y: shoulderY),
                       control: CGPoint(x: centerX - sideWidth * 0.7, y: bottom - rect.height * 0.2))
        p.addQuadCurve(to: CGPoint(x: centerX, y: top),
                       control: CGPoint(x: centerX - sideWidth, y: top + rect.height * 0.05))
        p.addQuadCurve(to: CGPoint(x: centerX + sideWidth, y: shoulderY),
                       control: CGPoint(x: centerX + sideWidth, y: top + rect.height * 0.05))
        p.addQuadCurve(to: CGPoint(x: centerX, y: bottom),
                       control: CGPoint(x: centerX + sideWidth * 0.7, y: bottom - rect.height * 0.2))
        p.closeSubpath()
        return p
    }
}

// MARK: - Previews

#Preview("Seed") {
    PlantCanvasView(stage: .seed, petalColor: .pink, accent: .green)
        .padding()
}

#Preview("Sprout") {
    PlantCanvasView(stage: .sprout, petalColor: .pink, accent: .green)
        .padding()
}

#Preview("Bloom") {
    PlantCanvasView(stage: .bloom, petalColor: .pink, accent: .green)
        .padding()
}

#Preview("Withered") {
    PlantCanvasView(stage: .withered, petalColor: .pink, accent: .green)
        .padding()
}
