//
//  AppEnvironmentManager.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/6/5.
//

import Combine
import SwiftUI
import Foundation
import os

/// 管理全局应用环境：语言和主题
@MainActor
class AppEnvironmentManager: ObservableObject {
    static let shared = AppEnvironmentManager()
    
    private let defaultsKey = "appPreferences"
    
    @Published var preferences: AppPreferences {
        didSet { save() }
    }
    
    /// 当前有效的 SwiftUI ColorScheme（nil = 跟随系统）
    var effectiveColorScheme: ColorScheme? {
        preferences.colorScheme.toSwiftColorScheme()
    }

    /// 当前有效的语言代码
    var effectiveLanguage: String? {
        preferences.appLanguage
    }

    /// 当前主色（用于 AccentColor / 折线 / 进度条）
    var effectiveAccent: ThemeAccent {
        ThemeAccent.resolve(preferences.accentPaletteId)
    }

    /// 当前主色对应的 `Color`
    var effectiveAccentColor: Color {
        effectiveAccent.color
    }

    /// 全局是否启用 iOS 26 glassEffect 卡片
    var glassEffectEnabled: Bool {
        preferences.glassEffectEnabled
    }

    /// 当前激活的 study phase id（nil = 全部数据）
    var activePhaseId: UUID? {
        preferences.activePhaseId
    }

    /// 切换主色预设
    func setAccentPalette(_ accent: ThemeAccent) {
        Log.preferences.info("切换主色 / Accent change: -> \(accent.rawValue, privacy: .public)")
        preferences.accentPaletteId = accent.rawValue
    }

    /// 切换玻璃效果开关
    func setGlassEffectEnabled(_ enabled: Bool) {
        Log.preferences.info("切换玻璃效果 / Glass effect: -> \(enabled, privacy: .public)")
        preferences.glassEffectEnabled = enabled
    }

    /// 设置当前激活的 study phase（nil = 全部数据）
    func setActivePhaseId(_ id: UUID?) {
        Log.preferences.info("切换 phase / Active phase change: -> \(id?.uuidString ?? "all", privacy: .public)")
        preferences.activePhaseId = id
    }
    
    private init() {
        // 从 UserDefaults 加载 / Load from UserDefaults
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let prefs = try? JSONDecoder().decode(AppPreferences.self, from: data) {
            self.preferences = prefs
            Log.preferences.info("已从 UserDefaults 恢复偏好 / Loaded preferences from UserDefaults: language=\(prefs.appLanguage ?? "auto", privacy: .public) scheme=\(prefs.colorScheme.rawValue, privacy: .public)")
        } else {
            self.preferences = AppPreferences()
            Log.preferences.info("使用默认偏好初始化 / Using default preferences")
        }
    }

    /// 保存偏好到 UserDefaults / Save preferences to UserDefaults
    private func save() {
        if let data = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
            Log.preferences.debug("已保存偏好到 UserDefaults / Saved preferences: language=\(self.preferences.appLanguage ?? "auto", privacy: .public) scheme=\(self.preferences.colorScheme.rawValue, privacy: .public)")
        } else {
            Log.preferences.error("保存偏好失败 / Failed to encode preferences")
        }
    }

    /// 切换语言 / Switch language
    func setLanguage(_ code: String?) {
        Log.preferences.info("切换语言 / Language change: \(self.preferences.appLanguage ?? "auto", privacy: .public) -> \(code ?? "auto", privacy: .public)")
        preferences.appLanguage = code
        applyLanguage()
    }

    /// 切换主题 / Switch theme
    func setColorScheme(_ scheme: ColorSchemeOption) {
        Log.preferences.info("切换主题 / Color scheme change: \(self.preferences.colorScheme.rawValue, privacy: .public) -> \(scheme.rawValue, privacy: .public)")
        preferences.colorScheme = scheme
    }

    /// 应用语言设置（通过 UserDefaults 覆盖 App 语言）/ Apply language (overrides App language via UserDefaults)
    private func applyLanguage() {
        if let languageCode = preferences.appLanguage {
            UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
            Log.preferences.debug("已写入 AppleLanguages / Wrote AppleLanguages: \(languageCode, privacy: .public)")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
            Log.preferences.debug("已清除 AppleLanguages / Cleared AppleLanguages")
        }
        UserDefaults.standard.synchronize()
    }

    /// 启动时应用语言（仅首次加载，不调用 synchronize 避免重启提示）
    /// Apply language at launch (initial load only, skip synchronize to avoid restart prompt)
    func applyLanguageOnLaunch() {
        if let languageCode = preferences.appLanguage {
            UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
            Log.preferences.info("启动时应用语言 / Applied language at launch: \(languageCode, privacy: .public)")
        } else {
            Log.preferences.debug("启动时无偏好语言，使用系统默认 / No preferred language at launch, using system default")
        }
    }
}
