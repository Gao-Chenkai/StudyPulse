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
    /// 自定义主色预设（影响 AccentColor / 折线 / 进度条）
    /// nil = 跟随系统默认蓝色
    var accentPaletteId: String? = nil
    /// 是否在支持的卡片上启用 iOS 26 glassEffect（默认关闭）
    var glassEffectEnabled: Bool = false
    /// 是否在 Trends 页顶部显示 90 天学习热力图（默认开启）
    var learningHeatmapOnTrends: Bool = true
    /// 当前选中的 study phase id；nil = 全部数据视图（不过滤）
    /// Current active study phase id. nil = show all data (no filtering).
    var activePhaseId: UUID? = nil

    // MARK: - Debug Mode (调试模式)

    /// Debug 模式总开关（默认关闭）。开启后顶部显示黄色 banner，FPS 浮窗、长按检视、Layout Bounds 等子开关才生效。
    /// Master switch for Debug mode. When on, a yellow banner shows at the top of every page,
    /// and the four sub-toggles below become active.
    var debugModeEnabled: Bool = false

    /// 子开关:开启后 LogStore 记录所有 .debug 级别（默认 .info 及以上）。
    /// Sub-toggle: capture .debug level entries in LogStore.
    var debugVerboseLogging: Bool = false

    /// 子开关:在所有主页面右上角显示实时 FPS / 内存 / 日志条数浮窗。
    /// Sub-toggle: show a live FPS / memory / log count overlay on every main page.
    var debugFPSOverlay: Bool = false

    /// 子开关:对应用了 .debugLayoutBounds() 修饰符的 view 显示 1px 随机色边框 + 5% 底色，方便排查布局问题。
    /// Sub-toggle: render a 1px random-color border + 5% tinted background on views marked with .debugLayoutBounds().
    var debugLayoutBounds: Bool = false

    /// 子开关:对应用了 .debugInspect() 修饰符的 view 长按弹 alert 显示原始值与类型。
    /// Sub-toggle: long-press any view marked with .debugInspect() to see its raw value and type.
    var debugLongPressInspect: Bool = false

    // 自定义解码器：缺字段时使用默认值，兼容老版本 UserDefaults 数据
    // Custom decoder: fall back to defaults for missing fields so older
    // serialized preferences (without accentPaletteId / glassEffectEnabled)
    // continue to decode instead of throwing.
    enum CodingKeys: String, CodingKey {
        case appLanguage, colorScheme, chartType, accentPaletteId, glassEffectEnabled, learningHeatmapOnTrends, activePhaseId
        case debugModeEnabled, debugVerboseLogging, debugFPSOverlay, debugLayoutBounds, debugLongPressInspect
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.appLanguage = try c.decodeIfPresent(String.self, forKey: .appLanguage)
        self.colorScheme = try c.decodeIfPresent(ColorSchemeOption.self, forKey: .colorScheme) ?? .system
        self.chartType = try c.decodeIfPresent(ChartType.self, forKey: .chartType) ?? .line
        self.accentPaletteId = try c.decodeIfPresent(String.self, forKey: .accentPaletteId)
        self.glassEffectEnabled = try c.decodeIfPresent(Bool.self, forKey: .glassEffectEnabled) ?? false
        self.learningHeatmapOnTrends = try c.decodeIfPresent(Bool.self, forKey: .learningHeatmapOnTrends) ?? true
        self.activePhaseId = try c.decodeIfPresent(UUID.self, forKey: .activePhaseId)
        self.debugModeEnabled = try c.decodeIfPresent(Bool.self, forKey: .debugModeEnabled) ?? false
        self.debugVerboseLogging = try c.decodeIfPresent(Bool.self, forKey: .debugVerboseLogging) ?? false
        self.debugFPSOverlay = try c.decodeIfPresent(Bool.self, forKey: .debugFPSOverlay) ?? false
        self.debugLayoutBounds = try c.decodeIfPresent(Bool.self, forKey: .debugLayoutBounds) ?? false
        self.debugLongPressInspect = try c.decodeIfPresent(Bool.self, forKey: .debugLongPressInspect) ?? false
    }
    
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

// MARK: - Theme Accent (主色预设)

/// 自定义主色预设：影响 AccentColor、趋势折线、进度条、设置项高亮等。
/// 通过 `accentPaletteId` 字符串持久化；新加预设请追加 `id`，不要改老的 id。
nonisolated enum ThemeAccent: String, CaseIterable, Identifiable {
    case system = "system"       // 跟随系统 AccentColor（默认）
    case blue = "blue"
    case cyan = "cyan"
    case teal = "teal"
    case green = "green"
    case mint = "mint"
    case orange = "orange"
    case red = "red"
    case pink = "pink"
    case purple = "purple"
    case indigo = "indigo"

    var id: String { rawValue }

    /// 解析持久化的 id，未知值回退到 `.system`
    static func resolve(_ id: String?) -> ThemeAccent {
        guard let id, let value = ThemeAccent(rawValue: id) else { return .system }
        return value
    }

    /// SF Symbol 图标（用于色板预览）
    var swatchSystemImage: String {
        switch self {
        case .system: "circle.righthalf.fill"
        default: "circle.fill"
        }
    }

    /// 主色（用于 `tint()`、折线、进度条等）
    /// `.system` 走 SwiftUI 系统 AccentColor，遵循系统浅深色
    var color: Color {
        switch self {
        case .system: .accentColor
        case .blue: .blue
        case .cyan: .cyan
        case .teal: .teal
        case .green: .green
        case .mint: .mint
        case .orange: .orange
        case .red: .red
        case .pink: .pink
        case .purple: .purple
        case .indigo: .indigo
        }
    }

    /// 本地化显示名
    @MainActor var localizedDisplayName: String {
        switch self {
        case .system: "System Default".localized()
        case .blue: "Blue".localized()
        case .cyan: "Cyan".localized()
        case .teal: "Teal".localized()
        case .green: "Green".localized()
        case .mint: "Mint".localized()
        case .orange: "Orange".localized()
        case .red: "Red".localized()
        case .pink: "Pink".localized()
        case .purple: "Purple".localized()
        case .indigo: "Indigo".localized()
        }
    }
}
