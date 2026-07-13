//
//  TagGraphEdges.swift
//  StudyPulse
//
//  标签图谱的"边"渲染辅助:
//  - 边在两点之间画成直线(可换微弯曲线)
//  - 描边宽度和透明度按"共同错题数"对数缩放
//
//  Edge Path rendering helpers for the tag graph.
//  - Edges drawn as straight or slightly curved lines between two points.
//  - Stroke width and opacity are scaled by edge weight (shared-mistake count).
//

import SwiftUI

/// 渲染一组边(force-directed graph 的连线)。
/// A simple Path-based renderer for graph edges.
struct TagGraphEdges: View {
    /// 节点名(小写)→ 位置
    /// Node name (lowercased) → position.
    let positions: [String: CGPoint]
    /// 待渲染的边集合
    /// Edge list to render.
    let edges: [TagGraphLayout.Edge]
    /// 连线颜色
    /// Line color.
    var lineColor: Color = .purple

    var body: some View {
        Canvas { context, _ in
            for edge in edges {
                guard let p1 = positions[edge.a.lowercased()],
                      let p2 = positions[edge.b.lowercased()] else {
                    // Fallback: lookup by original case
                    if let p1f = positions[edge.a], let p2f = positions[edge.b] {
                        drawEdge(context: context, p1: p1f, p2: p2f, weight: edge.weight)
                    }
                    continue
                }
                drawEdge(context: context, p1: p1, p2: p2, weight: edge.weight)
            }
        }
    }

    private func drawEdge(
        context: GraphicsContext,
        p1: CGPoint,
        p2: CGPoint,
        weight: Int
    ) {
        var path = Path()
        path.move(to: p1)
        path.addLine(to: p2)

        // Width: log-scaled from 1.0 to 4.0
        let width = log2(Double(weight) + 1.0).clamped(to: 1.0...4.0)
        // Opacity: 0.2 .. 0.6
        let opacity = (0.15 + 0.1 * log2(Double(weight) + 1.0)).clamped(to: 0.2...0.65)

        context.stroke(
            path,
            with: .color(lineColor.opacity(opacity)),
            style: StrokeStyle(lineWidth: width, lineCap: .round)
        )
    }
}

/// In-place clamping for `Comparable`.
extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
