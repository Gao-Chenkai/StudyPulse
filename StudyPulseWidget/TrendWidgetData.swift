//
//  TrendWidgetData.swift
//  StudyPulseWidget
//
//  Trend chart widget shared data model
//

import Foundation

struct TrendPoint: Codable {
    let date: Date
    let score: Double
    let subject: String
    let fullScore: Double
}

enum TrendWidgetConfig {
    static let widgetTrendKey = "widgetTrendData"
    static let widgetTrendTimestampKey = "widgetTrendTimestamp"
    static let widgetTrendSubjectKey = "widgetTrendSubject"
}

enum TrendWidgetDataStore {
    static func save(points: [TrendPoint]) {
        guard let container = UserDefaults(suiteName: AppGroupConfig.identifier) else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(points) {
            container.set(data, forKey: TrendWidgetConfig.widgetTrendKey)
            container.set(Date(), forKey: TrendWidgetConfig.widgetTrendTimestampKey)
        }
    }

    static func load() -> [TrendPoint] {
        guard let container = UserDefaults(suiteName: AppGroupConfig.identifier) else { return [] }
        guard let data = container.data(forKey: TrendWidgetConfig.widgetTrendKey) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([TrendPoint].self, from: data)) ?? []
    }

    static func savePreferredSubject(_ subject: String?) {
        guard let container = UserDefaults(suiteName: AppGroupConfig.identifier) else { return }
        if let subject {
            container.set(subject, forKey: TrendWidgetConfig.widgetTrendSubjectKey)
        } else {
            container.removeObject(forKey: TrendWidgetConfig.widgetTrendSubjectKey)
        }
    }

    static func loadPreferredSubject() -> String? {
        guard let container = UserDefaults(suiteName: AppGroupConfig.identifier) else { return nil }
        return container.string(forKey: TrendWidgetConfig.widgetTrendSubjectKey)
    }
}