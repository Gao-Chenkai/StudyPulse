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

/// 单次 LLM 调用的调试信息(DEBUG 面板用)。包含 URL / prompt / 思考时长 / 响应。
/// Debug info for a single LLM call. Populated by LLMClient.complete / stream.
nonisolated struct LLMCallDebugInfo: Equatable, Sendable {
    /// 调用起始时间
    let startTime: Date
    /// 调用结束时间
    let endTime: Date
    /// 思考/总耗时(秒)
    var elapsedSeconds: TimeInterval { endTime.timeIntervalSince(startTime) }
    /// 端点 URL(完整,含 /v1/chat/completions)
    let url: String
    /// 模型 id
    let model: String
    /// 采样温度
    let temperature: Double
    /// system prompt(完整,含 override / appendix)
    let systemPrompt: String
    /// 消息历史
    let messages: [LLMMessage]
    /// 是否使用 stream
    let streaming: Bool
    /// 响应内容(成功时)
    var response: String?
    /// 错误描述(失败时)
    var error: String?
    /// 调用场景标签(可选,便于多 AI 功能区分),由调用方通过 `caller` 字段填充
    let caller: String

    /// 渲染为可复制的 JSON 字符串(给 LLMDebugSheet 用)
    func asDebugJSON() -> String {
        let allMessages = [LLMMessage.system(systemPrompt)] + messages
        let msgArr = allMessages.map { msg in
            "{\"role\":\"\(msg.role.rawValue)\",\"content\":\(escapeJSON(msg.content))}"
        }.joined(separator: ",")
        return """
        {
          "caller": \(escapeJSON(caller)),
          "url": \(escapeJSON(url)),
          "model": \(escapeJSON(model)),
          "temperature": \(temperature),
          "streaming": \(streaming),
          "elapsedSeconds": \(String(format: "%.3f", elapsedSeconds)),
          "systemPrompt": \(escapeJSON(systemPrompt)),
          "messages": [\(msgArr)],
          "response": \(response.map(escapeJSON) ?? "null"),
          "error": \(error.map(escapeJSON) ?? "null")
        }
        """
    }

    private func escapeJSON(_ s: String) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: [s], options: [])) ?? Data()
        let arr = String(data: data, encoding: .utf8) ?? "[\"\"]"
        // 取首尾的引号(数组形式 = ["..."])
        return String(arr.dropFirst().dropLast())
    }
}

/// OpenAI Chat Completions 兼容客户端。
/// - `stream(...)` 中 `onDelta` 接收**到目前为止的完整文本**(不是增量),
///   方便 UI 端直接存进 `AsyncStream` 给 `StreamedMarkdownView`。
@MainActor
final class LLMClient: ObservableObject, @unchecked Sendable {
    // `@unchecked Sendable`:nonisolated 方法(buildBody/effectiveSystem/buildURL)不访问可变状态,
    // 仅 @Published 属性(lastCallInfo/recentCalls)需要 MainActor,它们仍在 MainActor 方法中访问。
    // `@unchecked Sendable`: nonisolated methods (buildBody/effectiveSystem/buildURL) access no
    // mutable state; only the @Published properties (lastCallInfo/recentCalls) require MainActor,
    // and they are still touched only from MainActor methods (recordCall).
    static let shared = LLMClient()

    /// 整体请求超时(秒);`stream` 与 `complete` 通用。
    private let timeoutSeconds: TimeInterval = 60

    private let session: URLSession   // 网络会话(可注入以做单测)

