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
        didSet {
            save()
            // 任何偏好变更都可能影响 debug 子开关 → 同步到 LogStore
            applyDebugStateToLogStore()
        }
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

    // MARK: - Theme Shop (主题 / 皮肤商店)

    /// 当前装备的主色预设（与 `effectiveAccent` 保持一致；后者保留以兼容旧调用点）。
    var effectiveAccentPalette: AccentPalette {
        ThemeShopCatalog.accentPalette(forId: preferences.accentPaletteId)
    }

    /// 当前装备的卡片皮肤。
    var effectiveCardSkin: CardSkin {
        ThemeShopCatalog.cardSkin(forId: preferences.cardSkinId)
    }

    /// 当前装备的计时器动画。
    var effectiveTimerAnimation: TimerAnimation {
        ThemeShopCatalog.timerAnimation(forId: preferences.timerAnimationId)
    }

    /// 主色对应的 `Color`（直接读 `effectiveAccentPalette.color`）。
    var effectiveAccentPaletteColor: Color {
        effectiveAccentPalette.color
    }

    /// 全局是否启用 iOS 26 glassEffect 卡片
    var glassEffectEnabled: Bool {
        preferences.glassEffectEnabled
    }

    /// 当前激活的 study phase id（nil = 全部数据）
    var activePhaseId: UUID? {
        preferences.activePhaseId
    }

    // MARK: - Debug Mode 透传属性

    /// Debug 模式总开关
    var debugModeEnabled: Bool {
        get { preferences.debugModeEnabled }
        set {
            Log.preferences.info("切换 Debug 总开关 / Debug mode: -> \(newValue, privacy: .public)")
            preferences.debugModeEnabled = newValue
        }
    }

    /// 是否处于 verbose 日志收集模式
    var debugVerboseLogging: Bool {
        preferences.debugVerboseLogging
    }

    /// 是否在主页面右上角显示 FPS / 内存浮窗
    var debugFPSOverlay: Bool {
        preferences.debugFPSOverlay
    }

    /// 是否对 .debugLayoutBounds() 修饰的 view 显示边界
    var debugLayoutBounds: Bool {
        preferences.debugLayoutBounds
    }

    /// 是否对 .debugInspect() 修饰的 view 启用长按检视
    var debugLongPressInspect: Bool {
        preferences.debugLongPressInspect
    }

    /// 是否启用 Debug 模式（仅看 master 总开关）。banner 出现条件。
    /// Whether Debug mode is on (master toggle only). Drives the banner.
    var isDebugModeActive: Bool {
        debugModeEnabled
    }

    /// 是否启用任意 Debug 子行为（用于决定右上角浮窗 / 修饰符是否生效）
    /// Whether any debug sub-behavior is currently active.
    var anyDebugSubToggleOn: Bool {
        debugVerboseLogging || debugFPSOverlay || debugLayoutBounds || debugLongPressInspect
    }

    /// 切换主色预设
    func setAccentPalette(_ accent: ThemeAccent) {
        Log.preferences.info("切换主色 / Accent change: -> \(accent.rawValue, privacy: .public)")
        preferences.accentPaletteId = accent.rawValue
    }

    /// 通过主色预设 id 装备（主题商店入口；与 `setAccentPalette` 行为一致，写同一字段）。
    func setAccentPaletteId(_ id: String) {
        Log.preferences.info("切换主色 (商店) / Accent change (shop): -> \(id, privacy: .public)")
        preferences.accentPaletteId = id
    }

    /// 装备卡片皮肤。
    func setCardSkinId(_ id: String) {
        Log.preferences.info("切换卡片皮肤 / Card skin change: -> \(id, privacy: .public)")
        preferences.cardSkinId = id
    }

    /// 装备计时器动画。
    func setTimerAnimationId(_ id: String) {
        Log.preferences.info("切换计时器动画 / Timer animation change: -> \(id, privacy: .public)")
        preferences.timerAnimationId = id
    }

    /// 切换玻璃效果开关
    func setGlassEffectEnabled(_ enabled: Bool) {
        Log.preferences.info("切换玻璃效果 / Glass effect: -> \(enabled, privacy: .public)")
        preferences.glassEffectEnabled = enabled
    }

    // MARK: - LLM (BYOK 大模型) 透传属性

    /// 当前 LLM 配置快照(只读)。调用方按需构造 `LLMPrompt`。
    var llmConfig: LLMConfig {
        LLMConfig.from(preferences)
    }

    /// LLM 总开关
    var llmEnabled: Bool {
        get { preferences.llmEnabled }
        set {
            Log.preferences.info("切换 LLM 总开关 / LLM enabled: -> \(newValue, privacy: .public)")
            preferences.llmEnabled = newValue
        }
    }

    /// 设置 LLM baseURL。`nil` / 空字符串视作未配置。
    func setLLMBaseURL(_ url: String?) {
        let normalized: String?
        if let url, !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            normalized = url.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            normalized = nil
        }
        Log.preferences.info("更新 LLM baseURL / LLM baseURL: -> \(normalized ?? "nil", privacy: .public)")
        preferences.llmBaseURL = normalized
    }

    /// 设置 LLM API Key。`nil` / 空字符串视作清空。
    func setLLMAPIKey(_ key: String?) {
        let normalized: String?
        if let key, !key.isEmpty { normalized = key } else { normalized = nil }
        Log.preferences.info("更新 LLM apiKey / LLM apiKey: -> \(normalized == nil ? "nil" : "<redacted>", privacy: .public)")
        preferences.llmAPIKey = normalized
    }

    /// 设置 LLM 模型 id
    func setLLMModel(_ model: String?) {
        let normalized: String?
        if let model, !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            normalized = model.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            normalized = nil
        }
        Log.preferences.info("更新 LLM model / LLM model: -> \(normalized ?? "nil", privacy: .public)")
        preferences.llmModel = normalized
    }

    /// 设置 LLM 自定义系统 prompt 追加
    func setLLMSystemPromptAppendix(_ appendix: String?) {
        let normalized: String?
        if let appendix, !appendix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            normalized = appendix
        } else {
            normalized = nil
        }
        preferences.llmSystemPromptAppendix = normalized
    }

    /// 设置 LLM 采样温度(0.0-2.0,内部 clamp)
    func setLLMTemperature(_ temperature: Double) {
        let clamped = max(0, min(2, temperature))
        preferences.llmTemperature = clamped
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

        // 同步 verbose 日志开关到 LogStore
        // Sync the verbose logging flag into the in-memory LogStore.
        applyDebugStateToLogStore()
    }

    /// 把 Debug 子开关同步到 LogStore（verbose 日志级别）
    /// Push the current Debug sub-toggles into LogStore.
    private func applyDebugStateToLogStore() {
        let minLevel: LogLevel = preferences.debugVerboseLogging ? .debug : .info
        LogStore.shared.minCaptureLevel = minLevel
        Log.preferences.info("LogStore minCaptureLevel = \(minLevel.rawValue, privacy: .public)")
    }

    /// 切换 verbose 日志模式（同时改 preferences 和 LogStore）
    /// Toggle verbose logging (updates both preferences and LogStore).
    func setDebugVerboseLogging(_ enabled: Bool) {
        Log.preferences.info("切换 verbose 日志 / Verbose logging: -> \(enabled, privacy: .public)")
        preferences.debugVerboseLogging = enabled
        applyDebugStateToLogStore()
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
