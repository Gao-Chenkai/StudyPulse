//
//  DateFormatters.swift
//  StudyPulse
//
//  集中所有 DateFormatter / NumberFormatter,避免散落创建。
// 之前散落在 HomeView / WeeklyReportView / PhaseManagementView 等 6+ 处。
//
//  Created for MVVM refactor (2026-07-05).
//

import Foundation

/// 全局共享的日期/数字格式化器。
/// All formatter are thread-safe per Foundation's contract; safe to share across actors.
enum DateFormatters {

    // MARK: - Date formatters
    // MARK: - 日期格式化器 / Date formatters

    /// "EEEE, MMMM d" — 例如 "Tuesday, March 21"
    /// 用于首页 / 详情页头部日期展示。
    /// "EEEE, MMMM d" — e.g. "Tuesday, March 21". Used in home / detail headers.
    static let fullDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f
    }()

    /// "M月d日" / "Mar 21" — 简短日期。
    /// "MMM d" — short date (e.g. "Mar 21").
    static let mediumDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    /// "M月d日 EEEE" — 中文风格 "3月21日 星期二"
    /// "M月d日 EEEE" — Chinese-style "3月21日 星期二".
    static let weekdayDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M月d日 EEEE"
        return f
    }()

    /// 单日 "d" — 例 "21"(紧凑考试卡片日期数字)
    /// Day-of-month "d" — e.g. "21" (compact exam-card day digit).
    static let dayOfMonth: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()

    /// 3 字母月份 "MMM" — 例 "Mar"(紧凑考试卡片月份缩写)
    /// 3-letter month "MMM" — e.g. "Mar" (compact exam-card month).
    static let monthShort: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()

    /// 文件时间戳 "yyyyMMdd_HHmmss"
    /// Filename timestamp "yyyyMMdd_HHmmss".
    static let fileTimestamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmmss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// ISO 日期 "yyyy-MM-dd"
    /// ISO date "yyyy-MM-dd".
    static let isoDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// ISO 8601 完整时间戳(用于 Live Activity attributes / 跨进程序列化)
    /// Full ISO 8601 timestamp (used by Live Activity attributes / cross-process serialization).
    static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// 周报月日 "MM/dd"
    /// Weekly report month/day "MM/dd".
    static let monthDay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM/dd"
        return f
    }()

    /// 周报周标题 "yyyy 第 ww 周"
    /// Weekly report week title "yyyy 'Week' ww".
    static let weekTitle: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy 'Week' ww"
        return f
    }()

    // MARK: - Number formatters
    // MARK: - 数字格式化器 / Number formatters

    /// 整数格式化(千分位)。
    /// Integer with thousands separator.
    static let integer: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }()

    /// 一位小数。
    /// One decimal place (always shown).
    static let oneDecimal: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 1
        f.minimumFractionDigits = 1
        return f
    }()

    // MARK: - Convenience
    // MARK: - 便捷方法 / Convenience

    /// 把 0-1 比例格式化为 "xx%"。
    /// Format a 0-1 ratio as "xx%".
    /// - Parameter rate: 0.0 - 1.0
    /// - Returns: 形如 "85%"
    ///   e.g. "85%".
    static func scoreRateText(_ rate: Double) -> String {
        let pct = max(0, min(1, rate)) * 100
        return String(format: "%.0f%%", pct)
    }

    /// 把任意 Double 格式化为整数千分位(返回 "1,234")。
    /// Format a Double as a thousands-separated integer ("1,234").
    static func integerString(_ value: Double) -> String {
        integer.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }

    /// 把任意 Double 格式化为 1 位小数("12.3")。
    /// Format a Double with 1 decimal place ("12.3").
    static func oneDecimalString(_ value: Double) -> String {
        oneDecimal.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }
}
