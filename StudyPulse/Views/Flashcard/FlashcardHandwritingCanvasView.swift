//
//  FlashcardHandwritingCanvasView.swift
//  StudyPulse
//
//  闪卡手写答题的 PencilKit 画布。
//  Flashcard handwriting answer canvas: PKCanvasView + PKToolPicker,
//  with Submit / Clear actions. Renders the PKDrawing to PNG Data on submit.
//
//  Created by Chenkai Gao on 2026/7/7.
//

import SwiftUI
import PencilKit
import UIKit

// MARK: - Flashcard Handwriting Canvas
// MARK: - Flashcard handwriting canvas

/// 闪卡手写答题画布
/// SwiftUI wrapper around `PKCanvasView` for flashcard handwriting answers.
///
/// Usage:
/// ```swift
/// @State private var drawing = PKDrawing()
/// FlashcardHandwritingCanvasView(
///     drawing: $drawing,
///     hasContent: drawing.strokes.isEmpty == false,
///     onSubmit: { pngData in ... },
///     onClear: { drawing = PKDrawing() }
/// )
/// ```
struct FlashcardHandwritingCanvasView: View {
    /// 文案配置，默认与闪卡原行为一致；错题登记等场景可传入自定义 Labels。
    /// Label config — defaults match the original flashcard behavior so the
    /// existing call site in `FlashcardStudyView` needs no changes.
    struct Labels: Equatable {
        var header: String = "Handwriting"
        var hint: String = "Submit when done"
        var clear: String = "Clear"
        var submit: String = "Submit Answer"
    }

    /// 当前 PKDrawing 双向绑定（外部持有，提交后清空）
    @Binding var drawing: PKDrawing
    /// 画布是否有内容（用于决定 Submit 按钮的可用状态）
    let hasContent: () -> Bool
    /// 提交回调：把 PKDrawing 渲染为 PNG Data 后传出
    let onSubmit: (Data) -> Void
    /// 清除回调
    let onClear: () -> Void
    /// 最小高度（默认 400,匹配无边记的可见区域）
    var minHeight: CGFloat = 400
    /// 画布（白板）上限;无边记风格的可拖动白板,默认 2000×2000
    /// Whiteboard upper limit — Freeform-style draggable canvas.
    var canvasSize: CGSize = CGSize(width: 2000, height: 2000)
    /// 文案配置
    var labels: Labels = Labels()

