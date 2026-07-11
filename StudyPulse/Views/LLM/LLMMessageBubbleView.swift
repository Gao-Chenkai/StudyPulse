//
//  LLMMessageBubbleView.swift
//  StudyPulse
//
//  AI 助手单条消息气泡。user 右对齐纯文本,assistant 左对齐 + MarkdownView
//  流式渲染(每次 content 更新会重新 parse,内含 `task(id: text)`)。
//
//  Created for LLM BYOK integration (2026-07-11).
//

import SwiftUI
import SwiftStreamingMarkdown

struct LLMMessageBubbleView: View {
    let message: LLMChatViewModel.Message

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 40)
                userBubble
            } else {
                assistantBubble
                Spacer(minLength: 40)
            }
        }
    }

    // MARK: - User Bubble

    private var userBubble: some View {
        Text(message.content)
            .font(.body)
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.accentColor)
            )
            .frame(maxWidth: 280, alignment: .trailing)
            .textSelection(.enabled)
    }

    // MARK: - Assistant Bubble

    private var assistantBubble: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "brain")
                    .font(.caption)
                    .foregroundColor(.teal)
                Text("AI".localized())
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.teal)
                if message.isStreaming {
                    ProgressView()
                        .scaleEffect(0.6)
                        .padding(.leading, 4)
                }
                Spacer()
            }
            if let err = message.error {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.red)
            } else if message.content.isEmpty && message.isStreaming {
                Text("Thinking...".localized())
                    .font(.body)
                    .foregroundColor(.secondary)
            } else {
                MarkdownView(
                    text: message.content.normalisingSingleDollarMath(),
                    config: .previewConfig
                )
                .textSelection(.enabled)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemBackground))
        )
        .frame(maxWidth: 300, alignment: .leading)
    }
}
