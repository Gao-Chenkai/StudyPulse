//
//  LLMResponseParser.swift
//  StudyPulse
//
//  把 OpenAI Chat Completions 响应(SSE 流 / 单次 JSON)解析为:
//  Parse OpenAI Chat Completions responses (SSE stream / single JSON) into:
//  - 非流式:`String` (assistant content)        / Non-streaming: `String` (assistant content)
//  - 流式:逐条 `delta`(只取 `choices[0].delta.content`)
//          / Streaming: per-chunk `delta` (only `choices[0].delta.content`)
//
//  Created for LLM BYOK integration (2026-07-11).
//

import Foundation

// MARK: - Response Body (OpenAI Chat Completions JSON Schema)

/// OpenAI Chat Completions 响应体的最小子集。
/// Minimal subset of the OpenAI Chat Completions response body.
/// 不依赖外部 SDK,直接用 `JSONDecoder` 解。
/// Does not depend on any external SDK; decodes with `JSONDecoder` directly.
nonisolated struct LLMChatResponse: Decodable, Sendable {
    struct Choice: Decodable, Sendable {
        let index: Int?
        /// 非流式响应会带 `message`;流式响应带 `delta`。
        /// Non-streaming responses carry `message`; streaming responses carry `delta`.
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
        /// Incremental content; the first chunk may be nil / "" (contains only `role`).
        let content: String?
    }

    let id: String?
    let model: String?
    let choices: [Choice]
}

// MARK: - Non-streaming parser (非流式: 一次性 JSON)

extension LLMChatResponse {
    /// 提取 assistant 最终 content / Extract the assistant's final `content`.
    /// 找不到时抛 `LLMError.malformedResponse` / Throws `LLMError.malformedResponse` if missing.
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
        // trim 只是为了判空;返回原 content 保留原始空白(可能含 Markdown 缩进)
        // trim is only used to detect emptiness; return raw content to preserve Markdown indentation
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { throw LLMError.emptyResponse }
        return content
    }
}

// MARK: - Streaming parser (流式: SSE)

/// 逐行解析 SSE(`data: {...}`)。
/// Parse SSE line-by-line (`data: {...}`).
/// 把 `data: ` 前缀剥掉,过滤空行/注释,遇到 `[DONE]` 终止。
/// Strips the `data: ` prefix, filters empty/comment lines, terminates on `[DONE]`.
enum LLMStreamingParser {
    /// 单行 SSE 是否是终止标记。
    /// Is a single SSE line the terminator?
    /// `[DONE]` 终止;其他非 `data:` 开头行(空行 / `:heartbeat`)忽略。
    /// `[DONE]` terminates; other non-`data:` lines (empty / `:heartbeat`) are ignored.
    static func isDoneLine(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespacesAndNewlines) == "data: [DONE]"
    }

    /// 把单行 SSE 解析为增量 content,无法解析返回 nil(调用方继续读取)。
    /// Parse one SSE line to its delta content; returns nil on failure (caller keeps reading).
    static func parseLine(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("data:") else { return nil }
        let payload = trimmed.dropFirst("data:".count).trimmingCharacters(in: .whitespacesAndNewlines)
        // 空 payload 或 [DONE] 都视为终止信号,返回 nil 让外层退出
        // Empty payload or [DONE] both signal end → return nil to let caller exit
        if payload.isEmpty || payload == "[DONE]" { return nil }
        guard let data = payload.data(using: .utf8) else { return nil }
        guard let resp = try? JSONDecoder().decode(LLMChatResponse.self, from: data) else {
            return nil
        }
        return resp.choices.first?.delta?.content
    }
}
