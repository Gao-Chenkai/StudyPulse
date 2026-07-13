//
//  HRVWidgetData.swift
//  StudyPulse
//
//  HRV readiness widget shared data model (main app copy)
//
//  HRV 准备度 widget 的共享数据模型(主 App 副本)。
//  HRV readiness widget shared data model (main app copy).
//

import Foundation

/// Widget 端使用的 HRV 准备度数据快照(主 App 与 Widget 共用)。
/// HRV readiness snapshot shared between main app and the widget.
struct HRVWidgetData: Codable {
    /// 当日 HRV (ms) / Today's HRV (ms)
    let todayHRV: Double?
    /// 30 天基线均值 / 30-day baseline mean
    let baselineMean: Double?
    /// z-score(当日偏离基线的标准差倍数) / Standard deviations from baseline
    let zScore: Double?
    /// 准备度类别字符串 / Readiness category (raw value)
    let category: String
    /// 建议文案 / Human-readable suggestion
    let suggestion: String
    /// 近 N 天每日 HRV 点(供趋势图) / Recent daily HRV points (for trend chart)
    let dailyHistory: [HRVDailyPoint]
}

/// 单日 HRV 数据点 / Single-day HRV data point
struct HRVDailyPoint: Codable {
    let date: Date   // 日期 / Date
    let value: Double // HRV 值(ms) / HRV value (ms)
}

/// HRV widget 持久化 Key 常量 / Persistence keys for the HRV widget
enum HRVWidgetConfig {
    static let widgetHRVKey = "widgetHRVData"           // HRV 数据主键 / Main payload key
    static let widgetHRVTimestampKey = "widgetHRVTimestamp"  // 最近同步时间 / Last sync timestamp
}

/// HRV widget 数据读写工具 / Read/write helpers for the HRV widget
enum HRVWidgetDataStore {
    /// 写入 HRV 数据 / Save HRV data to the shared App Group UserDefaults
    static func save(data: HRVWidgetData) {
        // suiteName 必须是已注册的 App Group id,否则写入失败
        // suiteName must be a registered App Group id; otherwise writes silently fail.
        guard let container = UserDefaults(suiteName: "group.com.chenkai.gao.studypulse") else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let d = try? encoder.encode(data) {
            container.set(d, forKey: HRVWidgetConfig.widgetHRVKey)
            container.set(Date(), forKey: HRVWidgetConfig.widgetHRVTimestampKey)
        }
    }

    /// 加载 HRV 数据 / Load HRV data from the shared App Group UserDefaults
    static func load() -> HRVWidgetData? {
        guard let container = UserDefaults(suiteName: "group.com.chenkai.gao.studypulse") else { return nil }
        guard let data = container.data(forKey: HRVWidgetConfig.widgetHRVKey) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(HRVWidgetData.self, from: data)
    }
}