    /// 最近一次调用的调试信息(给 LLMDebugSheet 显示)。每次 complete / stream 都会更新。
    /// Most-recent call's debug info. Updated on every complete / stream.
    @Published private(set) var lastCallInfo: LLMCallDebugInfo? = nil
    /// 最近的若干条调用历史(最多保留 20 条,新调用 push 到末尾)。
    /// Recent call history (newest last, capped at 20).
    @Published private(set) var recentCalls: [LLMCallDebugInfo] = []
    private let recentCallsLimit = 20  // 防止 LLM Debug 面板无限增长

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
    /// - Parameter caller: 调用场景标签(例如 "MistakeAI" / "WeeklyReport");写入 debug info。
    func complete(
        prompt: LLMPrompt,
        config: LLMConfig,
        caller: String = "complete"
    ) async throws -> String {
        try validateConfig(config)
        // 缓存命中:直接返回(避免重复走网络)。
        // Cache hit: return immediately (avoids the network round-trip).
        if let cached = LLMResponseCache.shared.get(caller: caller, prompt: prompt, config: config) {
            return cached
        }
        printPromptToConsole(prompt: prompt, config: config, caller: caller)
        let url = try buildURL(baseURL: config.baseURL)
        // JSON 编解码移到 detached Task,避免阻塞主线程
        // Move JSON encoding off the main actor to keep UI responsive.
        let body = try await Task.detached(priority: .userInitiated) {
            try self.buildBody(prompt: prompt, config: config, stream: false)
        }.value
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey ?? "")", forHTTPHeaderField: "Authorization")
        request.httpBody = body
        Log.llm.info("LLM complete → \(url.absoluteString, privacy: .public) model=\(config.model ?? "?", privacy: .public)")

