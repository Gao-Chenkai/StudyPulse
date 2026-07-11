//
//  LLMChatViewModel.swift
//  StudyPulse
//
//  AI 助手对话页 ViewModel。管理多轮消息 / 当前流式任务 / 取消逻辑。
//  状态仅 in-memory(本次迭代不持久化),离开页面或显式清空时释放。
//
//  Created for LLM BYOK integration (2026-07-11).
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class LLMChatViewModel: ObservableObject {
    /// 单条消息(可在 UI 流式渲染中区分 loading / finished)
    struct Message: Identifiable, Equatable {
        let id: UUID
        let role: LLMRole
        /// 已渲染内容。assistant 消息在流式过程中逐字累积
        var content: String
        /// 是否正在流式接收(仅 assistant 有意义)
        var isStreaming: Bool
        /// 流式错误信息(整条消息失败时显示)
        var error: String?

        init(
            id: UUID = UUID(),
            role: LLMRole,
            content: String = "",
            isStreaming: Bool = false,
            error: String? = nil
        ) {
            self.id = id
            self.role = role
            self.content = content
            self.isStreaming = isStreaming
            self.error = error
        }
    }

    /// 对话历史(UI 渲染时按时间顺序展示)
    @Published var messages: [Message] = []

    /// 是否正在等待响应
    @Published var isStreaming: Bool = false

    /// 当前 LLM 任务(允许手动取消)
    private var currentTask: Task<Void, Never>? = nil

    /// 清空对话
    func reset() {
        currentTask?.cancel()
        currentTask = nil
        messages.removeAll()
        isStreaming = false
    }

    /// 发送用户消息 → 触发 LLM 流式响应 → 把 assistant 回复追加到 messages
    func sendUserMessage(_ text: String, config: LLMConfig, envManager: AppEnvironmentManager) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isStreaming, config.isConfigured else { return }

        // 1) 追加 user message
        let userMessage = Message(role: .user, content: trimmed)
        messages.append(userMessage)

        // 2) 准备空 assistant message 占位
        let assistantMessage = Message(role: .assistant, content: "", isStreaming: true)
        messages.append(assistantMessage)

        // 3) 构造历史 messages 给 LLM
        let history = messages
            .filter { $0.id != assistantMessage.id } // 占位消息不参与历史
            .map { LLMMessage(role: $0.role, content: $0.content) }
        let prompt = LLMPrompt(system: LLMChatLLM.defaultSystem, messages: history)

        isStreaming = true
        currentTask = Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await LLMClient.shared.stream(
                    prompt: prompt,
                    config: config
                ) { snapshot in
                    Task { @MainActor in
                        // 找到最新的 assistant 消息并更新 content
                        if let lastIdx = self.messages.lastIndex(where: { $0.role == .assistant && $0.isStreaming }) {
                            self.messages[lastIdx].content = snapshot
                        }
                    }
                }
                if let lastIdx = self.messages.lastIndex(where: { $0.role == .assistant && $0.isStreaming }) {
                    self.messages[lastIdx].isStreaming = false
                }
            } catch is CancellationError {
                // 用户主动取消 → 把占位 assistant 消息标记为取消
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

    /// 取消当前流
    func cancel() {
        currentTask?.cancel()
    }
}
