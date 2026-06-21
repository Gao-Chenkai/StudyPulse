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
}
