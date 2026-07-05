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
/// 所有 formatter 都是线程安全的(Foundation 文档保证),可放心跨 actor 共享。
enum DateFormatters {

    // MARK: - Date formatters

    /// "EEEE, MMMM d" — 例如 "Tuesday, March 21"
    /// 用于首页 / 详情页头部日期展示。
    static let fullDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f
    }()

    /// "M月d日" / "Mar 21" — 简短日期。
    static let mediumDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    /// "M月d日 EEEE" — 中文风格 "3月21日 星期二"
    static let weekdayDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M月d日 EEEE"
        return f
    }()

    /// 单日 "d" — 例 "21"(紧凑考试卡片日期数字)
    static let dayOfMonth: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()

    /// 3 字母月份 "MMM" — 例 "Mar"(紧凑考试卡片月份缩写)
    static let monthShort: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()

    /// 文件时间戳 "yyyyMMdd_HHmmss"
    static let fileTimestamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmmss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// ISO 日期 "yyyy-MM-dd"
    static let isoDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// 周报月日 "MM/dd"
    static let monthDay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM/dd"
        return f
    }()

    /// 周报周标题 "yyyy 第 ww 周"
    static let weekTitle: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy 'Week' ww"
        return f
    }()

    // MARK: - Number formatters

    /// 整数格式化(千分位)。
    static let integer: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }()

    /// 一位小数。
    static let oneDecimal: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 1
        f.minimumFractionDigits = 1
        return f
    }()

    // MARK: - Convenience

    /// 把 0-1 比例格式化为 "xx%"。
    /// - Parameter rate: 0.0 - 1.0
    /// - Returns: 形如 "85%"
    static func scoreRateText(_ rate: Double) -> String {
        let pct = max(0, min(1, rate)) * 100
        return String(format: "%.0f%%", pct)
    }

    /// 把任意 Double 格式化为整数千分位(返回 "1,234")。
    static func integerString(_ value: Double) -> String {
        integer.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }

    /// 把任意 Double 格式化为 1 位小数("12.3")。
    static func oneDecimalString(_ value: Double) -> String {
        oneDecimal.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }
}
