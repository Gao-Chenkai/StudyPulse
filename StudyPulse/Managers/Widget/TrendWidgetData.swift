//
//  TrendWidgetData.swift
//  StudyPulse
//
//  Trend chart widget shared data model (main app copy)
//
//  成绩趋势 widget 共享数据模型(主 App 副本)。
//  Trend chart widget shared data model (main app copy).
//

import Foundation

/// 单次成绩(用于 widget 折线图)。
/// A single grade data point for the trend widget's line chart.
struct TrendPoint: Codable {
    let date: Date       // 考试日期 / Exam date
    let score: Double    // 得分 / Score
    let subject: String  // 科目 id / Subject identifier
    let fullScore: Double // 该科满分 / Full score for the subject
}

/// Trend widget 持久化 Key 常量 / Persistence keys for the trend widget
enum TrendWidgetConfig {
    static let widgetTrendKey = "widgetTrendData"              // 折线点主键 / Trend points payload
    static let widgetTrendTimestampKey = "widgetTrendTimestamp" // 最近同步时间 / Last sync timestamp
    static let widgetTrendSubjectKey = "widgetTrendSubject"    // 用户偏好科目 / Preferred subject
}

/// Trend widget 数据读写工具 / Read/write helpers for the trend widget
enum TrendWidgetDataStore {
    /// 写入折线点列表 / Save trend points
    static func save(points: [TrendPoint]) {
        guard let container = UserDefaults(suiteName: "group.com.chenkai.gao.studypulse") else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(points) {
            container.set(data, forKey: TrendWidgetConfig.widgetTrendKey)
            container.set(Date(), forKey: TrendWidgetConfig.widgetTrendTimestampKey)
        }
    }

    /// 加载折线点列表 / Load trend points (empty array if none)
    static func load() -> [TrendPoint] {
        guard let container = UserDefaults(suiteName: "group.com.chenkai.gao.studypulse") else { return [] }
        guard let data = container.data(forKey: TrendWidgetConfig.widgetTrendKey) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([TrendPoint].self, from: data)) ?? []
    }

    /// 写入用户偏好的展示科目(nil 表示清空) / Save the user's preferred subject (nil clears it)
    static func savePreferredSubject(_ subject: String?) {
        guard let container = UserDefaults(suiteName: "group.com.chenkai.gao.studypulse") else { return }
        if let subject {
            container.set(subject, forKey: TrendWidgetConfig.widgetTrendSubjectKey)
        } else {
            container.removeObject(forKey: TrendWidgetConfig.widgetTrendSubjectKey)
        }
    }

    /// 加载用户偏好的展示科目 / Load the user's preferred subject
    static func loadPreferredSubject() -> String? {
        guard let container = UserDefaults(suiteName: "group.com.chenkai.gao.studypulse") else { return nil }
        return container.string(forKey: TrendWidgetConfig.widgetTrendSubjectKey)
    }
}