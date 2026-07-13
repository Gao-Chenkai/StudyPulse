//  StudyTimerActivityAttributes.swift
//  StudyPulse
//
//  番茄钟 Live Activity 属性 / Pomodoro Live Activity attributes.
//  由主 App 与 Widget 扩展(target)共用。
//  Shared between the main app and the widget extension target.

@preconcurrency import ActivityKit
import Foundation

/// 番茄钟 Live Activity 属性(主 App + Widget 共用)。
/// Pomodoro Live Activity attributes (shared by main app + widget).
nonisolated struct StudyTimerActivityAttributes: ActivityAttributes, Sendable {
    /// 动态状态(活动期间更新)/ Dynamic state — updated during the activity.
    public struct ContentState: Codable, Hashable, Sendable {
        var remainingSeconds: Int  // 剩余秒数 / Remaining seconds.
        var totalSeconds: Int  // 会话总时长(秒) / Total session duration (seconds).
        var intensityLabel: String  // 强度等级显示名 / Intensity tier label.
        var intensityIcon: String  // 强度 SF Symbol / Intensity SF Symbol.
        var colorHex: String  // 6 位 hex 主题色 / 6-digit hex tier color.
        var tier: String  // tier 原始键 / Raw tier key.
        var targetEndISO: String  // 目标结束时间(ISO 8601) / Target end time (ISO 8601).
    }

    var intensityLabel: String  // 活动开始时记录一次 / Stored once at start.
    var intensityIcon: String  // 活动开始时记录一次 / Stored once at start.
    var colorHex: String  // 6 位 hex 主题色 / 6-digit hex tier color.
    var tier: String  // tier 原始键 / Raw tier key.
    var totalMinutes: Int  // 会话总时长(分钟) / Total session duration (minutes).
}
