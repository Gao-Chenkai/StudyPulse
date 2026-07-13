//
//  RoutineActivityAttributes.swift
//  StudyPulse
//
//  例程 Live Activity 共享属性(主 App + Widget 两 target 共用)。
//  Routine Live Activity attributes (shared by main App + Widget targets).
//
//  Created for Plans & Routines spec (2026-07-09).
//

@preconcurrency import ActivityKit
import Foundation

/// 例程 Live Activity 属性(主 App 启动 / Widget 渲染 Lock Screen + Dynamic Island)。
/// Routine Live Activity attributes (main app starts; widget renders Lock Screen / Dynamic Island).
nonisolated struct RoutineActivityAttributes: ActivityAttributes, Sendable {
    /// 动态状态(随例程进度变化)/ Dynamic state — evolves as the routine progresses.
    public typealias ContentState = RoutineContentState

    // MARK: - Static Attributes / 静态属性(创建后不变)

    public let routineId: UUID  // 例程唯一 ID / Routine unique ID.
    public let title: String  // 例程标题 / Routine title.
    public let subject: String?  // 关联学科(可选) / Associated subject (optional).
    public let typeRaw: String  // 例程类型原始键 / Routine type raw key.
    public let totalSeconds: Int  // 总时长(秒) / Total duration (seconds).
    public let startISO: String  // 开始时间(ISO 8601) / Start time (ISO 8601).
    public let endISO: String  // 结束时间(ISO 8601) / End time (ISO 8601).
    public let colorHex: String  // 主题色(6 位 hex) / Accent color (6-digit hex, RRGGBB).

    public init(
        routineId: UUID,
        title: String,
        subject: String?,
        typeRaw: String,
        totalSeconds: Int,
        startISO: String,
        endISO: String,
        colorHex: String
    ) {
        self.routineId = routineId
        self.title = title
        self.subject = subject
        self.typeRaw = typeRaw
        self.totalSeconds = totalSeconds
        self.startISO = startISO
        self.endISO = endISO
        self.colorHex = colorHex
    }
}

/// 例程 Live Activity 动态状态 / Dynamic state for the routine Live Activity.
nonisolated public struct RoutineContentState: Codable, Hashable, Sendable {
    public let remainingSeconds: Int  // 剩余秒数 / Remaining seconds.
    public let currentItemTitle: String?  // 当前正在执行的子项标题(可选) / Current sub-item title (optional).
    public let tier: Tier  // 当前强度等级(决定 Live Activity 视觉状态) / Current intensity tier.
    public let progress: Double  // 已完成进度 0...1 / Progress 0...1 (clamped).

    /// 强度等级枚举 / Intensity tier — drives color & urgency.
    public enum Tier: String, Codable, Hashable, Sendable {
        /// 稳态 / Steady state.
        case steady
        /// 警告:剩余 < 5min / Warning: < 5 min remaining.
        case warning    // 剩余 < 5min
        /// 紧急:剩余 < 1min / Critical: < 1 min remaining.
        case critical   // 剩余 < 1min
    }

    public init(
        remainingSeconds: Int,
        currentItemTitle: String? = nil,
        tier: Tier = .steady,
        progress: Double = 0
    ) {
        self.remainingSeconds = remainingSeconds
        self.currentItemTitle = currentItemTitle
        self.tier = tier
        // 把 progress 钳制在 [0, 1] / Clamp progress to [0, 1].
        self.progress = max(0, min(1, progress))
    }
}
