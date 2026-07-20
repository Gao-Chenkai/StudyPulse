//
//  BodyRadarChart.swift
//  StudyPulse
//
//  6 轴雷达 / 多边形图(HRV / 心率 / 恢复睡眠 / 锻炼 / 呼吸 / 心理稳定性)。
//  纯 SwiftUI `Path` 绘制,雷达本身不依赖 Charts 框架。
//
//  6-axis radar / polygon chart. Pure SwiftUI `Path`s — no Charts
//  framework dependency for the radar itself.
//
//  Phase 3 拆分 (2026-07-14):原 `HRVStatusCard.swift` 抽出,可独立预览。
//

import SwiftUI

/// 6 轴雷达 / 多边形图。
/// 6-axis radar / polygon chart.
struct BodyRadarChart: View {
    let values: [Double]

    private let dimensionCount = 6
    private let axisLabels: [String]
    private let axisColors: [Color]
    private let fillColors: [Color]
    private let strokeColors: [Color]
    private let pointColors: [Color]

    init(values: BodyRadarValues, axisLabels: [String]? = nil) {
        self.values = values.all
        self.axisLabels = axisLabels ?? [
            "HRV", "Heart Rate".localized(), "Recovery Sleep".localized(),
            "Workout".localized(), "Respiratory".localized(), "Stability".localized()
        ]
        let recoveryColor = values.recoveryLevel.color
        self.axisColors = Array(repeating: recoveryColor, count: 6)
        self.fillColors = [recoveryColor.opacity(0.45), recoveryColor.opacity(0.16)]
        self.strokeColors = [recoveryColor, recoveryColor.opacity(0.72)]
        self.pointColors = Array(repeating: recoveryColor, count: 6)
    }

    init(normalizedValues: [Double], axisLabels: [String]) {
        let colors: [Color] = [.purple, .pink, .indigo, .green, .cyan, .orange]
        self.values = Array(normalizedValues.prefix(6)).map { max(0, min(1, $0)) }
            + Array(repeating: 0.5, count: max(0, 6 - normalizedValues.count))
        self.axisLabels = Array(axisLabels.prefix(6))
            + Array(repeating: "", count: max(0, 6 - axisLabels.count))
        self.axisColors = colors
        self.fillColors = [Color.blue.opacity(0.45), Color.purple.opacity(0.18)]
        self.strokeColors = [.blue, .purple]
        self.pointColors = colors
    }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            // Reserve 22% of the radius for outside labels.
            let maxRadius = size / 2 * 0.78

            ZStack {
                // 同心网格多边形(25 / 50 / 75 / 100%)
                // Concentric grid polygons (25 / 50 / 75 / 100%).
                ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { level in
                    polygonPath(center: center,
                                radius: maxRadius * CGFloat(level),
                                count: dimensionCount)
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                }

                // 从中心到每个标签的轴线
                // Axis lines from center to each label.
                ForEach(0..<dimensionCount, id: \.self) { i in
                    Path { path in
                        path.move(to: center)
                        path.addLine(to: pointAt(
                            angle: angleFor(index: i),
                            radius: maxRadius,
                            from: center))
                    }
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                }

                // 填充数据多边形(渐变)
                // Filled data polygon (gradient).
                dataPolygonPath(center: center, radius: maxRadius)
                    .fill(LinearGradient(
                        colors: fillColors,
                        startPoint: .top, endPoint: .bottom))

                // 数据多边形描边
                // Data polygon outline.
                dataPolygonPath(center: center, radius: maxRadius)
                    .stroke(
                        LinearGradient(colors: strokeColors,
                                       startPoint: .top, endPoint: .bottom),
                        lineWidth: 2
                    )

                // 每轴的数据点 + 标签
                // Per-axis data point + label.
                ForEach(0..<dimensionCount, id: \.self) { i in
                    let p = pointAt(
                        angle: angleFor(index: i),
                        radius: maxRadius * CGFloat(values[i]),
                        from: center
                    )
                    Circle()
                        .fill(pointColors[i])
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .position(p)

                    let labelPoint = pointAt(
                        angle: angleFor(index: i),
                        radius: maxRadius * 1.18,
                        from: center
                    )
                    Text(axisLabels[i])
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(axisColors[i])
                        .position(labelPoint)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    // MARK: - 几何辅助 / Geometry helpers

    /// Start at the top (12 o'clock) and go clockwise. With 5 axes this
    /// puts HRV at the top, Heart Rate on the right, Recovery Sleep at
    /// the bottom-right, Workout at the bottom-left, and Respiratory on
    /// the left.
    /// 从 12 点钟方向起、顺时针排列。5 轴时:HRV 在正上,心率在右,
    /// 恢复睡眠在右下,运动在左下,呼吸在左。
    private func angleFor(index: Int) -> Angle {
        .degrees(Double(index) * 360.0 / Double(dimensionCount) - 90)
    }

    private func pointAt(angle: Angle, radius: CGFloat, from center: CGPoint) -> CGPoint {
        let rad = CGFloat(angle.radians)
        return CGPoint(
            x: center.x + cos(rad) * radius,
            y: center.y + sin(rad) * radius
        )
    }

    private func polygonPath(center: CGPoint, radius: CGFloat, count: Int) -> Path {
        Path { path in
            for i in 0..<count {
                let p = pointAt(angle: angleFor(index: i), radius: radius, from: center)
                if i == 0 { path.move(to: p) }
                else { path.addLine(to: p) }
            }
            path.closeSubpath()
        }
    }

    /// Connect the six radar data points, each at its own radius
    /// (maxRadius × normalized value) along its axis direction.
    /// 连接 6 个雷达数据点,每个点位于自己轴方向上 maxRadius × 归一化值处。
    private func dataPolygonPath(center: CGPoint, radius: CGFloat) -> Path {
        Path { path in
            for i in 0..<dimensionCount {
                let p = pointAt(
                    angle: angleFor(index: i),
                    radius: radius * CGFloat(values[i]),
                    from: center
                )
                if i == 0 { path.move(to: p) }
                else { path.addLine(to: p) }
            }
            path.closeSubpath()
        }
    }
}

// MARK: - Preview / 独立预览入口

#Preview("BodyRadarChart") {
    let values = BodyRadarValues(
        hrv: 0.7, heartRate: 0.6, sleep: 0.85, exercise: 0.4, respiratory: 0.55, psychologicalStability: 0.75,
        hrvValueText: "65 ms",
        heartRateValueText: "62 bpm",
        sleepValueText: "6.2h",
        exerciseValueText: "15 m",
        respiratoryValueText: "14",
        psychologicalStabilityValueText: "75%",
        hrvColor: .blue,
        heartRateColor: .blue,
        sleepColor: .green,
        exerciseColor: .blue,
        respiratoryColor: .blue,
        psychologicalStabilityColor: .blue
    )
    return BodyRadarChart(values: values)
        .frame(width: 320, height: 320)
        .padding()
}
