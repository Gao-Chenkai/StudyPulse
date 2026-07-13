//
//  LLMError.swift
//  StudyPulse
//
//  LLM 客户端错误类型。所有调用方(学习建议 / 错题解析 / 周报总结 / AI 助手)
//  应当捕获 `LLMError` 并按需求决定是否回退到本地实现。
//
//  Created for LLM BYOK integration (2026-07-11).
//

import Foundation

// MARK: - LLM Error (LLM 错误类型)
// MARK: - LLM Error

/// LLM 调用过程中可能抛出的错误。
/// 用于上层做"AI 失败 → 回退到本地"的统一入口。
/// Errors that may be thrown by an LLM call. Callers catch this type
/// to implement the "AI failed → fall back to local" pattern.
enum LLMError: Error, LocalizedError, Equatable {
    /// 用户未在 `LLMSettingsView` 配置 baseURL / APIKey / model
    case notConfigured
    /// baseURL 解析失败
    case invalidURL
    /// HTTP 401: API Key 无效 / 鉴权失败
    case unauthorized
    /// HTTP 429: 速率限制
    case rateLimited
    /// HTTP 4xx(非 401/429)/ 5xx。`body` 是服务端返回的 JSON 文本(若有),用于诊断
    case serverError(statusCode: Int, body: String?)
    /// 网络层错误(URLError / 解码 / 取消 等)
    case network(String)
    /// 响应 JSON 解析失败(数据格式与 OpenAI 协议不符)
    case malformedResponse
    /// 服务端返回了空内容(content 字段为 null/空)
    case emptyResponse
    /// 整个请求超时
    case timeout

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "LLM not configured. Set Base URL, API Key and Model in Settings → LLM.".localized()
        case .invalidURL:
            return "Invalid Base URL.".localized()
        case .unauthorized:
            return "Authentication failed. Check your API Key.".localized()
        case .rateLimited:
            return "Rate limited. Please try again later.".localized()
        case .serverError(let code, let body):
            // 把服务端返回的真实错误信息拼到提示里(若有)
            // Append the server's actual error body to the message, if any.
            let trimmed = body?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let trimmed, !trimmed.isEmpty {
                return String(format: "Server error (HTTP %d): %@".localized(), code, trimmed)
            }
            return String(format: "Server error (HTTP %d).".localized(), code)
        case .network(let msg):
            return String(format: "Network error: %@".localized(), msg)
        case .malformedResponse:
            return "Failed to parse LLM response.".localized()
        case .emptyResponse:
            return "LLM returned empty content.".localized()
        case .timeout:
            return "LLM request timed out.".localized()
        }
    }
}
