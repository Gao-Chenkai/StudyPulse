//
//  HomeLayoutPreference.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/6/20.
//

import Foundation

// MARK: - Home Card Type

/// 主页可配置的板块卡片类型
enum HomeCardType: String, CaseIterable, Codable {
    case hrvStatus = "hrvStatus"
    case unregisteredExamsReminder = "unregisteredExamsReminder"
    case flashcardReview = "flashcardReview"
    case quickActions = "quickActions"
    case studySuggestions = "studySuggestions"
    case trendChart = "trendChart"
    case upcomingExams = "upcomingExams"
    case studyTimer = "studyTimer"
    case dailyQuote = "dailyQuote"
    case recentGrades = "recentGrades"

    /// 本地化显示名称
    var displayName: String {
        switch self {
        case .studyTimer: return "Study Timer".localized()
        case .hrvStatus: return "HRV Readiness".localized()
        case .unregisteredExamsReminder: return "Exam Grade Reminder".localized()
        case .flashcardReview: return "Flashcard Review".localized()
        case .quickActions: return "Quick Actions".localized()
        case .studySuggestions: return "Study Suggestions".localized()
        case .trendChart: return "Trend Chart".localized()
        case .upcomingExams: return "Upcoming Exams".localized()
        case .dailyQuote: return "Daily Quote".localized()
        case .recentGrades: return "Recent Grades".localized()
        }
    }

    /// SF Symbol 图标
    var icon: String {
        switch self {
        case .studyTimer: return "timer"
        case .hrvStatus: return "heart.text.square"
        case .unregisteredExamsReminder: return "exclamationmark.bubble.fill"
        case .flashcardReview: return "rectangle.stack.fill"
        case .quickActions: return "bolt.fill"
        case .studySuggestions: return "lightbulb.fill"
        case .trendChart: return "chart.line.uptrend.xyaxis"
        case .upcomingExams: return "calendar.badge.exclamationmark"
        case .dailyQuote: return "quote.bubble.fill"
        case .recentGrades: return "list.bullet.rectangle"
        }
    }
}

// MARK: - Home Card Item

/// 单个卡片配置项
struct HomeCardItem: Identifiable, Codable, Equatable {
    var type: HomeCardType
    var enabled: Bool

    var id: String { type.rawValue }
}

// MARK: - Home Layout Preference

/// 主页布局偏好：控制卡片的显示顺序和是否显示
struct HomeLayoutPreference: Codable, Equatable {
    var items: [HomeCardItem]

    /// 默认配置：全部启用，标准顺序
    static let `default` = HomeLayoutPreference(items: [
        HomeCardItem(type: .hrvStatus, enabled: true),
        HomeCardItem(type: .unregisteredExamsReminder, enabled: true),
        HomeCardItem(type: .flashcardReview, enabled: true),
        HomeCardItem(type: .quickActions, enabled: true),
        HomeCardItem(type: .studyTimer, enabled: true),
        HomeCardItem(type: .studySuggestions, enabled: true),
        HomeCardItem(type: .trendChart, enabled: true),
        HomeCardItem(type: .upcomingExams, enabled: true),
        HomeCardItem(type: .dailyQuote, enabled: true),
        HomeCardItem(type: .recentGrades, enabled: true),
    ])
    
    /// 当前启用的卡片类型（按顺序）
    var enabledTypes: [HomeCardType] {
        items.filter(\.enabled).map(\.type)
    }
    
    /// 检查某个卡片类型是否启用
    func isEnabled(_ type: HomeCardType) -> Bool {
        items.first(where: { $0.type == type })?.enabled ?? true
    }
    
    // MARK: - Persistence
    
    private static let userDefaultsKey = "homeLayoutPreference"
    
    /// 从 UserDefaults 加载
    static func load() -> HomeLayoutPreference {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode(HomeLayoutPreference.self, from: data)
        else {
            return .default
        }
        // 兼容：如果存储的 items 数量不对（新增/删除卡片类型），用默认覆盖
        if decoded.items.count != HomeCardType.allCases.count {
            return mergeWithDefault(decoded)
        }
        return decoded
    }
    
    /// 保存到 UserDefaults
    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
    }
    
    /// 重置为默认配置
    static func resetToDefault() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
    
    /// 合并已保存配置与默认配置：保留用户对已知类型的设置，补充新增类型
    private static func mergeWithDefault(_ saved: HomeLayoutPreference) -> HomeLayoutPreference {
        var mergedItems: [HomeCardItem] = []
        let savedMap = Dictionary(uniqueKeysWithValues: saved.items.map { ($0.type, $0.enabled) })
        for defaultItem in HomeLayoutPreference.default.items {
            let enabled = savedMap[defaultItem.type] ?? defaultItem.enabled
            mergedItems.append(HomeCardItem(type: defaultItem.type, enabled: enabled))
        }
        return HomeLayoutPreference(items: mergedItems)
    }
}
