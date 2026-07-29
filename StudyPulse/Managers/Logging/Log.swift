//
//  Log.swift
//  StudyPulse
//
//  统一的日志系统 / Unified logging system
//  基于 Apple os.Logger，通过 subsystem + category 进行分类。
//  Powered by Apple's os.Logger, classified by subsystem + category.
//

import Foundation
import os

/// 日志级别。
/// Log level for in-app log entries.
enum LogLevel: String, Sendable, Codable {
    case debug
    case info
    case notice
    case warning
    case error
    case fault
}

extension LogLevel {
    /// 是否为严重级别（warning 及以上）。供 Debug 面板筛选卡顿事件用。
    /// Whether this is a severe level (warning or above). Used by Debug panel filters.
    nonisolated var isSevere: Bool {
        switch self {
        case .warning, .error, .fault: return true
        case .debug, .info, .notice: return false
        }
    }

    /// 严重程度数值（用于 log level 过滤；越大越严重）
    /// Severity rank (higher = more severe). Used for min-level filtering.
    nonisolated var ordinal: Int {
        switch self {
        case .debug: return 0
        case .info: return 1
        case .notice: return 2
        case .warning: return 3
        case .error: return 4
        case .fault: return 5
        }
    }
}

/// 单条日志条目，保存在内存中以供导出。
/// A single log entry captured in memory for export.
struct LogEntry: Sendable, Identifiable {
    let id: UUID
    let timestamp: Date
    let subsystem: String
    let category: String
    let level: LogLevel
    let message: String
}

/// 内存日志存储器，收集当前会话的所有日志条目。
/// In-memory log store that accumulates entries for the current session.
///
/// 由 Swift 原生 actor 保证并发安全，上限 5000 条，超出后丢弃最早条目。
actor LogStore {
    /// 全局共享实例。
    static let shared = LogStore()

    private var entries: [LogEntry] = []
    private var streamContinuations: [UUID: AsyncStream<LogEntry>.Continuation] = [:]
    private let maxEntries = 5_000
    /// 内存中最低记录级别。Debug 模式 verbose 开启时会被设为 .debug,默认 .info。
    /// Minimum level captured into the in-memory buffer.
    /// Set to .debug when Debug → verbose logging is on; defaults to .info.
    private var _minCaptureLevel: LogLevel = .info

    var minCaptureLevel: LogLevel {
        get { _minCaptureLevel }
        set { _minCaptureLevel = newValue }
    }

    func setMinCaptureLevel(_ level: LogLevel) {
        _minCaptureLevel = level
    }

    private init() {}

    /// 记录一条日志到内存存储。
    func record(category: String, level: LogLevel, message: String) {
        // 低于 minCaptureLevel 的条目不入内存(但 os.Logger 仍会写)
        guard shouldCapture(level: level, minLevel: _minCaptureLevel) else {
            return
        }

        let entry = LogEntry(
            id: UUID(),
            timestamp: Date(),
            subsystem: Log.subsystem,
            category: category,
            level: level,
            message: message
        )
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        let continuations = Array(streamContinuations.values)

        for continuation in continuations {
            continuation.yield(entry)
        }
    }

    /// 为每位订阅者创建独立的实时日志流。
    /// Creates an independent real-time log stream for each subscriber.
    func entriesStream() -> AsyncStream<LogEntry> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<LogEntry>.makeStream()
        streamContinuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeStreamContinuation(id: id) }
        }
        return stream
    }

    private func removeStreamContinuation(id: UUID) {
        streamContinuations.removeValue(forKey: id)
    }

    /// 是否记录该 level
    /// Whether a given level should be captured into the buffer.
    nonisolated private func shouldCapture(level: LogLevel, minLevel: LogLevel) -> Bool {
        level.ordinal >= minLevel.ordinal
    }

    /// 当前所有日志条目。
    var allEntries: [LogEntry] {
        return entries
    }

    /// 清空日志存储。
    func clear() {
        entries.removeAll()
    }

    /// 将全部日志导出为纯文本格式，包含头部元信息。
    func exportAsText() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var output = "StudyPulse Log Export\n"
        output += "App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")\n"
        output += "Build: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")\n"
        output += "OS: \(ProcessInfo.processInfo.operatingSystemVersionString)\n"
        output += "Export Time: \(formatter.string(from: Date()))\n"
        output += "Subsystem: \(Log.subsystem)\n"
        output += "Entry Count: \(allEntries.count)\n"
        output += String(repeating: "=", count: 80) + "\n\n"

        for entry in entries {
            let ts = formatter.string(from: entry.timestamp)
            output += "[\(ts)] [\(entry.category)] [\(entry.level.rawValue.uppercased())] \(entry.message)\n"
        }

        return output
    }

    // MARK: - Debug Panel Helpers

    /// 最近一次卡顿事件（category == "Performance" 且 level >= .warning）
    /// Most recent main-thread lag event for the Debug → Performance Panel.
    var lastLagEvent: LogEntry? {
        let entries = allEntries
        for entry in entries.reversed() where entry.category == "Performance" && entry.level.isSevere {
            return entry
        }
        return nil
    }

    /// 指定时间窗口内的卡顿次数
    /// Number of lag events within a time window (used by the Debug → Performance Panel).
    func recentLagCount(within interval: TimeInterval) -> Int {
        let cutoff = Date().addingTimeInterval(-interval)
        return allEntries.reduce(into: 0) { acc, entry in
            guard entry.category == "Performance",
                  entry.level.isSevere,
                  entry.timestamp >= cutoff else { return }
            acc += 1
        }
    }

    /// 当前在内存中的所有 category 列表（去重，按出现顺序）
    /// Unique list of categories currently in the buffer (insertion order).
    var knownCategories: [String] {
        var seen: Set<String> = []
        var ordered: [String] = []
        for entry in allEntries {
            if seen.insert(entry.category).inserted {
                ordered.append(entry.category)
            }
        }
        return ordered
    }
}

