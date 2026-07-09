//
//  RoutineActivityAttributes.swift
//  StudyPulseWidget
//
//  例程 Live Activity 共享属性(Widget target 镜像文件,与主 App 一致)。
//
//  Created for Plans & Routines spec (2026-07-09).
//

@preconcurrency import ActivityKit
import Foundation

/// 例程 Live Activity 属性。
/// 由主 App 用于 `Activity<RoutineActivityAttributes>.request(...)`,
/// 由 Widget 用于渲染 Lock Screen / Dynamic Island。
nonisolated struct RoutineActivityAttributes: ActivityAttributes, Sendable {
    /// 动态状态(随例程进度变化)
    public typealias ContentState = RoutineContentState

    /// 静态属性(创建后不变)
    public let routineId: UUID
    public let title: String
    public let subject: String?
    public let typeRaw: String
    public let totalSeconds: Int
    public let startISO: String
    public let endISO: String
    public let colorHex: String

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

/// 例程 Live Activity 动态状态
nonisolated public struct RoutineContentState: Codable, Hashable, Sendable {
    public let remainingSeconds: Int
    public let currentItemTitle: String?
    public let tier: Tier
    /// 已完成进度 0...1
    public let progress: Double

    public enum Tier: String, Codable, Hashable, Sendable {
        case steady
        case warning    // 剩余 < 5min
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
        self.progress = max(0, min(1, progress))
    }
}
