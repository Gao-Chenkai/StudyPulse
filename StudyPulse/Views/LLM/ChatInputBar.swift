//
//  ChatInputBar.swift
//  StudyPulse
//
//  统一的聊天输入框:三个 chat 界面共用,呈现为"悬浮在底部的 Liquid Glass 胶囊"。
//  iOS 26 用 `Color.clear.glassEffect(.regular.interactive(), in: Capsule())`,
//  老版本 fallback `.regularMaterial` 胶囊。
//
//  Created for chat UI unification (2026-07-11).
//

import SwiftUI

/// 三个 chat 界面共用的底部浮动输入框。
/// 用 `Binding` 跟外部 ViewModel 同步文本,`onSend` 回调负责把消息发出去。
struct ChatInputBar: View {
    @Binding var text: String
    let placeholder: String
    let isStreaming: Bool
    let canSend: Bool
    let onSend: () -> Void
    var onCancel: (() -> Void)? = nil

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

    // MARK: - 胶囊

    private var inputCapsule: some View {
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
                        Capsule().fill(.regularMaterial)
                    }
                }
            )
            .overlay(
                Capsule()
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
