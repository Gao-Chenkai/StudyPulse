//
//  LLMConfig.swift
//  StudyPulse
//
//  LLM BYOK 配置:从 `AppPreferences` 读出 / 写回的桥接层。
//  单一 immutable value type,便于测试与跨线程传递。
//
//  Created for LLM BYOK integration (2026-07-11).
//

import Foundation

// MARK: - LLM Config (LLM 配置)

/// 用户在 `LLMSettingsView` 中配置的 LLM 参数。
/// `enabled == false` 时所有 LLM 调用都应回退到本地实现。
nonisolated struct LLMConfig: Sendable, Equatable {
    /// 总开关;关闭时所有 AI 功能回退到本地版本。
    var enabled: Bool
    /// Chat Completions 风格 base URL,例如 https://api.openai.com
    /// (URL 末尾的 `/` 会在 `LLMClient` 内部自动 trim)
    var baseURL: String?
    /// 用户自备的 API Key。仅在设备本地 UserDefaults 存储。
    var apiKey: String?
    /// 模型 id,例如 gpt-4o-mini / deepseek-chat
    var model: String?
    /// 自定义系统 prompt 追加(在默认 prompt 之后)
    var systemPromptAppendix: String?
    /// 采样温度 (0.0-2.0)
    var temperature: Double
    /// Debug 专用:完整覆盖 system prompt(非空时,会**完全替换**默认 system + appendix)。
    /// DEBUG-only override: when set, replaces the default system prompt + appendix entirely.
    var overrideSystemPrompt: String?

    /// 是否已配置完整(baseURL / apiKey / model 都非空)。
    /// `LLMClient.complete/stream` 入口处统一检查;
    /// `false` 时抛 `LLMError.notConfigured`,调用方按需回退。
    var isConfigured: Bool {
        enabled
            && !(baseURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            && !(apiKey?.isEmpty ?? true)
            && !(model?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }
}

extension LLMConfig {
    /// 默认配置(全部关闭 / 空)。用于首次启动 / 测试 fallback。
    static let empty = LLMConfig(
        enabled: false,
        baseURL: nil,
        apiKey: nil,
        model: nil,
        systemPromptAppendix: nil,
        temperature: 0.7
    )
}

// MARK: - AppPreferences 桥接

import os

extension LLMConfig {
    /// 从 `AppPreferences` 当前值构造一份 `LLMConfig`。
    /// 这是只读快照;修改配置请走 `AppEnvironmentManager` 提供的 setter。
    @MainActor
    static func from(_ prefs: AppPreferences) -> LLMConfig {
        LLMConfig(
            enabled: prefs.llmEnabled,
            baseURL: prefs.llmBaseURL,
            apiKey: prefs.llmAPIKey,
            model: prefs.llmModel,
            systemPromptAppendix: prefs.llmSystemPromptAppendix,
            temperature: prefs.llmTemperature,
            overrideSystemPrompt: prefs.debugOverrideSystemPrompt
        )
    }
}
