//
//  AppPreferences.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/6/5.
//

import Foundation
import SwiftUI

/// 应用内语言和主题偏好
nonisolated struct AppPreferences: Codable {
    /// 语言选项：nil 表示跟随系统
    var appLanguage: String?
    /// 主题选项：system / light / dark
    var colorScheme: ColorSchemeOption = .system
    
    enum Language {
        static let english = "en"
        static let simplifiedChinese = "zh-Hans"
        static let traditionalChinese = "zh-Hant"
        static let japanese = "ja"
        static let korean = "ko"
        
        static let all: [(code: String?, displayName: String)] = [
            (nil, "Follow System"),
            (english, "English"),
            (simplifiedChinese, "简体中文"),
            (traditionalChinese, "繁體中文"),
            (japanese, "日本語"),
            (korean, "한국어")
        ]
        
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

/// 颜色主题选项
nonisolated enum ColorSchemeOption: String, Codable, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }
    
    @MainActor var localizedDisplayName: String {
        switch self {
        case .system: "Follow System".localized()
        case .light: "Light".localized()
        case .dark: "Dark".localized()
        }
    }
    
    func toSwiftColorScheme() -> ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
