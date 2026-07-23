import SwiftUI

struct MistakePatternGalleryView: View {
    let summaries: [MistakePatternSummary]

    private let colors: [Color] = [.cyan, .blue, .purple, .pink, .orange, .green]

    private func color(for summary: MistakePatternSummary) -> Color {
        switch summary.riskScore {
        case 0.75...: return .red
        case 0.5...: return .orange
        default: return colors[abs(summary.pattern.rawValue.hashValue) % colors.count]
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("mistake.pattern.gallery.title".localized())
                    .font(.title2.bold())
                Text("mistake.pattern.gallery.description".localized())
                    .font(.subheadline).foregroundStyle(.secondary)

                GeometryReader { proxy in
                    let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
                    ZStack {
                        Canvas { context, size in
                            for (index, _) in summaries.enumerated() {
                                guard index > 0 else { continue }
                                let start = point(for: index - 1, center: center, size: size)
                                let end = point(for: index, center: center, size: size)
                                var path = Path()
                                path.move(to: start)
                                path.addLine(to: end)
                                context.stroke(path, with: .color(.secondary.opacity(0.22)), lineWidth: 1)
                            }
                        }
                        ForEach(Array(summaries.enumerated()), id: \.element.id) { index, summary in
                            NavigationLink(destination: MistakePatternDetailView(summary: summary)) {
                                Circle()
                                    .fill(color(for: summary).gradient)
                                    .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 1))
                                    .frame(width: nodeSize(for: summary), height: nodeSize(for: summary))
                                    .shadow(color: color(for: summary).opacity(0.45), radius: 12)
                                    .overlay {
                                        Text("\(summary.count)").font(.caption.bold()).foregroundStyle(.white)
                                    }
                            }
                            .buttonStyle(.plain)
                            .position(point(for: index, center: center, size: proxy.size))
                            .accessibilityLabel(String(format: "mistake.pattern.gallery.accessibility".localized(), summary.pattern.displayName, summary.count))
                        }
                    }
                }
                .frame(height: 300)

                VStack(spacing: 10) {
                    ForEach(summaries) { summary in
                        NavigationLink(destination: MistakePatternDetailView(summary: summary)) {
                            HStack {
                                Circle().fill(color(for: summary)).frame(width: 12, height: 12)
                                Text(summary.pattern.displayName).foregroundStyle(.primary)
                                Spacer()
                                Text(String(format: "mistake.pattern.gallery.risk".localized(), Int(summary.riskScore * 100)))
                                    .font(.caption).foregroundStyle(color(for: summary))
                            }
                            .padding(12).cardSkin()
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, DesignToken.Spacing.mainHorizontal)
            .padding(.vertical)
        }
        .navigationTitle("mistake.pattern.gallery.title".localized())
        .navigationBarTitleDisplayMode(.inline)
    }

    private func nodeSize(for summary: MistakePatternSummary) -> CGFloat {
        min(76, max(42, 36 + CGFloat(summary.count) * 5))
    }

    private func point(for index: Int, center: CGPoint, size: CGSize) -> CGPoint {
        guard summaries.count > 1 else { return center }
        let radius = min(size.width, size.height) * 0.32
        let angle = Double(index) / Double(summaries.count) * 2 * .pi - .pi / 2
        return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
    }
}
