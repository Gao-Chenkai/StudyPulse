//
//  AIDiscussionSheet.swift
//  StudyPulse
//
//  "深入探讨" 对话 sheet:从 AI 预测/分析结果入口打开,让用户基于
//  给定上下文与 LLM 多轮深入对话。
//
//  UI 关键点:
//  - 顶部 header 简要显示当前上下文来源(预测 / 错题 / 周报)
//  - 中部:滚动对话历史,user 右对齐,assistant 左对齐 + MarkdownView 流式
//  - 底部输入框:iOS 26 `glassEffect` 浮动胶囊(脱离键盘的悬浮玻璃感);
//    老版本 fallback 到 `.regularMaterial` 胶囊
//
//  Created for LLM BYOK integration (2026-07-11).
//

import SwiftUI
import Combine
import SwiftStreamingMarkdown

struct AIDiscussionSheet: View {
    /// 标题(显示在 navigation bar)
    let title: String
    /// 上下文(喂给 system prompt)
    let context: String
    /// 初始 assistant 消息(显示在对话历史开头;通常 = 上一步 AI 预测原文)
    let initialAssistantMessage: String?
    /// 退出回调
    let onDismiss: () -> Void

    @EnvironmentObject private var envManager: AppEnvironmentManager
    @StateObject private var viewModel = AIDiscussionViewModel()
    @State private var inputText: String = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                messagesList
                floatingInput
            }
            .background(Color(.systemGroupedBackground).opacity(0.001))
            .containerBackground(.clear, for: .navigation)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close".localized()) {
                        viewModel.cancel()
                        onDismiss()
                    }
                }
                if viewModel.isStreaming {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            viewModel.cancel()
                        } label: {
                            Image(systemName: "stop.circle.fill")
                        }
                    }
                } else {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            viewModel.reset()
                        } label: {
                            Image(systemName: "trash")
                        }
                        .disabled(viewModel.messages.isEmpty)
                    }
                }
            }
            .onAppear {
                viewModel.bootstrap(
                    context: context,
                    initialAssistantMessage: initialAssistantMessage
                )
            }
            .onDisappear { viewModel.cancel() }
        }
    }

    // MARK: - Messages List

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if viewModel.messages.isEmpty {
                    emptyState
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            discussionBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 16)
                    .padding(.bottom, 96) // 给浮动输入框留位
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.count) { _, _ in scrollToBottom(proxy: proxy) }
            .onChange(of: viewModel.messages.last?.content ?? "") { _, _ in scrollToBottom(proxy: proxy) }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            if !envManager.llmConfig.isConfigured {
                Image(systemName: "brain")
                    .font(.system(size: 56))
                    .foregroundColor(.secondary)
                Text("LLM Not Configured".localized())
                    .font(.headline)
                Text("Set Base URL, API Key and Model in Settings → LLM.".localized())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                NavigationLink(destination: LLMSettingsView()) {
                    Label("Open LLM Settings".localized(), systemImage: "gearshape")
                }
                .buttonStyle(.borderedProminent)
            } else {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 56))
                    .foregroundColor(.secondary)
                Text("Ask anything".localized())
                    .font(.headline)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let last = viewModel.messages.last else { return }
        withAnimation(.easeOut(duration: 0.15)) {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }

    // MARK: - Floating Input (iOS 26 Liquid Glass)

    /// 底部浮动输入框。视觉上"脱离"键盘悬浮,
    /// iOS 26 用 `Color.clear.glassEffect(.regular, in: Capsule())`;
    /// 老版本 fallback `.regularMaterial` 胶囊。
    private var floatingInput: some View {
        HStack(alignment: .bottom, spacing: 8) {
            inputCapsule
            sendButton
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var inputCapsule: some View {
        TextField("Ask anything...".localized(), text: $inputText, axis: .vertical)
            .lineLimit(1...5)
            .focused($inputFocused)
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
                        Color.primary.opacity(inputFocused ? 0.15 : 0.08),
                        lineWidth: inputFocused ? 1 : 0.5
                    )
            )
            .onSubmit { send() }
    }

    private var sendButton: some View {
        Button {
            send()
        } label: {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 32))
        }
        .disabled(
            inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || viewModel.isStreaming
                || !envManager.llmConfig.isConfigured
        )
    }

    private func send() {
        let text = inputText
        inputText = ""
        viewModel.sendUserMessage(text, config: envManager.llmConfig)
    }

    // MARK: - Bubble

    @ViewBuilder
    private func discussionBubble(message: AIDiscussionViewModel.Message) -> some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 40)
                Text(message.content)
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color.accentColor))
                    .frame(maxWidth: 280, alignment: .trailing)
                    .textSelection(.enabled)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "brain")
                            .font(.caption)
                            .foregroundColor(.teal)
                        Text("AI".localized())
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.teal)
                        if message.isInitialContext {
                            Text("·  " + "以下对话基于上一次的 AI 预测".localized())
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        if message.isStreaming {
                            ProgressView().scaleEffect(0.6).padding(.leading, 4)
                        }
                        Spacer()
                    }
                    if let err = message.error {
                        Text(err).font(.caption).foregroundColor(.red)
                    } else if message.content.isEmpty && message.isStreaming {
                        Text("Thinking...".localized())
                            .font(.body).foregroundColor(.secondary)
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
                        .fill(message.isInitialContext
                              ? Color(.tertiarySystemBackground)
                              : Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(
                            message.isInitialContext ? Color.secondary.opacity(0.25) : Color.clear,
                            lineWidth: 1
                        )
                )
                .opacity(message.isInitialContext ? 0.85 : 1.0)
                .frame(maxWidth: 300, alignment: .leading)
                Spacer(minLength: 40)
            }
        }
    }
}

