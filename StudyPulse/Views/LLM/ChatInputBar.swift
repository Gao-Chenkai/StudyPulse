//
//  ChatInputBar.swift
//  StudyPulse
//
//  统一的聊天输入框:三个 chat 界面共用,呈现为"悬浮在底部的 Liquid Glass 胶囊"。
//  iOS 26 用 `Color.clear.glassEffect(.regular.interactive(), in: Capsule())`,
//  老版本 fallback `.regularMaterial` 胶囊。
//
//  Unified chat input bar: shared by all three chat screens, rendered as
//  a "floating Liquid Glass capsule" at the bottom.
//  iOS 26 uses `Color.clear.glassEffect(.regular.interactive(), in: Capsule())`,
//  older versions fall back to a `.regularMaterial` capsule.
//

import SwiftUI

/// 三个 chat 界面共用的底部浮动输入框。
/// 用 `Binding` 跟外部 ViewModel 同步文本,`onSend` 回调负责把消息发出去。
/// Shared floating bottom input bar for the three chat screens.
/// Uses a `Binding` to sync text with the parent view model; `onSend`
/// is the callback that actually dispatches the message.
struct ChatInputBar: View {
    /// 双向绑定的输入文本
    /// Two-way bound input text.
    @Binding var text: String
    /// 占位文字
    /// Placeholder string.
    let placeholder: String
    /// 是否处于流式生成中(显示 stop 按钮)
    /// Whether a stream is in progress (shows the stop button).
    let isStreaming: Bool
    /// 是否允许发送
    /// Whether sending is currently allowed.
    let canSend: Bool
    /// 发送回调(主对话按钮)
    /// Send callback (primary action).
    let onSend: () -> Void
    /// 取消回调(流式生成中显示)
    /// Cancel callback (shown while streaming).
    var onCancel: (() -> Void)? = nil

    /// 输入框焦点状态,用于驱动描边透明度
    /// Input focus state, drives the border opacity.
    @FocusState private var focused: Bool

    init(
        text: Binding<String>,
        placeholder: String = "Ask anything...".localized(),
        isStreaming: Bool,
        canSend: Bool,
        onSend: @escaping () -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.isStreaming = isStreaming
        self.canSend = canSend
        self.onSend = onSend
        self.onCancel = onCancel
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            inputCapsule
            if isStreaming, let onCancel {
                Button {
                    onCancel()
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.red)
                }
            } else {
                Button {
                    onSend()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(canSend ? .accentColor : .secondary)
                }
                .disabled(!canSend)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    // MARK: - 胶囊 / Capsule

    private var inputCapsule: some View {
        // axis: .vertical + lineLimit 1...5 → 文本框可随输入自动增高
        // axis: .vertical + lineLimit 1...5 → field grows up to 5 lines
        // as the user types multiline messages.
        TextField(placeholder, text: $text, axis: .vertical)
            .lineLimit(1...5)
            .focused($focused)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .background(
                Group {
                    if #available(iOS 26.0, *) {
                        // iOS 26 真正的 liquid glass
                        // Real liquid glass on iOS 26+: Color.clear + Capsule + glassEffect
                        Color.clear
                            .glassEffect(.regular.interactive(), in: Capsule())
                    } else {
                        // iOS 18- fallback: 同样的胶囊 + regularMaterial
                        // iOS 18- fallback: same capsule shape with .regularMaterial.
                        Capsule().fill(.regularMaterial)
                    }
                }
            )
            .overlay(
                Capsule()
                    // 聚焦时描边更明显:opacity 0.08 → 0.15
                    // Brighter border on focus: opacity 0.08 → 0.15.
                    .strokeBorder(
                        Color.primary.opacity(focused ? 0.15 : 0.08),
                        lineWidth: focused ? 1 : 0.5
                    )
            )
            .onSubmit {
                if canSend { onSend() }
            }
    }
}
