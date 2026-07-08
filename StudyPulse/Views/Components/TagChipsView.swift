//
//  TagChipsView.swift
//  StudyPulse
//
//  标签只读展示:横向 chip 列表;可选可点击(onTap)。
//  用于 MistakeSetDetailView / MistakeCardView / SuggestedMistakeCard 等。
//
//  Read-only tag chip strip (optionally tappable). Used by the detail
//  view, list cards, and the suggested review card.
//

import SwiftUI

struct TagChipsView: View {
    let tags: [String]
    /// 点击回调(可选)
    var onTap: ((String) -> Void)? = nil
    /// 是否显示为紧凑小芯片(列表卡片用)
    var compact: Bool = false
    /// 最多显示几个 chip(超出显示 +N)。0 = 无限
    var maxVisible: Int = 0
    /// 0 = auto:compact=3 / 普通=10
    var effectiveMax: Int {
        if maxVisible > 0 { return maxVisible }
        return compact ? 3 : 10
    }

    private var visible: [String] {
        Array(tags.prefix(effectiveMax))
    }

    private var overflow: Int {
        max(0, tags.count - effectiveMax)
    }

    var body: some View {
        if tags.isEmpty {
            EmptyView()
        } else {
            FlowLayout(spacing: compact ? 4 : 6) {
                ForEach(Array(visible.enumerated()), id: \.offset) { _, tag in
                    chip(for: tag)
                }
                if overflow > 0 {
                    Text("+\(overflow)")
                        .font(compact ? .caption2 : .caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, compact ? 6 : 8)
                        .padding(.vertical, compact ? 2 : 3)
                        .background(
                            Capsule().fill(Color(.tertiarySystemFill))
                        )
                }
            }
        }
    }

    @ViewBuilder
    private func chip(for tag: String) -> some View {
        let label = Text("#\(tag)")
            .font(compact ? .caption2 : .caption)
            .foregroundStyle(Color.purple)
            .padding(.horizontal, compact ? 6 : 10)
            .padding(.vertical, compact ? 2 : 4)
            .background(
                Capsule().fill(Color.purple.opacity(0.12))
            )

        if let onTap {
            Button {
                onTap(tag)
            } label: {
                label
            }
            .buttonStyle(.plain)
        } else {
            label
        }
    }
}

/// 简单的 wrap layout(横向换行)。iOS 16+ 可用 iOS 自带 Layout,但为兼容性手写一个。
/// A minimal flow layout: lays out children in a row, wrapping to the next row
/// when the row width would exceed the available width.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                totalWidth = max(totalWidth, rowWidth - spacing)
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        totalWidth = max(totalWidth, rowWidth - spacing)
        return CGSize(width: max(0, totalWidth), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + maxWidth, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: size.width, height: size.height))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        TagChipsView(tags: ["函数", "三角", "解析几何"])
        TagChipsView(tags: ["函数", "三角", "解析几何"], compact: true)
        TagChipsView(tags: ["a", "b", "c", "d", "e", "f"], compact: true, maxVisible: 3)
        TagChipsView(tags: ["点击我", "测试"]) { tag in
            print("tapped \(tag)")
        }
    }
    .padding()
}
