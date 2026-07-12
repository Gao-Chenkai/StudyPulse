//
//  ChatBubble.swift
//  StudyPulse
//
//  统一的聊天消息气泡(user / assistant),三个聊天界面共用。
//  三个 chat 界面曾经各自实现气泡,样式 / 宽度 / 动画都各做各的;
//  这里是单一来源,以后再改样式只改这一处。
//
//  Created for chat UI unification (2026-07-11).
//

import SwiftUI
import Combine
import SwiftStreamingMarkdown

/// 统一的聊天气泡:user 右对齐小框,assistant 左对齐宽框(上限 600pt)。
/// 三个 chat 界面 (LLMChatView / AIDiscussionSheet / HomeAskSheet) 都通过本组件渲染。
struct ChatBubble: View {
    enum Role {
        case user
        /// `dimmed: true` 用于"上一次的 AI 预测"等只读上下文,
        /// 背景色更弱、加细描边、整体降低不透明度
        case assistant(dimmed: Bool)

        var isUser: Bool {
            if case .user = self { return true }
            return false
        }
        var isDimmed: Bool {
            if case .assistant(let d) = self { return d }
            return false
        }
    }

    let role: Role
    let content: String
    let isStreaming: Bool
    let error: String?
    /// assistant 头部"AI"标签右侧的小文字(如 "·  身体 · 成绩" 或 "以下对话基于上一次的 AI 预测")
    let headerTag: String?
    /// 气泡下方的额外内容(HomeAsk 的"数据快照"折叠区)
    let footer: AnyView?

    init(
        role: Role,
        content: String,
        isStreaming: Bool = false,
        error: String? = nil,
        headerTag: String? = nil,
        footer: AnyView? = nil
    ) {
        self.role = role
        self.content = content
        self.isStreaming = isStreaming
        self.error = error
        self.headerTag = headerTag
        self.footer = footer
    }

    var body: some View {
        Group {
            if role.isUser {
                userBubble
            } else {
                assistantBubble
            }
        }
        // 新消息:从下方轻微上浮 + 渐入,跟聊天 App 习惯一致
        .transition(.asymmetric(
            insertion: .scale(
                scale: 0.85,
                anchor: role.isUser ? .bottomTrailing : .bottomLeading
            )
            .combined(with: .opacity)
            .combined(with: .move(edge: .bottom)),
            removal: .opacity
        ))
    }

    // MARK: - User Bubble

    private var userBubble: some View {
        HStack {
            Spacer(minLength: 40)
            Text(content)
                .font(.body)
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.accentColor)
                )
                .frame(maxWidth: 320, alignment: .trailing)
                .textSelection(.enabled)
        }
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
                if let headerTag, !headerTag.isEmpty {
                    Text("·  " + headerTag)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                if isStreaming {
                    ProgressView()
                        .scaleEffect(0.6)
                        .padding(.leading, 4)
                        .modifier(PulseModifier())
                }
                Spacer()
            }
            if let err = error {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.red)
            } else if content.isEmpty && isStreaming {
                HStack(spacing: 6) {
                    Text("Thinking...".localized())
                        .font(.body)
                        .foregroundColor(.secondary)
                    TypingDots()
                }
            } else {
                MarkdownView(
                    text: content.normalisingSingleDollarMath(),
                    config: .previewConfig
                )
                .textSelection(.enabled)
            }
            if let footer {
                footer
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(role.isDimmed
                      ? Color(.tertiarySystemBackground)
                      : Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(
                    role.isDimmed ? Color.secondary.opacity(0.25) : Color.clear,
                    lineWidth: 1
                )
        )
        .opacity(role.isDimmed ? 0.85 : 1.0)
        // 关键:iPad / 横屏下 600pt 上限,允许 AI 框随着屏幕变宽
        .frame(maxWidth: 600, alignment: .leading)
    }
}

// MARK: - 思考中动画(被 ChatBubble 使用,跨文件 internal)

/// 加载指示器周围的轻微脉动修饰符(0.9 ↔ 1.0)
struct PulseModifier: ViewModifier {
    @State private var pulsing = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(pulsing ? 1.15 : 0.95)
            .opacity(pulsing ? 0.6 : 1.0)
            .animation(
                .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                value: pulsing
            )
            .onAppear { pulsing = true }
    }
}

/// 三个点的打字机动画(··· 依次淡入)
struct TypingDots: View {
    @State private var phase: Int = 0
    private let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 4, height: 4)
                    .opacity(phase == i ? 1.0 : 0.3)
            }
        }
        .onReceive(timer) { _ in
            phase = (phase + 1) % 3
        }
    }
}
