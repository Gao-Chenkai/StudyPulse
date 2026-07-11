//
//  LLMPrompt.swift
//  StudyPulse
//
//  LLM 提示载荷类型:
//  - `LLMMessage` / `LLMRole`  — OpenAI Chat Completions 消息结构
//  - `LLMPrompt`               — 一次完整请求的 system + messages
//
//  Created for LLM BYOK integration (2026-07-11).
//

import Foundation

// MARK: - LLM Message Role (消息角色)

/// OpenAI Chat Completions 消息角色。模型只有 4 种取值。
nonisolated enum LLMRole: String, Codable, Sendable {
    case system
    case user
    case assistant
    case tool
}

// MARK: - LLM Message (单条消息)

/// 单条消息。`content` 留空时序列化为 `""`。
nonisolated struct LLMMessage: Codable, Sendable, Equatable {
    var role: LLMRole
    var content: String

    init(role: LLMRole, content: String) {
        self.role = role
        self.content = content
    }

    static func system(_ content: String) -> LLMMessage {
        LLMMessage(role: .system, content: content)
    }
    static func user(_ content: String) -> LLMMessage {
        LLMMessage(role: .user, content: content)
    }
    static func assistant(_ content: String) -> LLMMessage {
        LLMMessage(role: .assistant, content: content)
    }
}

// MARK: - LLM Prompt (单次请求载荷)

/// 一次完整请求。
/// `messages` 至少含 1 条 system;调用方在 `LLMRequestBuilder` 中按场景构造。
nonisolated struct LLMPrompt: Sendable {
    /// 系统 prompt(会与 `LLMConfig.systemPromptAppendix` 拼接)
    let system: String
    /// 多轮对话或单条 user 消息
    let messages: [LLMMessage]

    init(system: String, messages: [LLMMessage]) {
        self.system = system
        self.messages = messages
    }

    /// 拼接 `system + appendix`(若 appendix 非空)。
    /// 在 `LLMClient` 内部调用,不让业务侧操心。
    func effectiveSystem(appendix: String?) -> String {
        guard let appendix, !appendix.isEmpty else { return system }
        return system + "\n\n" + appendix
    }
}
