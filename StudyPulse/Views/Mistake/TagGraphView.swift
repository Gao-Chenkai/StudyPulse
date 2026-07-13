//
//  TagGraphView.swift
//  StudyPulse
//
//  Obsidian 风格标签图谱:
//  - 每个标签 = 一个节点(胶囊形 label)
//  - 共享 ≥ 1 道错题的两个标签之间画边,权重 = 共享错题数
//  - 布局:力导向(Fruchterman-Reingold)via `TagGraphLayout`
//  - 点击节点 → 触发 `onSelectTag` 让 caller 过滤错题
//  - Recenter 按钮重新计算布局
//
//  Obsidian-style tag graph view.
//  - Each tag is a node (capsule label).
//  - Edges connect tags that share ≥ 1 mistake (weight = # of shared mistakes).
//  - Layout: force-directed (Fruchterman-Reingold) via TagGraphLayout.
//  - Tap a node to filter mistakes to that tag (caller handles via onSelectTag).
//  - Recenter re-runs the layout from scratch.
//

import SwiftUI

/// 标签图谱:展示错题标签的节点 + 共享边 + 力导向布局。
/// Tag graph: shows mistake tags as nodes plus their shared edges
/// laid out with a force-directed algorithm.
struct TagGraphView: View {
    /// 错题(从中提取标签与共享关系)
    /// Mistakes (from which tags and shared edges are derived).
    let mistakes: [MistakeNote]
    /// 点击节点时的回调(让 caller 过滤错题)
    /// Callback when a node is tapped (lets the caller filter mistakes).
    var onSelectTag: (String) -> Void
    /// 关闭 sheet 的回调(为空时用系统 dismiss)
    /// Sheet-dismiss callback (falls back to system dismiss when nil).
    var onClose: () -> Void = {}

    /// 当前 canvas 的尺寸
    /// Current canvas size.
    @State private var canvasSize: CGSize = .zero
    /// 节点位置字典(tag → CGPoint)
    /// Node position dictionary (tag → CGPoint).
    @State private var positions: [String: CGPoint] = [:]
    /// 重新计算布局的"扳机"(变化时跑一次 layout)
    /// Recomputation trigger (changing it re-runs the layout).
    @State private var recomputeKey: UUID = UUID()
    /// 当前被点击的节点 tag
    /// Currently tapped node's tag.
    @State private var tappedTag: String?

    // 画布 pan / zoom 状态
    // Canvas pan / zoom state
    /// 当前 canvas 累计的平移
    /// Accumulated pan offset of the canvas.
    @State private var canvasOffset: CGSize = .zero
    /// 当前 canvas 缩放
    /// Current canvas scale.
    @State private var canvasScale: CGFloat = 1.0
    /// 当前手势的临时平移(松手后归零)
    /// Temporary translation from the current gesture (resets on release).
    @GestureState private var dragAccumulator: CGSize = .zero
    /// 当前手势的临时缩放(松手后归零)
    /// Temporary scale from the current gesture (resets on release).
    @GestureState private var magnifyBy: CGFloat = 1.0

    @Environment(\.dismiss) private var dismiss

    /// 节点胶囊内边距(让 label 不贴边)
    /// Inner padding for the node capsule.
    private let nodePadding: CGFloat = 12
    /// 参与布局的最大节点数;超出时显示提示而不是渲染一团乱麻
    /// Max nodes allowed in the layout; over the limit we show a "too many" message.
    private let maxNodesForLayout: Int = 60

