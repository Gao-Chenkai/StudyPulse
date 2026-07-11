//
//  LLMClient.swift
//  StudyPulse
//
//  LLM BYOK 客户端。实现 OpenAI Chat Completions 协议:
//  - `complete(...)` 单次非流式
//  - `stream(...)`   SSE 流式,逐 delta 调 onDelta
//  - `testConnection(...)` LLMSettingsView 用,极小请求确认可达
//
//  单例 `@MainActor class: ObservableObject`,与项目其他 Manager
//  (HealthKitManager / PlantManager) 风格保持一致。
//
//  Created for LLM BYOK integration (2026-07-11).
//

import Foundation
import os
import Combine

// MARK: - LLM Client

/// OpenAI Chat Completions 兼容客户端。
/// - `stream(...)` 中 `onDelta` 接收**到目前为止的完整文本**(不是增量),
///   方便 UI 端直接存进 `AsyncStream` 给 `StreamedMarkdownView`。
@MainActor
final class LLMClient: ObservableObject {
    static let shared = LLMClient()

    /// 整体请求超时(秒);`stream` 与 `complete` 通用。
    private let timeoutSeconds: TimeInterval = 60

    private let session: URLSession

    private init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            // 显式声明超时;默认 60s 已经够用,且能被 `stream` 的 task 取消覆盖
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 60
            config.timeoutIntervalForResource = 120
            self.session = URLSession(configuration: config)
        }
    }

    // MARK: - Public API

    /// 单次非流式调用,返回最终 content。
    /// 失败抛 `LLMError`;调用方按需回退到本地。
    func complete(prompt: LLMPrompt, config: LLMConfig) async throws -> String {
        try validateConfig(config)
        let url = try buildURL(baseURL: config.baseURL)
        let body = try buildBody(prompt: prompt, config: config, stream: false)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey ?? "")", forHTTPHeaderField: "Authorization")
        request.httpBody = body
        Log.llm.info("LLM complete → \(url.absoluteString, privacy: .public) model=\(config.model ?? "?", privacy: .public)")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw LLMError.timeout
        } catch {
            throw LLMError.network(error.localizedDescription)
        }
        try validateHTTP(response: response, data: data)
        return try LLMChatResponse.parseSingleResponse(data)
    }

    /// SSE 流式调用,逐 delta 调 `onDelta`。
    /// 返回**完整文本**;`onDelta` 每次接收到目前为止的全部内容。
    /// 失败抛 `LLMError`。
    func stream(
        prompt: LLMPrompt,
        config: LLMConfig,
        onDelta: @MainActor (String) -> Void
    ) async throws -> String {
        try validateConfig(config)
        let url = try buildURL(baseURL: config.baseURL)
        let body = try buildBody(prompt: prompt, config: config, stream: true)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(config.apiKey ?? "")", forHTTPHeaderField: "Authorization")
        request.httpBody = body
        request.timeoutInterval = timeoutSeconds
        Log.llm.info("LLM stream → \(url.absoluteString, privacy: .public) model=\(config.model ?? "?", privacy: .public)")

        let (bytes, response) = try await session.bytes(for: request)
        // 如果状态非 2xx,先把整个 body 收集起来再抛(serverError 才会带 body)
        // If status is not 2xx, drain the whole body before throwing so the error carries it.
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            var buffer = Data()
            for try await byte in bytes {
                buffer.append(byte)
            }
            try validateHTTP(response: response, data: buffer)
        }
        try validateHTTP(response: response, data: Data())

        var accumulated = ""
        var pending = ""
        for try await line in bytes.lines {
            if Task.isCancelled { throw LLMError.network("Cancelled") }
            if LLMStreamingParser.isDoneLine(line) { break }
            // SSE 事件由空行分隔;单行处理
            pending = line
            if let piece = LLMStreamingParser.parseLine(pending) {
                accumulated += piece
                let snapshot = accumulated
                onDelta(snapshot)
            }
        }
        if accumulated.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw LLMError.emptyResponse
        }
        return accumulated
    }

    /// 测试连接。发一条极小请求确认 baseURL/apiKey/model 可用。
    /// 成功返回;失败抛 `LLMError`。
    func testConnection(config: LLMConfig) async throws {
        let prompt = LLMPrompt(
            system: "You are a connectivity check endpoint.",
            messages: [.user("ping")]
        )
        _ = try await complete(prompt: prompt, config: config)
    }

    // MARK: - Helpers

    private func validateConfig(_ config: LLMConfig) throws {
        guard config.enabled else { throw LLMError.notConfigured }
        guard !(config.apiKey?.isEmpty ?? true) else { throw LLMError.notConfigured }
        guard let baseURL = config.baseURL, !baseURL.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw LLMError.notConfigured
        }
        guard let model = config.model, !model.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw LLMError.notConfigured
        }
        // 静默引用 model 避免 unused-warning(Linter 友好)
        _ = model
    }

    private func buildURL(baseURL: String?) throws -> URL {
        guard let raw = baseURL else { throw LLMError.invalidURL }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
        guard let base = URL(string: cleaned) else { throw LLMError.invalidURL }
        return base.appendingPathComponent("/v1/chat/completions")
    }

    private func buildBody(prompt: LLMPrompt, config: LLMConfig, stream: Bool) throws -> Data {
        // 手搓 JSON 避免引入外部 SDK
        let effective = prompt.effectiveSystem(appendix: config.systemPromptAppendix)
        let allMessages = [LLMMessage.system(effective)] + prompt.messages
        let payload: [String: Any] = [
            "model": config.model ?? "",
            "temperature": max(0, min(2, config.temperature)),
            "stream": stream,
            "messages": allMessages.map { ["role": $0.role.rawValue, "content": $0.content] }
        ]
        return try JSONSerialization.data(withJSONObject: payload, options: [])
    }

    private func validateHTTP(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw LLMError.network("Non-HTTP response")
        }
        switch http.statusCode {
        case 200..<300: return
        case 401: throw LLMError.unauthorized
        case 429: throw LLMError.rateLimited
        default:
            // 把响应体一并抛出,UI 才能看到 "Model not found" / "Invalid API key" 之类
            // Include the response body so the UI can show the server's real error message.
            let body = String(data: data, encoding: .utf8)
            throw LLMError.serverError(statusCode: http.statusCode, body: body)
        }
    }
}

// MARK: - Log Category

extension Log {
    /// LLM BYOK 请求/响应/错误日志;不打印 API Key 明文。
    /// LLM BYOK request/response/error logs; never logs the raw API key.
    nonisolated static let llm = Logger(subsystem: subsystem, category: "LLM")
}
