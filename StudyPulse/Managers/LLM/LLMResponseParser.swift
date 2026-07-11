//
//  LLMResponseParser.swift
//  StudyPulse
//
//  把 OpenAI Chat Completions 响应(SSE 流 / 单次 JSON)解析为:
//  - 非流式:`String` (assistant content)
//  - 流式:逐条 `delta`(只取 `choices[0].delta.content`)
//
//  Created for LLM BYOK integration (2026-07-11).
//

import Foundation

// MARK: - Response Body (OpenAI Chat Completions JSON Schema)

/// OpenAI Chat Completions 响应体的最小子集。
/// 不依赖外部 SDK,直接用 `JSONDecoder` 解。
nonisolated struct LLMChatResponse: Decodable, Sendable {
    struct Choice: Decodable, Sendable {
        let index: Int?
        /// 非流式响应会带 `message`;流式响应带 `delta`。
        let message: Message?
        let delta: Delta?
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case index
            case message
            case delta
            case finishReason = "finish_reason"
        }
    }

    struct Message: Decodable, Sendable {
        let role: String?
        let content: String?
    }

    struct Delta: Decodable, Sendable {
        let role: String?
        /// 增量内容;首块可能为 nil / ""(仅含 `role`)。
        let content: String?
    }

    let id: String?
    let model: String?
    let choices: [Choice]
}

// MARK: - Non-streaming parser (非流式: 一次性 JSON)

extension LLMChatResponse {
    /// 提取 assistant 最终 content。
    /// 找不到时抛 `LLMError.malformedResponse`。
    static func parseSingleResponse(_ data: Data) throws -> String {
        let resp: LLMChatResponse
        do {
            resp = try JSONDecoder().decode(LLMChatResponse.self, from: data)
        } catch {
            throw LLMError.malformedResponse
        }
        guard let content = resp.choices.first?.message?.content else {
            throw LLMError.emptyResponse
        }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { throw LLMError.emptyResponse }
        return content
    }
}

// MARK: - Streaming parser (流式: SSE)

/// 逐行解析 SSE(`data: {...}`)。
/// 把 `data: ` 前缀剥掉,过滤空行/注释,遇到 `[DONE]` 终止。
enum LLMStreamingParser {
    /// 单行 SSE 是否是终止标记。
    /// `[DONE]` 终止;其他非 `data:` 开头行(空行 / `:heartbeat`)忽略。
    static func isDoneLine(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespacesAndNewlines) == "data: [DONE]"
    }

    /// 把单行 SSE 解析为增量 content,无法解析返回 nil(调用方继续读取)。
    static func parseLine(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("data:") else { return nil }
        let payload = trimmed.dropFirst("data:".count).trimmingCharacters(in: .whitespacesAndNewlines)
        if payload.isEmpty || payload == "[DONE]" { return nil }
        guard let data = payload.data(using: .utf8) else { return nil }
        guard let resp = try? JSONDecoder().decode(LLMChatResponse.self, from: data) else {
            return nil
        }
        return resp.choices.first?.delta?.content
    }
}
