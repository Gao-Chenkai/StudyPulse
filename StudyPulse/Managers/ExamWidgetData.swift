//
//  ExamWidgetData.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/6/6.
//

import Foundation

// MARK: - Widget Exam Data Model (Widget 考试数据模型)

/// Widget 专用考试数据（轻量结构体，避免导入主 App 模型）
/// 用于主 App 与 Widget 之间的数据共享
nonisolated struct ExamWidgetData: Codable {
    /// 考试名称
    let name: String
    /// 科目名称
    let subject: String
    /// 考试日期
    let examDate: Date
    /// 剩余天数
    let daysRemaining: Int
}

// MARK: - App Group Configuration (App Group 配置)

/// App Group 配置常量（需要在 Xcode 开发者后台注册后使用）
nonisolated enum AppGroupConfig {
    /// App Group 标识符
    static let identifier = "group.com.chenkai.gao.studypulse"
    
    /// 共享 UserDefaults 中的考试数据 Key
    static let widgetExamsKey = "widgetUpcomingExams"
    /// 共享 UserDefaults 中的更新时间 Key
    static let widgetExamsTimestampKey = "widgetExamsTimestamp"
}

// MARK: - Widget Data Persistence (Widget 数据存储)

/// Widget 数据读写工具
/// 通过 App Group 共享 UserDefaults 实现主 App 与 Widget 的数据同步
nonisolated enum WidgetDataStore {
    /// 保存即将到来的考试数据到共享 UserDefaults
    /// - Parameter exams: 考试数据列表
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
    /// - Returns: 考试数据列表
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