    /// Compute the tag nodes (with usage count) and edges (shared-mistake weight).
    private var graph: (nodes: [(tag: String, count: Int)], edges: [TagGraphLayout.Edge]) {
        let counts = MistakeFilter.tagCounts(mistakes)
        let nodes = counts.prefix(maxNodesForLayout).map { (tag: $0.tag, count: $0.count) }

        // Edge: two tags are connected if they share ≥ 1 mistake.
        // Use a per-mistake tag list; iterate over each mistake's tag set and
        // count co-occurrences (lowercased).
        var edgeWeights: [String: Int] = [:]
        for m in mistakes {
            let raw = m.tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            // Pairwise combinations
            for i in 0..<raw.count {
                for j in (i + 1)..<raw.count {
                    let a = raw[i].lowercased()
                    let b = raw[j].lowercased()
                    let key = [a, b].sorted().joined(separator: "|")
                    edgeWeights[key, default: 0] += 1
                }
            }
        }

        let nodeSet = Set(nodes.map { $0.tag.lowercased() })
        var edges: [TagGraphLayout.Edge] = []
        for (key, weight) in edgeWeights {
            let parts = key.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2,
                  nodeSet.contains(String(parts[0])),
                  nodeSet.contains(String(parts[1])) else { continue }
            // Look up original case for the edge endpoints.
            let aOrig = nodes.first(where: { $0.tag.lowercased() == String(parts[0]) })?.tag ?? String(parts[0])
            let bOrig = nodes.first(where: { $0.tag.lowercased() == String(parts[1]) })?.tag ?? String(parts[1])
            edges.append(TagGraphLayout.Edge(a: aOrig, b: bOrig, weight: weight))
        }
        return (Array(nodes), edges)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if mistakes.isEmpty {
                    emptyState
                } else if graph.nodes.isEmpty {
                    emptyTags
                } else if graph.nodes.count > maxNodesForLayout {
                    tooManyTags
                } else {
                    graphCanvas
                }
            }
            .navigationTitle("Tag Graph".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        // 父层传了 onClose 就用(比如要附带副作用),否则用系统 dismiss
                        // 统一兜底:dismiss() 关闭 fullScreenCover / sheet
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close".localized())
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // 重新布局 + 重置视图变换
                        recomputeKey = UUID()
                        canvasOffset = .zero
                        canvasScale = 1.0
                    } label: {
                        Label("Recenter".localized(), systemImage: "arrow.counterclockwise")
                    }
                    .accessibilityLabel("Recenter".localized())
                    .disabled(graph.nodes.isEmpty || graph.nodes.count > maxNodesForLayout)
                }
            }
        }
    }

    // MARK: - Empty / Too many states / 空态 / 节点过多提示

    private var emptyState: some View {
        ContentUnavailableView(
            "No Mistakes".localized(),
            systemImage: "exclamationmark.triangle",
            description: Text("Add some mistakes first.".localized())
        )
    }

    private var emptyTags: some View {
        ContentUnavailableView(
            "No tags yet".localized(),
            systemImage: "tag",
            description: Text("No tags yet — add tags to your mistakes to see the graph".localized())
        )
    }

    private var tooManyTags: some View {
        ContentUnavailableView(
            "Too many tags".localized(),
            systemImage: "tag.fill",
            description: Text("You have more than \(maxNodesForLayout) tags. Try removing some to view the graph.".localized())
        )
    }

    // MARK: - Canvas / 画布

    private var graphCanvas: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let totalScale = canvasScale * magnifyBy
            ZStack {
                Color.clear.contentShape(Rectangle())

                // Edges
                TagGraphEdges(positions: positions, edges: graph.edges)
                    .id(recomputeKey)
                    .allowsHitTesting(false)

                // Nodes
                ForEach(Array(graph.nodes.enumerated()), id: \.offset) { _, node in
                    if let pos = positions[node.tag.lowercased()]
                        ?? positions[node.tag] {
                        nodeView(for: node)
                            .position(pos)
                            .onTapGesture {
                                handleTap(node.tag)
                            }
                    }
                }
            }
            .frame(width: size.width, height: size.height)
            .scaleEffect(totalScale, anchor: .center)
            .offset(
                x: canvasOffset.width + dragAccumulator.width,
                y: canvasOffset.height + dragAccumulator.height
            )
            // 双指捏合缩放
            .gesture(
                MagnificationGesture()
                    .updating($magnifyBy) { value, state, _ in
                        state = value
                    }
                    .onEnded { value in
                        canvasScale = max(0.4, min(3.5, canvasScale * value))
                    }
            )
            // 单指拖动平移(不影响子节点的 tap)
            .simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .updating($dragAccumulator) { value, state, _ in
                        state = value.translation
                    }
                    .onEnded { value in
                        canvasOffset = CGSize(
                            width: canvasOffset.width + value.translation.width,
                            height: canvasOffset.height + value.translation.height
                        )
                    }
            )
            .onAppear {
                canvasSize = size
                recomputeLayout(in: size)
            }
            .onChange(of: recomputeKey) { _, _ in
                recomputeLayout(in: size)
            }
            .onChange(of: proxy.size) { _, newSize in
                canvasSize = newSize
                recomputeLayout(in: newSize)
            }
        }
    }

    @ViewBuilder
    private func nodeView(for node: (tag: String, count: Int)) -> some View {
        let isSelected = tappedTag == node.tag
        let hue = abs(node.tag.hashValue) % 360
        let baseColor = Color(hue: Double(hue) / 360.0, saturation: 0.55, brightness: 0.85)

        HStack(spacing: 4) {
            Text(node.tag)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text("\(node.count)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(
                    Capsule().fill(Color.white.opacity(0.25))
                )
        }
        .padding(.horizontal, nodePadding)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(isSelected ? Color.purple : baseColor)
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)
        .frame(minWidth: 50, minHeight: 30)
        .scaleEffect(isSelected ? 1.08 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    /// Approximate the rendered text width of a tag (used for label size scaling).
    private func nodeTextSize(_ text: String) -> CGSize {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold)
        ]
        return (text as NSString).size(withAttributes: attrs)
    }

    // MARK: - Layout / 布局计算

    private func recomputeLayout(in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let tags = graph.nodes.map { $0.tag }
        let result = TagGraphLayout.layout(
            tags: tags,
            edges: graph.edges,
            size: size,
            iterations: 120
        )
        // Build a case-insensitive lookup map for both original + lowercased.
        var merged: [String: CGPoint] = [:]
        for (key, value) in result {
            merged[key] = value
            merged[key.lowercased()] = value
        }
        positions = merged
    }

    // MARK: - Tap handling / 点击处理

    private func handleTap(_ tag: String) {
        // Toggle selected
        if tappedTag == tag {
            tappedTag = nil
            onSelectTag(tag)
        } else {
            tappedTag = tag
        }
    }
}

#Preview {
    let mock = [
        MistakeNote(title: "x", originalQuestion: "x", source: "x", errorReason: "x", wrongSolution: "x", correctSolution: "x", tags: ["函数", "导数"]),
        MistakeNote(title: "y", originalQuestion: "y", source: "y", errorReason: "y", wrongSolution: "y", correctSolution: "y", tags: ["函数", "三角"]),
        MistakeNote(title: "z", originalQuestion: "z", source: "z", errorReason: "z", wrongSolution: "z", correctSolution: "z", tags: ["三角", "解析几何", "导数"])
    ]
    return TagGraphView(mistakes: mock, onSelectTag: { _ in })
}
