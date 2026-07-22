//
//  LLMChatViewModel.swift
//  StudyPulse
//
//  AI 助手对话页 ViewModel。管理多轮消息 / 当前流式任务 / 取消逻辑。
//  状态仅 in-memory(本次迭代不持久化)。
//  AI-assistant chat-page VM. Manages multi-turn messages, the streaming
//  task, and the cancel flow. State is in-memory only (not persisted).
//
//  Created for LLM BYOK integration (2026-07-11).
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class LLMChatViewModel: ObservableObject {
    /// 单条消息(区分 loading / finished) / Single message.
    struct Message: Identifiable, Equatable {
        let id: UUID
        let role: LLMRole
        /// 已渲染内容(流式时逐字累积) / Already-rendered content.
        var content: String
        /// 是否正在流式接收(仅 assistant) / Currently streaming?
        var isStreaming: Bool
        /// 流式错误信息 / Streaming error.
        var error: String?
        var attachments: [LLMImageAttachment]

        init(
            id: UUID = UUID(),
            role: LLMRole,
            content: String = "",
            isStreaming: Bool = false,
            error: String? = nil,
            attachments: [LLMImageAttachment] = []
        ) {
            self.id = id
            self.role = role
            self.content = content
            self.isStreaming = isStreaming
            self.error = error
            self.attachments = attachments
        }
    }

    /// 对话历史 / Conversation history.
    @Published var messages: [Message] = []
    /// 是否正在等待响应 / Awaiting response?
    @Published var isStreaming: Bool = false
    /// 当前 LLM 任务(可取消) / Current LLM task (cancellable).
    private var currentTask: Task<Void, Never>? = nil

    /// 清空对话 / Clear the conversation.
    func reset() {
        currentTask?.cancel()
        currentTask = nil
        messages.removeAll()
        isStreaming = false
    }

    /// 发送用户消息 → 触发 LLM 流式响应 → 追加 assistant 回复
    /// Send a user message, kick off streaming, append assistant reply.
    func sendUserMessage(_ text: String, attachments: [LLMImageAttachment] = [], config: LLMConfig, envManager: AppEnvironmentManager) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // 三道闸:非空、当前空闲、LLM 已配置
        // Three guards: non-empty, not streaming, LLM configured.
        guard (!trimmed.isEmpty || !attachments.isEmpty), !isStreaming, config.isConfigured else { return }

        // 1) 追加 user message
        let userMessage = Message(role: .user, content: trimmed, attachments: attachments)
        messages.append(userMessage)

        // 2) 准备空 assistant message 占位
        let assistantMessage = Message(role: .assistant, content: "", isStreaming: true)
        messages.append(assistantMessage)

        // 3) 构造历史 messages 给 LLM
        // 占位消息不参与历史(它还没有真实内容)
        // Placeholder excluded from history (no real content yet).
        let history = messages
            .filter { $0.id != assistantMessage.id }
            .map { LLMMessage(role: $0.role, content: $0.content, imageDataURLs: $0.attachments.map(\.dataURL)) }
        let prompt = LLMPrompt(system: LLMChatLLM.defaultSystem, messages: history)

        isStreaming = true
        currentTask = Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await LLMClient.shared.stream(
                    prompt: prompt,
                    config: config,
                    caller: "LLMChat"
                ) { snapshot in
                    Task { @MainActor in
                        // 找到最新的 assistant 消息并更新 content
                        // Find the latest streaming assistant message and
                        // overwrite its content.
                        if let lastIdx = self.messages.lastIndex(where: { $0.role == .assistant && $0.isStreaming }) {
                            self.messages[lastIdx].content = snapshot
                        }
                    }
                }
                if let lastIdx = self.messages.lastIndex(where: { $0.role == .assistant && $0.isStreaming }) {
                    self.messages[lastIdx].isStreaming = false
                }
            } catch is CancellationError {
                // 用户主动取消 → 标记占位为取消
                // User-initiated cancel → mark placeholder as cancelled.
                if let lastIdx = self.messages.lastIndex(where: { $0.role == .assistant && $0.isStreaming }) {
                    if self.messages[lastIdx].content.isEmpty {
                        // 内容为空 → 填占位文案 / Fill placeholder when empty.
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
                        // 内容为空 → 渲染粗体错误 / Bold error when empty.
                        self.messages[lastIdx].content = "**Error**: \(desc)"
                    }
                }
            }
            self.isStreaming = false
            self.currentTask = nil
        }
    }

    /// 取消当前流 / Cancel the in-flight stream.
    func cancel() {
        currentTask?.cancel()
    }
}
