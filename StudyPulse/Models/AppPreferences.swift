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