/// StudyPulse 全局日志入口。
/// Centralized logging façade for the entire app.
///
/// - `subsystem`: 与主 App bundle identifier 保持一致，方便在 Console.app / Xcode
///   中按子系统过滤。Matches the main app bundle identifier so logs can be
///   filtered by subsystem in Console.app / Xcode.
/// - `category`: 按功能模块划分（如 data、healthKit、widget …），便于按
///   模块追踪问题。Splits logs by functional module (data, healthKit, widget …)
///   for easier troubleshooting.
nonisolated enum Log {
    /// 日志 subsystem，与主 App bundle identifier 保持一致。
    /// Logging subsystem, identical to the main app bundle identifier.
    nonisolated static let subsystem = "Gao.Chenkai.StudyPulse"

    // MARK: - Category Loggers
    // 每个 category 对应一个稳定的 Logger 实例。
    // Each category maps to a stable Logger instance.

    /// App 生命周期（启动、激活、后台）/ App lifecycle (launch, active, background)
    nonisolated static let app = Logger(subsystem: subsystem, category: "App")

    /// DataManager 数据读写、迁移 / DataManager I/O, migration
    nonisolated static let data = Logger(subsystem: subsystem, category: "Data")

    /// HealthKit 鉴权、查询、准备度 / HealthKit authorization, queries, readiness
    nonisolated static let healthKit = Logger(subsystem: subsystem, category: "HealthKit")

    /// 健康历史持久化 / Health history persistence
    nonisolated static let healthHistory = Logger(subsystem: subsystem, category: "HealthHistory")

    /// Widget 同步与刷新 / Widget sync & refresh
    nonisolated static let widget = Logger(subsystem: subsystem, category: "Widget")

    /// 本地通知（授权、调度、取消）/ Local notifications (authorization, scheduling, cancel)
    nonisolated static let notification = Logger(subsystem: subsystem, category: "Notification")

    /// CSV 导入/导出 / CSV import/export
    nonisolated static let export = Logger(subsystem: subsystem, category: "Export")

    /// 视图层（数据管理、编辑等用户可见行为）/ View layer (data management, edits, user-visible actions)
    nonisolated static let view = Logger(subsystem: subsystem, category: "View")

    /// 偏好 / 语言 / 主题设置 / Preferences / language / theme
    nonisolated static let preferences = Logger(subsystem: subsystem, category: "Preferences")

    /// 主线程卡顿 / 性能监测 / Performance monitoring (lag detection)
    nonisolated static let performance = Logger(subsystem: subsystem, category: "Performance")
    nonisolated static let achievement = Logger(subsystem: subsystem, category: "Achievement")

    /// 成就 / 连续打卡系统 / Achievements & streak system

    /// 成绩预测 / Score prediction (linear regression / future Core ML)
    nonisolated static let prediction = Logger(subsystem: subsystem, category: "Prediction")

    /// 主页植物 / Plant card on Home (stage transitions, activity hooks, force override)
    nonisolated static let plant = Logger(subsystem: subsystem, category: "Plant")

    // MARK: - Record to both os.Logger and in-memory store

    /// 同时写入 os.Logger 和内存 LogStore。
    /// Logs to both os.Logger and the in-memory LogStore for later export.
    ///
    /// - Parameter level: 日志级别
    /// - Parameter category: 分类字符串（与 enum 属性名一致，例如 "App"、"Data"）
    /// - Parameter message: 日志正文
    static func record(_ level: LogLevel, category: String, message: String) {
        let logger = Logger(subsystem: subsystem, category: category)
        switch level {
        case .debug:   logger.debug("\(message, privacy: .public)")
        case .info:    logger.info("\(message, privacy: .public)")
        case .notice:  logger.notice("\(message, privacy: .public)")
        case .warning: logger.warning("\(message, privacy: .public)")
        case .error:   logger.error("\(message, privacy: .public)")
        case .fault:   logger.fault("\(message, privacy: .public)")
        }
        Task { await LogStore.shared.record(category: category, level: level, message: message) }
    }
}