    var body: some View {
        VStack(spacing: 0) {
            // 头部
            HStack(spacing: 6) {
                Image(systemName: "pencil.tip")
                    .font(.caption.weight(.semibold))
                Text(labels.header.localized())
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(labels.hint.localized())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))

            // 可拖动白板（无边记风格:双指拖动 / 捏合缩放,单指书写）
            DraggableCanvasRepresentable(drawing: $drawing, canvasSize: canvasSize)
                .frame(minHeight: minHeight)
                .background(Color.white)
                .clipShape(Rectangle())  // 保持直角,父容器用 RoundedRectangle 裁剪

            // 底部操作栏
            // Bottom action bar.
            HStack(spacing: 10) {
                Button(role: .destructive) {
                    onClear()
                } label: {
                    Label(labels.clear.localized(), systemImage: "trash")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)

                Button {
                    onSubmit(renderPNG())
                } label: {
                    Label(labels.submit.localized(), systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .disabled(!hasContent())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
        )
    }

    /// 把当前画布渲染为 PNG Data
    /// Render the current PKDrawing to PNG Data.
    /// 实际渲染由 `HandwritingCanvasRepresentable` 持有 `PKCanvasView` 引用，
    /// 这里调一个静态方法把 drawing 转 PNG。
    private func renderPNG() -> Data {
        // 用 drawing 的 bounds 作为渲染区域；如果为空则返回一个 1x1 透明 PNG
        let bounds: CGRect
        if drawing.bounds.isEmpty {
            bounds = CGRect(x: 0, y: 0, width: 1, height: 1)
        } else {
            // 上下左右各内缩一定量，避免笔触被裁剪
            bounds = drawing.bounds.insetBy(dx: -20, dy: -20)
        }
        let scale: CGFloat = min(2.0, UIScreen.main.scale)
        let image = drawing.image(from: bounds, scale: scale)
        return image.pngData() ?? Data()
    }
}

// MARK: - UIViewRepresentable
// MARK: - UIViewRepresentable

/// 可拖动的白板画布（无边记风格）。
/// Draggable whiteboard canvas (Freeform-style):
/// - UIScrollView 包裹 PKCanvasView,contentSize = canvasSize(上限)。
/// - 单指在画布上书写,双指拖动 / 捏合缩放白板。
/// - canvasSize 限制最大可绘/可平移范围,默认 2000×2000。
struct DraggableCanvasRepresentable: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    let canvasSize: CGSize

    func makeCoordinator() -> Coordinator {
        Coordinator(drawing: $drawing)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 0.5
        scrollView.maximumZoomScale = 3.0
        scrollView.bouncesZoom = true
        scrollView.alwaysBounceVertical = true
        scrollView.alwaysBounceHorizontal = true
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.backgroundColor = .white
        scrollView.contentSize = canvasSize
        scrollView.contentInsetAdjustmentBehavior = .never
        // 双指拖动,单指留给画笔书写
        // 2-finger pan so 1-finger still draws on the canvas.
        scrollView.panGestureRecognizer.minimumNumberOfTouches = 2

        let canvas = PKCanvasView()
        canvas.frame = CGRect(origin: .zero, size: canvasSize)
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .white
        canvas.isOpaque = true
        canvas.delegate = context.coordinator
        canvas.tool = PKInkingTool(.pen, color: .label, width: 5)
        canvas.drawing = drawing

        scrollView.addSubview(canvas)
        context.coordinator.canvas = canvas
        context.coordinator.scrollView = scrollView

        // 安装 PKToolPicker(浮在键盘区域,iPad 上会自动停靠)
        // Setup PKToolPicker (floats over keyboard area, auto-docks on iPad).
        DispatchQueue.main.async {
            guard let canvas = context.coordinator.canvas else { return }
            let toolPicker = PKToolPicker()
            toolPicker.setVisible(true, forFirstResponder: canvas)
            toolPicker.addObserver(canvas)
            canvas.becomeFirstResponder()
            context.coordinator.toolPicker = toolPicker

            // 居中初始内容(类似无边记打开新文档时的居中)
            let bounds = scrollView.bounds.size
            let horizontalInset = max(0, (bounds.width - canvasSize.width) / 2)
            let verticalInset = max(0, (bounds.height - canvasSize.height) / 2)
            scrollView.contentInset = UIEdgeInsets(
                top: verticalInset,
                left: horizontalInset,
                bottom: verticalInset,
                right: horizontalInset
            )
        }

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        guard let canvas = context.coordinator.canvas else { return }
        // 仅当外部 binding 与 canvas 内部的 drawing 显著不同时才回写
        // Only re-write the canvas when the binding actually differs.
        if canvas.drawing.dataRepresentation() != drawing.dataRepresentation() {
            canvas.drawing = drawing
        }
    }

    static func dismantleUIView(_ uiView: UIScrollView, coordinator: Coordinator) {
        if let picker = coordinator.toolPicker, let canvas = coordinator.canvas {
            picker.removeObserver(canvas)
            picker.setVisible(false, forFirstResponder: canvas)
        }
        coordinator.toolPicker = nil
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject, PKCanvasViewDelegate, UIScrollViewDelegate {
        @Binding var drawing: PKDrawing
        weak var canvas: PKCanvasView?
        weak var scrollView: UIScrollView?
        var toolPicker: PKToolPicker?

        init(drawing: Binding<PKDrawing>) {
            self._drawing = drawing
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return canvas
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            // 同步到 binding
            // Push the canvas state back into the SwiftUI binding.
            drawing = canvasView.drawing
        }
    }
}