        let startTime = Date()
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            let info = LLMCallDebugInfo(
                startTime: startTime, endTime: Date(),
                url: url.absoluteString, model: config.model ?? "?",
                temperature: config.temperature,
                systemPrompt: effectiveSystem(prompt: prompt, config: config),
                messages: prompt.messages, streaming: false,
                response: nil, error: LLMError.timeout.errorDescription,
                caller: caller
            )
            recordCall(info)
            throw LLMError.timeout
        } catch {
            let info = LLMCallDebugInfo(
                startTime: startTime, endTime: Date(),
                url: url.absoluteString, model: config.model ?? "?",
                temperature: config.temperature,
                systemPrompt: effectiveSystem(prompt: prompt, config: config),
                messages: prompt.messages, streaming: false,
                response: nil, error: error.localizedDescription,
                caller: caller
            )
            recordCall(info)
            throw LLMError.network(error.localizedDescription)
        }
        do {
            try validateHTTP(response: response, data: data)
        } catch {
            let desc = (error as? LLMError)?.errorDescription ?? error.localizedDescription
            let info = LLMCallDebugInfo(
                startTime: startTime, endTime: Date(),
                url: url.absoluteString, model: config.model ?? "?",
                temperature: config.temperature,
                systemPrompt: effectiveSystem(prompt: prompt, config: config),
                messages: prompt.messages, streaming: false,
                response: String(data: data, encoding: .utf8),
                error: desc, caller: caller
            )
            recordCall(info)
            throw error
        }
        let result = try await Task.detached(priority: .userInitiated) {
            try LLMChatResponse.parseSingleResponse(data)
        }.value
        let info = LLMCallDebugInfo(
            startTime: startTime, endTime: Date(),
            url: url.absoluteString, model: config.model ?? "?",
            temperature: config.temperature,
            systemPrompt: effectiveSystem(prompt: prompt, config: config),
            messages: prompt.messages, streaming: false,
            response: result, error: nil, caller: caller
        )
        recordCall(info)
        // 写入缓存:相同 prompt 在 TTL 内不重复请求网络。
        // Cache the response so the same prompt doesn't hit the network within TTL.
        LLMResponseCache.shared.set(caller: caller, prompt: prompt, config: config, response: result)
        return result
    }

    /// SSE 流式调用,逐 delta 调 `onDelta`。
    /// 返回**完整文本**;`onDelta` 每次接收到目前为止的全部内容。
    /// 失败抛 `LLMError`。
    /// - Parameter caller: 调用场景标签(例如 "MistakeAI" / "WeeklyReport");写入 debug info。
    func stream(
        prompt: LLMPrompt,
        config: LLMConfig,
        caller: String = "stream",
        onDelta: @MainActor (String) -> Void
    ) async throws -> String {
        try validateConfig(config)
        // 缓存命中:把缓存作为单次 onDelta emit,避免重复走网络。
        // Cache hit: emit the cached response as a single onDelta,avoiding the network round-trip.
        if let cached = LLMResponseCache.shared.get(caller: caller, prompt: prompt, config: config) {
            onDelta(cached)
            return cached
        }
        printPromptToConsole(prompt: prompt, config: config, caller: caller)
        let url = try buildURL(baseURL: config.baseURL)
        // JSON 编码移到 detached Task,与 complete() 一致
        // Move JSON encoding off the main actor, matching complete().
        let body = try await Task.detached(priority: .userInitiated) {
            try self.buildBody(prompt: prompt, config: config, stream: true)
        }.value
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(config.apiKey ?? "")", forHTTPHeaderField: "Authorization")
        request.httpBody = body
        request.timeoutInterval = timeoutSeconds
        Log.llm.info("LLM stream → \(url.absoluteString, privacy: .public) model=\(config.model ?? "?", privacy: .public)")

        let startTime = Date()
        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await session.bytes(for: request)
        } catch {
            let info = LLMCallDebugInfo(
                startTime: startTime, endTime: Date(),
                url: url.absoluteString, model: config.model ?? "?",
                temperature: config.temperature,
                systemPrompt: effectiveSystem(prompt: prompt, config: config),
                messages: prompt.messages, streaming: true,
                response: nil, error: error.localizedDescription,
                caller: caller
            )
            recordCall(info)
            if let urlErr = error as? URLError, urlErr.code == .timedOut {
                throw LLMError.timeout
            }
            throw LLMError.network(error.localizedDescription)
        }
        // 如果状态非 2xx,先把整个 body 收集起来再抛(serverError 才会带 body)
        // If status is not 2xx, drain the whole body before throwing so the error carries it.
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            var buffer = Data()
            for try await byte in bytes {
                buffer.append(byte)
            }
            do {
                try validateHTTP(response: response, data: buffer)
            } catch {
                let desc = (error as? LLMError)?.errorDescription ?? error.localizedDescription
                let info = LLMCallDebugInfo(
                    startTime: startTime, endTime: Date(),
                    url: url.absoluteString, model: config.model ?? "?",
                    temperature: config.temperature,
                    systemPrompt: effectiveSystem(prompt: prompt, config: config),
                    messages: prompt.messages, streaming: true,
                    response: String(data: buffer, encoding: .utf8),
                    error: desc, caller: caller
                )
                recordCall(info)
                throw error
            }
        }
        try validateHTTP(response: response, data: Data())

        var accumulated = ""
        var pending = ""
        do {
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
        } catch {
            let info = LLMCallDebugInfo(
                startTime: startTime, endTime: Date(),
                url: url.absoluteString, model: config.model ?? "?",
                temperature: config.temperature,
                systemPrompt: effectiveSystem(prompt: prompt, config: config),
                messages: prompt.messages, streaming: true,
                response: accumulated.isEmpty ? nil : accumulated,
                error: error.localizedDescription, caller: caller
            )
            recordCall(info)
            throw error
        }
        if accumulated.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let info = LLMCallDebugInfo(
                startTime: startTime, endTime: Date(),
                url: url.absoluteString, model: config.model ?? "?",
                temperature: config.temperature,
                systemPrompt: effectiveSystem(prompt: prompt, config: config),
                messages: prompt.messages, streaming: true,
                response: nil, error: LLMError.emptyResponse.errorDescription,
                caller: caller
            )
            recordCall(info)
            throw LLMError.emptyResponse
        }
        let info = LLMCallDebugInfo(
            startTime: startTime, endTime: Date(),
            url: url.absoluteString, model: config.model ?? "?",
            temperature: config.temperature,
            systemPrompt: effectiveSystem(prompt: prompt, config: config),
            messages: prompt.messages, streaming: true,
            response: accumulated, error: nil, caller: caller
        )
        recordCall(info)
        // 写入缓存:与 complete() 一致,使流式调用的结果也可被后续命中。
        // Cache the response so the same prompt doesn't hit the network within TTL.
        LLMResponseCache.shared.set(caller: caller, prompt: prompt, config: config, response: accumulated)
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

    private func printPromptToConsole(
        prompt: LLMPrompt,
        config: LLMConfig,
        caller: String
    ) {
        let systemPrompt = effectiveSystem(prompt: prompt, config: config)
        var messageBlocks = ""
        for (index, msg) in prompt.messages.enumerated() {
            messageBlocks += "[\(index + 1)] [\(msg.role.rawValue.uppercased())]:\n\(msg.content)\n"
        }
        let output = """
        ==================== LLM REQUEST PROMPT START [\(caller)] ====================
        Model: \(config.model ?? "nil")
        Temperature: \(config.temperature)
        Base URL: \(config.baseURL ?? "nil")
        -------------------- SYSTEM PROMPT --------------------
        \(systemPrompt)
        ---------------------- MESSAGES ----------------------
        \(messageBlocks)==================== LLM REQUEST PROMPT END ====================
        """
        // 通过 Log.llm(debug 级) 走统一日志系统;Release 默认 minCaptureLevel=.info 不会保留,
        // DEBUG 模式 verbose 开启时才进入 LogStore。
        // Route through the unified Log system at .debug level. Release builds
        // (minCaptureLevel=.info) drop it; DEBUG + verbose captures into LogStore.
        Log.llm.debug("\(output, privacy: .public)")
    }

    nonisolated private func buildURL(baseURL: String?) throws -> URL {
        guard let raw = baseURL else { throw LLMError.invalidURL }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // 去除末尾的 "/",避免 appedingPathComponent 把请求变成 "//v1"
        // Strip a trailing slash so appendingPathComponent doesn't produce "//v1".
        let cleaned = trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
        guard let base = URL(string: cleaned) else { throw LLMError.invalidURL }
        // 强制走 OpenAI 兼容的 chat completions 路径
        // Always use the OpenAI-compatible /v1/chat/completions path.
        return base.appendingPathComponent("/v1/chat/completions")
    }

    nonisolated private func buildBody(prompt: LLMPrompt, config: LLMConfig, stream: Bool) throws -> Data {
        // 手搓 JSON 避免引入外部 SDK
        // DEBUG 覆盖:非空时**完全替换**默认 system + appendix
        // DEBUG override: when non-empty, replace default system + appendix entirely.
        let effective = effectiveSystem(prompt: prompt, config: config)
        let allMessages = [LLMMessage.system(effective)] + prompt.messages
        let payload: [String: Any] = [
            "model": config.model ?? "",
            "temperature": max(0, min(2, config.temperature)),
            "stream": stream,
            "messages": allMessages.map { ["role": $0.role.rawValue, "content": $0.content] }
        ]
        return try JSONSerialization.data(withJSONObject: payload, options: [])
    }

    /// 拼接最终 system prompt:`override` 优先,否则 `default + appendix`。
    /// Resolve the final system prompt: override takes precedence over default + appendix.
    nonisolated private func effectiveSystem(prompt: LLMPrompt, config: LLMConfig) -> String {
        if let override = config.overrideSystemPrompt?.trimmingCharacters(in: .whitespacesAndNewlines),
           !override.isEmpty {
            return override
        }
        return prompt.effectiveSystem(appendix: config.systemPromptAppendix)
    }

    /// 把一次调用写入 `lastCallInfo` + `recentCalls`,并 log 到 `Log.llm`。
    /// Record a call into `lastCallInfo` and `recentCalls`, and emit a Log.llm entry.
    private func recordCall(_ info: LLMCallDebugInfo) {
        lastCallInfo = info
        recentCalls.append(info)
        if recentCalls.count > recentCallsLimit {
            recentCalls.removeFirst(recentCalls.count - recentCallsLimit)
        }
        let elapsedStr = String(format: "%.2fs", info.elapsedSeconds)
        let okOrErr = info.error == nil ? "OK" : "ERR: \(info.error ?? "")"
        Log.llm.info("LLM call [\(info.caller, privacy: .public)] \(info.url, privacy: .public) elapsed=\(elapsedStr, privacy: .public) status=\(okOrErr, privacy: .public)")
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