// MARK: - View Model

@MainActor
final class AIDiscussionViewModel: ObservableObject {
    struct Message: Identifiable, Equatable {
        let id: UUID
        let role: LLMRole
        var content: String
        var isStreaming: Bool
        var error: String?
        /// 标记这条消息是不是"上一次的 AI 预测"(只用于 UI 显示,不会发给 LLM)
        var isInitialContext: Bool = false

        init(
            id: UUID = UUID(),
            role: LLMRole,
            content: String = "",
            isStreaming: Bool = false,
            error: String? = nil,
            isInitialContext: Bool = false
        ) {
            self.id = id
            self.role = role
            self.content = content
            self.isStreaming = isStreaming
            self.error = error
            self.isInitialContext = isInitialContext
        }
    }

    @Published var messages: [Message] = []
    @Published var isStreaming: Bool = false
    private var context: String = ""
    /// 上一次的 AI 预测原文(只用于拼装 system prompt;不会作为 conversation history 发送,
    /// 因为 `assistant` 角色没有前导 user 消息会让部分 LLM 困惑 / 遗忘)。
    private var previousAIPrediction: String? = nil
    private var currentTask: Task<Void, Never>? = nil

    /// 初始化对话:把"上一步的 AI 预测"作为初始 assistant 消息(只用于 UI 显示),
    /// 并把同一段内容存到 `previousAIPrediction`,后续每次发请求都会作为 system 上下文喂给 LLM。
    func bootstrap(context: String, initialAssistantMessage: String?) {
        guard messages.isEmpty else { return }
        self.context = context
        if let initial = initialAssistantMessage, !initial.isEmpty {
            previousAIPrediction = initial
            messages.append(
                Message(role: .assistant, content: initial, isStreaming: false, isInitialContext: true)
            )
        }
    }

    func reset() {
        currentTask?.cancel()
        currentTask = nil
        messages.removeAll()
        isStreaming = false
        // 注意:reset 会清掉 previousAIPrediction,确保清空后没有遗留上下文
        previousAIPrediction = nil
    }

    func cancel() {
        currentTask?.cancel()
    }

    func sendUserMessage(_ text: String, config: LLMConfig) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isStreaming, config.isConfigured else { return }

        // 1) user message
        messages.append(Message(role: .user, content: trimmed))

        // 2) assistant 占位
        let placeholder = Message(role: .assistant, content: "", isStreaming: true)
        messages.append(placeholder)

        // 3) 构造发给 LLM 的 history
        // 关键:不要把"上一次的 AI 预测"那条 initial assistant 消息放进 history
        // (assistant 没有前导 user 消息,会让 LLM 困惑 / 遗忘);
        // 它已经通过 system prompt 里的"你刚才已经给出的预测"段落显式喂给 LLM。
        let history: [LLMMessage] = messages
            .filter { $0.id != placeholder.id && !$0.isInitialContext }
            .map { LLMMessage(role: $0.role, content: $0.content) }
        let system = AIDiscussionLLM.defaultSystem(
            context: context,
            previousAIPrediction: previousAIPrediction
        )
        let prompt = LLMPrompt(system: system, messages: history)

        isStreaming = true
        currentTask = Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await LLMClient.shared.stream(prompt: prompt, config: config) { snapshot in
                    Task { @MainActor in
                        if let lastIdx = self.messages.lastIndex(where: { $0.role == .assistant && $0.isStreaming }) {
                            self.messages[lastIdx].content = snapshot
                        }
                    }
                }
                if let lastIdx = self.messages.lastIndex(where: { $0.role == .assistant && $0.isStreaming }) {
                    self.messages[lastIdx].isStreaming = false
                }
            } catch is CancellationError {
                if let lastIdx = self.messages.lastIndex(where: { $0.role == .assistant && $0.isStreaming }) {
                    if self.messages[lastIdx].content.isEmpty {
                        self.messages[lastIdx].content = "[Cancelled]".localized()
                    }
                    self.messages[lastIdx].isStreaming = false
                }
            } catch {
                if let lastIdx = self.messages.lastIndex(where: { $0.role == .assistant && $0.isStreaming }) {
                    let desc = (error as? LLMError)?.errorDescription ?? error.localizedDescription
                    self.messages[lastIdx].error = desc
                    self.messages[lastIdx].isStreaming = false
                    if self.messages[lastIdx].content.isEmpty {
                        self.messages[lastIdx].content = "**Error**: \(desc)"
                    }
                }
            }
            self.isStreaming = false
            self.currentTask = nil
        }
    }
}
