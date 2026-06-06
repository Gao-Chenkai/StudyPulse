//
//  AppEnvironmentManager.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/6/5.
//

import Combine
import SwiftUI
import Foundation

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
    
    private init() {
        // 从 UserDefaults 加载
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let prefs = try? JSONDecoder().decode(AppPreferences.self, from: data) {
            self.preferences = prefs
        } else {
            self.preferences = AppPreferences()
        }
    }
    
    /// 保存偏好到 UserDefaults
    private func save() {
        if let data = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
    
    /// 切换语言
    func setLanguage(_ code: String?) {
        preferences.appLanguage = code
        applyLanguage()
    }
    
    /// 切换主题
    func setColorScheme(_ scheme: ColorSchemeOption) {
        preferences.colorScheme = scheme
    }
    
    /// 应用语言设置（通过 UserDefaults 覆盖 App 语言）
    private func applyLanguage() {
        if let languageCode = preferences.appLanguage {
            UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
        UserDefaults.standard.synchronize()
    }
    
    /// 启动时应用语言（仅首次加载，不调用 synchronize 避免重启提示）
    func applyLanguageOnLaunch() {
        if let languageCode = preferences.appLanguage {
            UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
        }
    }
}
