//
//  HandwritingSheet.swift
//  StudyPulse
//
//  错题登记「Draw」按钮弹出的 PencilKit 画图 sheet。
//  PencilKit drawing sheet presented by the "Draw" button in the mistake
//  registration image toolbar. Wraps `FlashcardHandwritingCanvasView` in a
//  NavigationStack, exposes Cancel / Use This Drawing actions, and converts
//  the resulting PNG to Data via the `onDone` callback.
//
//  Created by Chenkai Gao on 2026/7/7.
//

import SwiftUI
import PencilKit

/// 错题登记用的 PencilKit 画图 sheet
/// PencilKit sheet used by the mistake registration flow.
struct HandwritingSheet: View {
    @Environment(\.dismiss) private var dismiss
    /// PencilKit 当前画板内容
    /// Current PencilKit drawing content.
    @State private var drawing = PKDrawing()
    /// 是否弹出"放弃当前画稿?"确认
    /// Whether to show the "Discard your drawing?" confirmation.
    @State private var showingDiscardAlert = false

    /// 提交时回调,父级负责把 PNG Data 转 UIImage / 追加图片数组
    /// Called on submit with the rendered PNG Data. The parent converts
    /// the data to a UIImage and appends it to the current section's images.
    let onDone: (Data) -> Void

    /// 当前画布上是否有未保存的笔迹
    /// True when the user has drawn something that has not been submitted.
    var hasUnsavedDrawing: Bool {
        !drawing.strokes.isEmpty
    }

    var body: some View {
        NavigationStack {
            // 用 ScrollView 包裹使内容可滚动,避开 PKToolPicker 遮挡底部按钮
            // Wrap in ScrollView so the user can scroll the canvas (and the
            // bottom action bar) past the floating PKToolPicker.
            ScrollView {
                FlashcardHandwritingCanvasView(
                    drawing: $drawing,
                    hasContent: { hasUnsavedDrawing },
                    onSubmit: { pngData in
                        onDone(pngData)
                        dismiss()
                    },
                    onClear: { drawing = PKDrawing() },
                    labels: .init(
                        header: "Drawing",
                        hint: "Drag with 2 fingers to pan, pinch to zoom",
                        clear: "Clear",
                        submit: "Use This Drawing"
                    )
                )
                .padding(16)
            }
            .navigationTitle("Draw".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel".localized()) {
                        attemptDismiss()
                    }
                }
            }
            .confirmationDialog(
                "Discard your drawing?".localized(),
                isPresented: $showingDiscardAlert,
                titleVisibility: .visible
            ) {
                Button("Discard".localized(), role: .destructive) {
                    dismiss()
                }
                Button("Keep Drawing".localized(), role: .cancel) { }
            } message: {
                Text("Your drawing will not be saved.".localized())
            }
        }
        // 阻止 iOS 滑动手势误触关闭 sheet,避免有未保存笔迹时丢失画稿;
        // 用户必须通过 Cancel 按钮退出,Cancel 按钮内部调用 attemptDismiss
        // 处理未保存确认。
        // Block swipe-to-dismiss so the user cannot lose strokes by accident;
        // they must go through the explicit Cancel button, which calls
        // attemptDismiss() to show the discard confirmation.
        .interactiveDismissDisabled(hasUnsavedDrawing)
    }

    /// 尝试退出:有未保存笔迹时先弹确认
    private func attemptDismiss() {
        if hasUnsavedDrawing {
            showingDiscardAlert = true
        } else {
            dismiss()
        }
    }
}
