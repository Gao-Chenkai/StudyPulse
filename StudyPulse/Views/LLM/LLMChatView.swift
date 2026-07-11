//
//  LLMChatView.swift
//  StudyPulse
//
//  AI 助手对话页:多轮对话 + Markdown 流式渲染。
//  对话历史仅 in-memory,离开页面或按 toolbar 的"清空"按钮释放。
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
        VStack(spacing: 0) {
            messagesList
            inputBar
        }
        .navigationTitle("AI Assistant".localized())
        .navigationBarTitleDisplayMode(.inline)
        .containerBackground(.clear, for: .navigation)
        .debugModeContainer()
        .debugLayoutBoundsAuto()
        .toolbar {
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
                            LLMMessageBubbleView(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 16)
                }
            }
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

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Ask anything...".localized(), text: $inputText, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($inputFocused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .onSubmit { send() }

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
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemBackground).opacity(0.001)) // 让 iOS 26 透明生效
        }
    }

    private func send() {
        let text = inputText
        inputText = ""
        viewModel.sendUserMessage(text, config: envManager.llmConfig, envManager: envManager)
    }
}
