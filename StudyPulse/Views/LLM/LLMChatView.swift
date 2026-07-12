//
//  LLMChatView.swift
//  StudyPulse
//
//  AI 助手对话页:多轮对话 + Markdown 流式渲染。
//  对话历史仅 in-memory,离开页面或按 toolbar 的"清空"按钮释放。
//
//  UI 统一(2026-07-11):使用共享 ChatBubble + ChatInputBar,
//  跟 AIDiscussionSheet / HomeAskSheet 保持一致的输入框样式和气泡外观。
//
//  Created for LLM BYOK integration (2026-07-11).
//

import SwiftUI
import SwiftStreamingMarkdown

struct LLMChatView: View {
    @EnvironmentObject private var envManager: AppEnvironmentManager
    @StateObject private var viewModel = LLMChatViewModel()
    @State private var inputText: String = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            messagesList
            ChatInputBar(
                text: $inputText,
                isStreaming: viewModel.isStreaming,
                canSend: canSend,
                onSend: send,
                onCancel: { viewModel.cancel() }
            )
        }
        .background(Color(.systemGroupedBackground).opacity(0.4))
        .containerBackground(.clear, for: .navigation)
        .debugModeContainer()
        .debugLayoutBoundsAuto()
        .llmDebugButton(caller: "LLMChat")
        .navigationTitle("AI Assistant".localized())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.isStreaming {
                    Button {
                        viewModel.cancel()
                    } label: {
                        Image(systemName: "stop.circle.fill")
                    }
                } else {
                    Button {
                        viewModel.reset()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(viewModel.messages.isEmpty)
                }
            }
        }
    }

    private var canSend: Bool {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !viewModel.isStreaming && envManager.llmConfig.isConfigured
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
                            ChatBubble(
                                role: message.role == .user ? .user : .assistant(dimmed: false),
                                content: message.content,
                                isStreaming: message.isStreaming,
                                error: message.error
                            )
                            .id(message.id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                    // 驱动 bubble 进出场的 transition
                    .animation(.spring(response: 0.35, dampingFraction: 0.78), value: viewModel.messages.count)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.messages.last?.content ?? "") { _, _ in
                scrollToBottom(proxy: proxy)
            }
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
                Text("Start a conversation".localized())
                    .font(.headline)
                Text("Ask about your grades, mistakes, or exams.".localized())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let last = viewModel.messages.last else { return }
        withAnimation(.easeOut(duration: 0.15)) {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }

    private func send() {
        let text = inputText
        inputText = ""
        viewModel.sendUserMessage(text, config: envManager.llmConfig, envManager: envManager)
    }
}
