//
//  HRVWidgetData.swift
//  StudyPulse
//
//  HRV readiness widget shared data model (main app copy)
//

import Foundation

struct HRVWidgetData: Codable {
    let todayHRV: Double?
    let baselineMean: Double?
    let zScore: Double?
    let category: String
    let suggestion: String
    let dailyHistory: [HRVDailyPoint]
}

struct HRVDailyPoint: Codable {
    let date: Date
    let value: Double
}

enum HRVWidgetConfig {
    static let widgetHRVKey = "widgetHRVData"
    static let widgetHRVTimestampKey = "widgetHRVTimestamp"
}

enum HRVWidgetDataStore {
    static func save(data: HRVWidgetData) {
        guard let container = UserDefaults(suiteName: "group.com.chenkai.gao.studypulse") else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let d = try? encoder.encode(data) {
            container.set(d, forKey: HRVWidgetConfig.widgetHRVKey)
            container.set(Date(), forKey: HRVWidgetConfig.widgetHRVTimestampKey)
        }
    }

    static func load() -> HRVWidgetData? {
        guard let container = UserDefaults(suiteName: "group.com.chenkai.gao.studypulse") else { return nil }
        guard let data = container.data(forKey: HRVWidgetConfig.widgetHRVKey) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(HRVWidgetData.self, from: data)
    }
}