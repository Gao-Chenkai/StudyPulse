//
//  AutoMindMapView.swift
//  StudyPulse
//
//  Created by Antigravity on 2026/7/13.
//  Copyright © 2026 Chenkai Gao. All rights reserved.
//

import SwiftUI
import SwiftStreamingMarkdown
import UniformTypeIdentifiers
import Photos
import UIKit

/// 错题交互式思维导图视图
/// Interactive mind map view for mistakes.
/// 提供平移、缩放手势，展示 Root -> Theme -> KnowledgePoint -> Mistake 的放射结构
/// Supports panning, zooming, and displays a radial Root -> Theme -> KP -> Mistake hierarchy.
struct AutoMindMapView: View {
    // MARK: - Dependencies / 依赖项
    
    @Environment(RepositoryContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - View Parameters / 外部传入参数
    
    /// 待生成导图的错题列表
    /// List of mistakes to build the mind map for.
    let mistakes: [MistakeNote]
    
    /// 导图上下文标题（学科名称或 "My Mistakes"）
    /// Context title for the map (e.g. subject name or "My Mistakes").
    let contextTitle: String
    
    // MARK: - Local States / 本地视图状态
    
    /// 视图模型，控制异步加载与极坐标系布局计算
    /// View model managing asynchronous loading and polar coordinate layout.
    @State private var viewModel: AutoMindMapViewModel
    
    /// 是否正在显示 AI 问答 (HomeAsk 通道)
    /// Whether the HomeAsk view sheet is currently shown.
    @State private var showingHomeAsk = false
    
    /// 传给 HomeAsk 通道的问题内容
    /// The pre-filled question text passed to the HomeAsk sheet.
    @State private var homeAskQuestion: String? = nil

    /// 导出图片状态 / Image export state.
    @State private var isExportingImage = false
    @State private var imageDocument: ReportImageDocument?
    @State private var exportErrorMessage: String?
    @State private var exportFeedbackTitle = "Export Failed"
    
    // MARK: - Viewport Controls (Pan / Zoom) / 画布平移与缩放状态
    
    /// 画布累计的平移量
    /// Accumulated canvas translation offset.
    @State private var canvasOffset: CGSize = .zero
    
    /// 画布当前的缩放比例
    /// Current canvas scale factor.
    @State private var canvasScale: CGFloat = 1.0
    
    /// 拖拽手势过程中的临时偏移量
    /// Temporary drag offset during the gesture.
    @GestureState private var dragAccumulator: CGSize = .zero
    
    /// 捏合缩放手势过程中的临时比例
    /// Temporary scale during the magnification gesture.
    @GestureState private var magnifyBy: CGFloat = 1.0
    
    // MARK: - Initializer / 初始化
    init(mistakes: [MistakeNote], contextTitle: String = "My Mistakes") {
        self.mistakes = mistakes
        self.contextTitle = contextTitle
        
        // 绑定 ViewModel
        // Bind the state-managed ViewModel.
        _viewModel = State(
            initialValue: AutoMindMapViewModel(mistakes: mistakes, contextTitle: contextTitle)
        )
    }
    
    // MARK: - Body / 视图主体
    var body: some View {
        NavigationStack {
            ZStack {
                // 1. 背景底色
                // 1. Background color.
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                // 2. 主体状态分流渲染
                // 2. Conditional rendering based on loading state.
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.nodes.isEmpty {
                    emptyView
                } else {
                    interactiveCanvas
                }
                
                // 3. 悬浮在画布左下角的图例
                // 3. Floating legend at the bottom left.
                if !viewModel.isLoading && !viewModel.nodes.isEmpty {
                    legendView
                }
            }
            .navigationTitle("Auto Mind Map".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close".localized())
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        // 重新归位按钮
                        // Recenter layout button.
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                canvasOffset = .zero
                                canvasScale = 1.0
                            }
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                        }
                        .disabled(viewModel.nodes.isEmpty)
                        .accessibilityLabel("Recenter".localized())

                        Menu {
                            Button(action: exportMindMapImage) {
                                Label("Export Image".localized(), systemImage: "square.and.arrow.up")
                            }
                            Button(action: saveMindMapToPhotos) {
                                Label("Save to Photos".localized(), systemImage: "photo")
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .disabled(viewModel.isLoading || viewModel.nodes.isEmpty)
                        .accessibilityLabel("Export Image".localized())
                    }
                }
            }
            .task {
                // 自动载入思维导图数据
                // Auto-trigger generation pipeline on view task.
                await viewModel.generate(config: container.envManager.llmConfig)
            }
            // 绑定 AI 提问通道 Sheet
            // Present HomeAsk sheet when showingHomeAsk is triggered.
            .sheet(isPresented: $showingHomeAsk) {
                if let question = homeAskQuestion {
                    HomeAskSheet(container: container, envManager: container.envManager, initialQuestion: question)
                        .environment(container)
                }
            }
            .fileExporter(
                isPresented: $isExportingImage,
                document: imageDocument,
                contentType: .png,
                defaultFilename: imageDocument?.fileName
            ) { result in
                switch result {
                case .success(let url):
                    Log.record(.info, category: "Export", message: "错题思维导图导出成功 / Mind map image exported: url=\(url.path)")
                case .failure(let error):
                    Log.record(.error, category: "Export", message: "错题思维导图导出失败 / Mind map image export failed: \(error.localizedDescription)")
                }
                imageDocument = nil
            }
            .alert(exportFeedbackTitle.localized(), isPresented: Binding(
                get: { exportErrorMessage != nil },
                set: { if !$0 { exportErrorMessage = nil } }
            )) {
                Button("OK".localized()) { exportErrorMessage = nil }
            } message: {
                Text(exportErrorMessage ?? "")
            }
        }
    }
    
    // MARK: - Subviews / 子视图定义
    
    /// 加载中骨架屏与提示
    /// Loading state screen with spinner.
    private var loadingView: some View {
        AIWaitingView(
            title: "Generating mind map...".localized(),
            messages: [
                "AI正在结合历史数据...".localized(),
                "AI正在提炼表达...".localized(),
                "正在提取错题中的核心概念...".localized(),
                "正在梳理知识脉络与关联...".localized(),
                "正在绘制个性化知识拓扑结构...".localized()
            ],
            onCancel: { dismiss() }
        )
    }
    
    /// 空状态视图
    /// Empty placeholder when no data exists.
    private var emptyView: some View {
        ContentUnavailableView(
            "No Mistakes".localized(),
            systemImage: "arrow.triangle.branch",
            description: Text("Not enough mistake notes to generate a mind map. Please add some mistakes first.".localized())
        )
    }
    
    /// 核心交互式网格画布
    /// Core interactive viewport canvas.
    private var interactiveCanvas: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let totalScale = canvasScale * magnifyBy
            
            ZStack {
                // 用于捕获画布级手势的透明背景层
                // Invisible shape to capture gestures on empty space.
                Color.clear.contentShape(Rectangle())
                
                // A. 放射连接线（用 SwiftUI Canvas 绘制）
                // A. Connecting edges (rendered using SwiftUI Canvas).
                Canvas { context, _ in
                    for edge in viewModel.edges {
                        // 寻找对应目标节点的 level 以决定连接线样式
                        // Look up destination node's depth level for styling.
                        let toNode = viewModel.nodes.first(where: { $0.id == edge.toNodeId })
                        let level = toNode?.level ?? 2
                        
                        drawRadialEdge(
                            context: context,
                            from: CGPoint(x: edge.from.x + center.x, y: edge.from.y + center.y),
                            to: CGPoint(x: edge.to.x + center.x, y: edge.to.y + center.y),
                            level: level
                        )
                    }
                }
                .allowsHitTesting(false)
                
                // B. 交互节点层（悬浮在 canvas 之上）
                // B. Node components layer placed over the Canvas.
                ForEach(viewModel.nodes) { node in
                    let absPos = CGPoint(
                        x: node.position.x + center.x,
                        y: node.position.y + center.y
                    )
                    nodeComponent(for: node)
                        .position(absPos)
                }
            }
            .frame(width: size.width, height: size.height)
            // 极坐标系视图平移与缩放矩阵变换
            // Viewport matrix transformation for zoom and pan.
            .scaleEffect(totalScale, anchor: .center)
            .offset(
                x: canvasOffset.width + dragAccumulator.width,
                y: canvasOffset.height + dragAccumulator.height
            )
            // 绑定双指缩放
            // Bind magnification gesture.
            .gesture(
                MagnificationGesture()
                    .updating($magnifyBy) { value, state, _ in
                        state = value
                    }
                    .onEnded { value in
                        canvasScale = max(0.3, min(2.5, canvasScale * value))
                    }
            )
            // 绑定单指拖拽平移
            // Bind simultaneous drag gesture.
            .simultaneousGesture(
                DragGesture(minimumDistance: 5)
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
        }
    }

    /// Content-sized, non-interactive canvas used for PNG export.
    private var exportCanvas: some View {
        let bounds = exportBounds
        return ZStack {
            Color(.systemGroupedBackground)
            Canvas { context, _ in
                for edge in viewModel.edges {
                    drawRadialEdge(
                        context: context,
                        from: edge.from,
                        to: edge.to,
                        level: viewModel.nodes.first(where: { $0.id == edge.toNodeId })?.level ?? 2,
                        translation: CGPoint(x: -bounds.minX, y: -bounds.minY)
                    )
                }
            }
            ForEach(viewModel.nodes) { node in
                exportNodeComponent(for: node)
                    .position(CGPoint(x: node.position.x - bounds.minX, y: node.position.y - bounds.minY))
            }
        }
        .frame(width: bounds.width, height: bounds.height)
        .clipped()
    }

    private var exportBounds: CGRect {
        guard let first = viewModel.nodes.first else {
            return CGRect(x: 0, y: 0, width: 800, height: 600)
        }
        var minX = first.position.x
        var maxX = first.position.x
        var minY = first.position.y
        var maxY = first.position.y
        for node in viewModel.nodes.dropFirst() {
            minX = min(minX, node.position.x)
            maxX = max(maxX, node.position.x)
            minY = min(minY, node.position.y)
            maxY = max(maxY, node.position.y)
        }
        let padding: CGFloat = 150
        return CGRect(
            x: minX - padding,
            y: minY - padding,
            width: max(maxX - minX + padding * 2, 800),
            height: max(maxY - minY + padding * 2, 600)
        )
    }

    @ViewBuilder
    private func exportNodeComponent(for node: MindMapLayoutNode) -> some View {
        switch node.kind {
        case .root(let title):
            Text(title)
                .font(.system(.body, design: .rounded).weight(.bold))
                .foregroundColor(.white)
                .padding(.horizontal, 22).padding(.vertical, 11)
                .background(Capsule().fill(container.envManager.effectiveAccentColor))
        case .theme(let name):
            Text(name)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Capsule().fill(Color(.secondarySystemGroupedBackground)))
                .overlay(Capsule().stroke(container.envManager.effectiveAccentColor.opacity(0.55), lineWidth: 1.8))
        case .knowledgePoint(let name):
            Text(name)
                .font(.system(.footnote, design: .rounded).weight(.medium))
                .foregroundColor(.primary)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(Color(.tertiarySystemGroupedBackground)))
                .overlay(Capsule().stroke(Color.purple.opacity(0.45), lineWidth: 1.2))
        case .mistake(let note):
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle.fill").font(.caption2).foregroundColor(.red.opacity(0.85))
                Text(note.title).font(.system(.caption, design: .rounded)).lineLimit(1)
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(Color(.secondarySystemGroupedBackground)))
            .overlay(Capsule().stroke(Color.red.opacity(0.25), lineWidth: 0.8))
        }
    }
    
    /// 按节点类型分类渲染具体的外观样式
    /// Render specific styles for each node type.
    @ViewBuilder
    private func nodeComponent(for node: MindMapLayoutNode) -> some View {
        switch node.kind {
        case .root(let title):
            // 根节点：大胶囊、主色渐变背景
            // Root Node: Large capsule, bold gradient.
            Text(title)
                .font(.system(.body, design: .rounded).weight(.bold))
                .foregroundColor(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 11)
                .background(
                    Capsule()
                        .fill(LinearGradient(
                            colors: [container.envManager.effectiveAccentColor, container.envManager.effectiveAccentColor.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .shadow(color: container.envManager.effectiveAccentColor.opacity(0.35), radius: 10, x: 0, y: 5)
                )
            
        case .theme(let name):
            // 主题节点：中胶囊，高亮描边
            // Theme Node: Medium capsule with highlighted accent border.
            Text(name)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color(.secondarySystemGroupedBackground))
                        .shadow(color: Color.black.opacity(0.06), radius: 5, x: 0, y: 2)
                )
                .overlay(
                    Capsule()
                        .stroke(container.envManager.effectiveAccentColor.opacity(0.55), lineWidth: 1.8)
                )
                .contextMenu {
                    contextMenuOptions(for: name)
                }
            
        case .knowledgePoint(let name):
            // 知识点节点：小胶囊，紫色边框表示核心概念
            // KP Node: Small capsule with purple borders for core concepts.
            Text(name)
                .font(.system(.footnote, design: .rounded).weight(.medium))
                .foregroundColor(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color(.tertiarySystemGroupedBackground))
                        .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1.5)
                )
                .overlay(
                    Capsule()
                        .stroke(Color.purple.opacity(0.45), lineWidth: 1.2)
                )
                .contextMenu {
                    contextMenuOptions(for: name)
                }
            
        case .mistake(let note):
            // 叶子节点（具体错题）：支持点击导航与长按快捷 AI 讲解
            // Leaf Node (Mistake): supports tap navigation and long-press AI explanation.
            NavigationLink(
                destination: MistakeSetDetailView(mistakeSet: note)
                    .environment(container)
            ) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.red.opacity(0.85))
                    Text(note.title)
                        .font(.system(.caption, design: .rounded))
                        .lineLimit(1)
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color(.secondarySystemGroupedBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                )
                .overlay(
                    Capsule()
                        .stroke(Color.red.opacity(0.25), lineWidth: 0.8)
                )
            }
            .buttonStyle(.plain)
            .contextMenu {
                // 如果能追溯到其所属的知识点，优先用知识点名字提问，否则直接用题目标题
                // Ask using parent KP name if available, otherwise fallback to mistake title.
                let kpName = viewModel.mistakeToKP[note.id.uuidString] ?? note.title
                contextMenuOptions(for: kpName)
            }
        }
    }
    
    /// 节点的上下文长按菜单
    /// Context menu options for nodes.
    @ViewBuilder
    private func contextMenuOptions(for targetName: String) -> some View {
        Button {
            triggerAIExplanation(for: targetName)
        } label: {
            Label("AI Explain Concept".localized(), systemImage: "sparkles")
        }
    }
    
    /// 左下角浮动图例视图与模式标识（AI 模式 / 本地规则降级模式）
    /// Legend overlay with model run status (AI mode vs Local fallback).
    private var legendView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // A. AI 模式标牌
            // A. AI classification label.
            HStack(spacing: 6) {
                if viewModel.isUsingFallback {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.amber)
                    Text("Local Fallback".localized())
                        .font(.caption.weight(.bold))
                        .foregroundColor(.primary)
                } else {
                    Image(systemName: "sparkles")
                        .foregroundColor(.teal)
                    Text("AI Classified".localized())
                        .font(.caption.weight(.bold))
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color(.secondarySystemGroupedBackground).opacity(0.9))
                    .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
            )
            .padding(.bottom, 4)
            
            // B. 节点图例卡片
            // B. Color-coded legend card.
            VStack(alignment: .leading, spacing: 6) {
                legendItem(title: "Main Node".localized(), color: container.envManager.effectiveAccentColor, isRoot: true)
                legendItem(title: "Theme".localized(), color: container.envManager.effectiveAccentColor)
                legendItem(title: "Concept".localized(), color: .purple)
                legendItem(title: "Mistake".localized(), color: .red)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemGroupedBackground).opacity(0.9))
                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .allowsHitTesting(false)
    }
    
    /// 单个图例元素
    /// Single legend item layout.
    private func legendItem(title: String, color: Color, isRoot: Bool = false) -> some View {
        HStack(spacing: 8) {
            if isRoot {
                Capsule()
                    .fill(color)
                    .frame(width: 14, height: 8)
            } else {
                Capsule()
                    .stroke(color, lineWidth: 1.5)
                    .frame(width: 14, height: 8)
            }
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Drawing & Action Helpers / 绘图与业务辅助
    
    /// 用三阶贝塞尔曲线绘制平滑的分支线
    /// Draw smooth radial branches using cubic Bezier paths.
    private func drawRadialEdge(
        context: GraphicsContext,
        from: CGPoint,
        to: CGPoint,
        level: Int,
        translation: CGPoint = .zero
    ) {
        var path = Path()
        path.move(to: CGPoint(x: from.x + translation.x, y: from.y + translation.y))
        
        // Use relative offsets from origin.
        let dx1 = from.x
        let dy1 = from.y
        let dx2 = to.x
        let dy2 = to.y
        
        let r1 = sqrt(dx1 * dx1 + dy1 * dy1)
        let r2 = sqrt(dx2 * dx2 + dy2 * dy2)
        let rMid = (r1 + r2) / 2
        
        let theta1 = atan2(dy1, dx1)
        let theta2 = atan2(dy2, dx2)
        
        let c1: CGPoint
        let c2: CGPoint
        
        // 若起始点为 Root (0, 0)，控制点在向外延伸的切线上
        // Origin transitions: straight tangents going outwards.
        if r1 < 5 {
            c1 = CGPoint(x: (r2 / 4.0) * cos(theta2), y: (r2 / 4.0) * sin(theta2))
            c2 = CGPoint(x: (r2 * 3.0 / 4.0) * cos(theta2), y: (r2 * 3.0 / 4.0) * sin(theta2))
        } else {
            c1 = CGPoint(x: rMid * cos(theta1), y: rMid * sin(theta1))
            c2 = CGPoint(x: rMid * cos(theta2), y: rMid * sin(theta2))
        }
        
        path.addCurve(
            to: CGPoint(x: to.x + translation.x, y: to.y + translation.y),
            control1: CGPoint(x: c1.x + translation.x, y: c1.y + translation.y),
            control2: CGPoint(x: c2.x + translation.x, y: c2.y + translation.y)
        )
        
        let strokeColor: Color
        let strokeWidth: CGFloat
        
        switch level {
        case 1:
            strokeColor = container.envManager.effectiveAccentColor.opacity(0.4)
            strokeWidth = 2.0
        case 2:
            strokeColor = container.envManager.effectiveAccentColor.opacity(0.3)
            strokeWidth = 1.5
        case 3:
            strokeColor = Color.purple.opacity(0.25)
            strokeWidth = 1.0
        default:
            strokeColor = Color.secondary.opacity(0.2)
            strokeWidth = 1.0
        }
        
        context.stroke(
            path,
            with: .color(strokeColor),
            style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
        )
    }

    /// Render the complete map and present the system Save-to-Files/share flow.
    private func exportMindMapImage() {
        guard let image = renderedMindMapImage(),
              let data = ReportRenderer.encode(image, format: .png) else {
            exportErrorMessage = "Unable to export the mind map image.".localized()
            return
        }

        exportFeedbackTitle = "Export Failed"
        let fileName = "StudyPulse_MindMap_\(DateFormatters.fileTimestamp.string(from: Date())).png"
        imageDocument = ReportImageDocument(data: data, fileName: fileName, contentType: .png)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            guard !Task.isCancelled else { return }
            isExportingImage = true
        }
    }

    /// Render the complete map and save it directly to the user's Photos library.
    private func saveMindMapToPhotos() {
        guard let image = renderedMindMapImage() else {
            exportFeedbackTitle = "Export Failed"
            exportErrorMessage = "Unable to export the mind map image.".localized()
            return
        }

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                Task { @MainActor in
                    exportFeedbackTitle = "Save to Photos Failed"
                    exportErrorMessage = "Photo library access is required to save this image.".localized()
                }
                return
            }

            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                Task { @MainActor in
                    if success {
                        exportFeedbackTitle = "Saved to Photos"
                        exportErrorMessage = "Mind map image saved to Photos.".localized()
                        Log.record(.info, category: "Export", message: "错题思维导图已保存到相册 / Mind map image saved to Photos")
                    } else {
                        exportFeedbackTitle = "Save to Photos Failed"
                        exportErrorMessage = error?.localizedDescription ?? "Unable to save the mind map image to Photos.".localized()
                        Log.record(.error, category: "Export", message: "错题思维导图保存到相册失败 / Failed to save mind map image to Photos: \(error?.localizedDescription ?? "unknown error")")
                    }
                }
            }
        }
    }

    private func renderedMindMapImage() -> UIImage? {
        guard !viewModel.nodes.isEmpty else { return nil }
        return ReportRenderer.render(exportCanvas, size: exportBounds.size, scale: 2.0)
    }
    
    /// 触发 AI 讲解知识点并弹出 HomeAsk 界面
    /// Trigger AI explanation and present the HomeAsk sheet.
    private func triggerAIExplanation(for concept: String) {
        let question = String(format: "AI explain concept query".localized(), concept)
        self.homeAskQuestion = question
        self.showingHomeAsk = true
    }
}

// MARK: - Color Extension helper for legend
extension Color {
    static let amber = Color(red: 245/255, green: 158/255, blue: 11/255)
}
