//
//  AppPreferences.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/6/5.
//

import Foundation
import SwiftUI

// MARK: - App Preferences (应用偏好设置)

/// 应用内语言和主题偏好设置模型
/// 数据持久化于 UserDefaults，通过 AppEnvironmentManager 管理
nonisolated struct AppPreferences: Codable {
    /// 语言代码：nil 表示跟随系统
    /// 可选值："en", "zh-Hans", "zh-Hant", "ja", "ko"
    var appLanguage: String?
    /// 颜色主题选项
    var colorScheme: ColorSchemeOption = .system
    /// 成绩趋势图表显示类型（折线/柱状/饼图/散点/热力）
    var chartType: ChartType = .line
    
    // MARK: - 语言常量
    
    /// 支持的语言代码常量
    enum Language {
        static let english = "en"
        static let simplifiedChinese = "zh-Hans"
        static let traditionalChinese = "zh-Hant"
        static let japanese = "ja"
        static let korean = "ko"
        
        /// 所有支持的语言列表
        static let all: [(code: String?, displayName: String)] = [
            (nil, "Follow System"),
            (english, "English"),
            (simplifiedChinese, "简体中文"),
            (traditionalChinese, "繁體中文"),
            (japanese, "日本語"),
            (korean, "한국어")
        ]
        
        /// 所有支持的语言列表（已本地化）
        @MainActor static var allLocalized: [(code: String?, displayName: String)] {
            [
                (nil, "Follow System".localized()),
                (english, "English"),
                (simplifiedChinese, "简体中文"),
                (traditionalChinese, "繁體中文"),
                (japanese, "日本語"),
                (korean, "한국어")
            ]
        }
    }
}

// MARK: - Color Scheme Options (颜色主题选项)

/// 应用颜色主题选项
nonisolated enum ColorSchemeOption: String, Codable, CaseIterable {
    case system = "system"   /// 跟随系统
    case light = "light"     /// 浅色模式
    case dark = "dark"       /// 深色模式
    
    /// 主题对应的 SF Symbol 图标
    var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }
    
    /// 主题的本地化显示名称
    @MainActor var localizedDisplayName: String {
        switch self {
        case .system: "Follow System".localized()
        case .light: "Light".localized()
        case .dark: "Dark".localized()
        }
    }
    
    /// 转换为 SwiftUI ColorScheme（nil = 跟随系统）
    func toSwiftColorScheme() -> ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

// MARK: - Chart Type (成绩趋势图表类型)

/// 成绩趋势图表显示类型
/// - line: 折线图（默认）
/// - bar: 柱状图
/// - pie: 饼图（按分数段占比展示）
/// - scatter: 散点图
/// - heatmap: 热力图（按日期-星期分布密度）
/// - histogram: 频数直方图（按 20% 得分率分组统计次数）
nonisolated enum ChartType: String, Codable, CaseIterable, Identifiable {
    case line = "line"
    case bar = "bar"
    case pie = "pie"
    case scatter = "scatter"
    case heatmap = "heatmap"
    case histogram = "histogram"

    var id: String { rawValue }

    /// SF Symbol 图标
    var icon: String {
        switch self {
        case .line: "chart.xyaxis.line"
        case .bar: "chart.bar.fill"
        case .pie: "chart.pie.fill"
        case .scatter: "chart.dots.scatter"
        case .heatmap: "square.grid.4x3.fill"
        case .histogram: "chart.bar.xaxis"
        }
    }

    /// 本地化显示名称
    @MainActor var localizedDisplayName: String {
        switch self {
        case .line: "Line Chart".localized()
        case .bar: "Bar Chart".localized()
        case .pie: "Pie Chart".localized()
        case .scatter: "Scatter Plot".localized()
        case .heatmap: "Heatmap".localized()
        case .histogram: "Frequency Histogram".localized()
        }
    }

    /// 本地化描述
    @MainActor var localizedDescription: String {
        switch self {
        case .line: "Show score trend over time with connected points.".localized()
        case .bar: "Show each grade as a separate bar.".localized()
        case .pie: "Show distribution across score ranges.".localized()
        case .scatter: "Show each grade as an independent dot.".localized()
        case .heatmap: "Show grade density by weekday and week.".localized()
        case .histogram: "Count how often scores fall into each 20% bucket.".localized()
        }
    }
}
