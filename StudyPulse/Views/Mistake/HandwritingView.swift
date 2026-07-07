//
//  HandwritingView.swift
//  StudyPulse
//
//  iPad 用的 PencilKit 画图 NavigationLink 目的地。
//  iPad PencilKit drawing destination (NavigationLink).
//  与 `HandwritingSheet`（iPhone sheet 版）共享同款 `FlashcardHandwritingCanvasView`，
//  区别在于：
//  - 标题栏显示自定义「Back」按钮（带未保存提示）
//  - 不挂自己的 NavigationStack,沿用父级
//  - 系统 back 按钮被 .navigationBarBackButtonHidden(true) 隐藏,避免误触滑退丢画稿
//
//  Created by Chenkai Gao on 2026/7/7.
//

import SwiftUI
import PencilKit

/// iPad 错题登记 PencilKit 画图 NavigationLink 目的地
/// iPad PencilKit drawing destination pushed via NavigationLink.
struct HandwritingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var drawing = PKDrawing()
    @State private var showingDiscardAlert = false

    /// 提交时回调,父级负责把 PNG Data 转 UIImage / 追加图片数组
    let onDone: (Data) -> Void

    /// 当前画布上是否有未保存的笔迹
    /// True when the user has drawn something that has not been submitted.
    var hasUnsavedDrawing: Bool {
        !drawing.strokes.isEmpty
    }

    var body: some View {
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
        // 隐藏系统 back 按钮:用自定义 Back 按钮(带未保存确认),
        // 顺带禁用 iOS 边缘右滑返回手势,避免误触丢画稿
        // Hide the system back button (also disables the swipe-back gesture)
        // so the only way out is the explicit Back button → confirm dialog.
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    attemptDismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.subheadline.weight(.semibold))
                        Text("Back".localized())
                    }
                    .foregroundStyle(Color.accentColor)
                }
                .accessibilityLabel("Back".localized())
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

    /// 尝试退出:有未保存笔迹时先弹确认
    private func attemptDismiss() {
        if hasUnsavedDrawing {
            showingDiscardAlert = true
        } else {
            dismiss()
        }
    }
}
