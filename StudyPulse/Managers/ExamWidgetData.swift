//
//  ExamWidgetData.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/6/6.
//

import Foundation

/// Widget 专用考试数据（轻量结构体，避免导入主 App 模型）
nonisolated struct ExamWidgetData: Codable {
    let name: String
    let subject: String
    let examDate: Date
    let daysRemaining: Int
}

/// App Group 标识（需要在 Xcode 开发者后台注册后替换）
nonisolated enum AppGroupConfig {
    static let identifier = "group.com.chenkai.gao.studypulse"
    
    /// 共享 UserDefaults 中的考试数据 Key
    static let widgetExamsKey = "widgetUpcomingExams"
    static let widgetExamsTimestampKey = "widgetExamsTimestamp"
}

/// 考试数据在 App Group 共享 UserDefaults 中读写
nonisolated enum WidgetDataStore {
    /// 保存即将到来的考试数据到共享 UserDefaults
    static func save(exams: [ExamWidgetData]) {
        guard let container = UserDefaults(suiteName: AppGroupConfig.identifier) else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(exams) {
            container.set(data, forKey: AppGroupConfig.widgetExamsKey)
            container.set(Date(), forKey: AppGroupConfig.widgetExamsTimestampKey)
        }
    }
    
    /// 从共享 UserDefaults 加载即将到来的考试数据
    static func load() -> [ExamWidgetData] {
        guard let container = UserDefaults(suiteName: AppGroupConfig.identifier) else { return [] }
        guard let data = container.data(forKey: AppGroupConfig.widgetExamsKey) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([ExamWidgetData].self, from: data)) ?? []
    }
    
    /// 获取上次更新时间
    static func lastUpdated() -> Date? {
        guard let container = UserDefaults(suiteName: AppGroupConfig.identifier) else { return nil }
        return container.object(forKey: AppGroupConfig.widgetExamsTimestampKey) as? Date
    }
}
