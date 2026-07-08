//
//  ThemeShop.swift
//  StudyPulse
//
//  主题 / 皮肤商店 (Theme Shop) 数据层。
//  Three independent cosmetic catalogs that drive the app's visual
//  customization. Unlocks are NOT persisted separately — they are
//  derived from existing achievement unlock state. Only the *equipped*
//  selection is persisted (via AppPreferences).
//
//  - `AccentPalette`   主色预设：影响 AccentColor、折线、进度条
//  - `CardSkin`        卡片皮肤：影响卡片背景/边框/阴影
//  - `TimerAnimation`  计时器动画：影响 StudyTimer 的粒子/辉光/背景
//
//  Three categories are fully orthogonal — users can mix & match.
//  No IAP. Polar / Sakura / Galaxy are example entries in the
//  `timerAnimations` catalog.
//

import SwiftUI
import Foundation

// MARK: - AccentPalette

/// 主色预设条目。
/// id 兼容旧 `ThemeAccent` rawValue 字符串（"blue", "cyan"...），老数据无感升级。
nonisolated struct AccentPalette: Identifiable, Hashable, Sendable {
    /// 持久化主键（同时是 `accentPaletteId` 的值）。
    let id: String
    /// 本地化 key（不含 "theme.shop.item.<id>.name" 前缀）。
    let displayNameKey: String
    /// 本地化 key（不含 "theme.shop.item.<id>.description" 前缀）。
    let descriptionKey: String
    /// 解锁所需的成就 id；nil = 永久免费。
    let unlockAchievementId: String?
    /// 主色（用于 AccentColor / 折线 / 进度条）。
    let primary: Color
    /// 副色（用于渐变 / 边框 / 阴影）。
    let secondary: Color
    /// SF Symbol 图标。
    let icon: String

    var color: Color { primary }

    var gradient: LinearGradient {
        LinearGradient(
            colors: [primary, secondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var localizedName: String {
        "theme.shop.item.\(id).name".localized()
    }

    var localizedDescription: String {
        "theme.shop.item.\(id).description".localized()
    }
}

// MARK: - CardSkin

/// 卡片皮肤条目。纯数据；view 渲染在 `CardSkinRenderer` 扩展里。
nonisolated struct CardSkin: Identifiable, Hashable, Sendable {
    /// 持久化主键。
    let id: String
    /// 本地化 key。
    let displayNameKey: String
    /// 本地化 key。
    let descriptionKey: String
    /// 解锁所需成就 id；nil = 永久免费。
    let unlockAchievementId: String?
    /// SF Symbol 图标。
    let icon: String
    /// 卡片圆角。
    let cornerRadius: CGFloat
    /// 边框宽度。
    let borderWidth: CGFloat
    /// 边框不透明度（0~1）。
    let borderOpacity: Double
    /// 阴影半径。
    let shadowRadius: CGFloat
    /// 阴影不透明度（0~1）。
    let shadowOpacity: Double
    /// 是否需要 iOS 26 `glassEffect`（与 `glassEffectEnabled` 二次门控）。
    let isGlass: Bool
    /// 皮肤主题色（用于边框/装饰色）。
    let accentColor: Color
    /// 背景不透明度（0~1）。
    let backgroundOpacity: Double
    /// 视觉变体（决定渲染器走哪条分支）。
    let styleVariant: StyleVariant

    enum StyleVariant: String, Hashable, Sendable {
        /// 单色填充（系统默认）。
        case plain
        /// 双色渐变填充。
        case gradient
        /// iOS 26 glass（需 `isGlass && glassEffectEnabled`）。
        case frosted
        /// 多色光晕渐变。
        case aurora
        /// 樱花瓣装饰（半透明粉 + 渐变）。
        case sakura
        /// 星空深紫渐变。
        case galaxy
        /// 羊皮纸纹理（暖棕渐变 + 装饰边框）。
        case parchment
    }

    var localizedName: String {
        "theme.shop.item.\(id).name".localized()
    }

    var localizedDescription: String {
        "theme.shop.item.\(id).description".localized()
    }
}

// MARK: - TimerAnimation

/// 计时器动画条目。纯数据；view 渲染在 `TimerAnimationRenderer` 扩展里。
nonisolated struct TimerAnimation: Identifiable, Hashable, Sendable {
    /// 持久化主键。
    let id: String
    /// 本地化 key。
    let displayNameKey: String
    /// 本地化 key。
    let descriptionKey: String
    /// 解锁所需成就 id；nil = 永久免费。
    let unlockAchievementId: String?
    /// SF Symbol 图标。
    let icon: String
    /// 主题色（2~3 色），用于环形 + 粒子 + 背景渐变。
    let colors: [Color]
    /// 粒子形态。
    let particleStyle: ParticleStyle
    /// 粒子数量（0~20）。
    let particleCount: Int
    /// 背景形态。
    let backgroundStyle: BackgroundStyle
    /// 用 `colors[glowColorIndex]` 作 radial glow。
    let glowColorIndex: Int

    enum ParticleStyle: String, Hashable, Sendable {
        /// 默认圆形光球（旧 ColorTheme 行为）。
        case orbs
        /// 雪花下落。
        case snowfall
        /// 樱花瓣飘落。
        case petals
        /// 星空闪烁。
        case stars
        /// 流萤光点。
        case fireflies
        /// 气泡上浮。
        case bubbles
        /// 雨滴下落。
        case rain
        /// 无粒子。
        case none

        /// 粒子属性范围（size / speed / opacity），驱动 `StudyTimerActiveCard` 的随机化。
        var ranges: (size: ClosedRange<CGFloat>, speed: ClosedRange<Double>, opacity: ClosedRange<Double>) {
            switch self {
            case .snowfall: return (2...5, 5.0...10.0, 0.4...0.8)
            case .petals:   return (6...12, 6.0...12.0, 0.5...0.9)
            case .stars:    return (1...3, 3.0...8.0, 0.3...0.7)
            case .fireflies:return (3...6, 4.0...9.0, 0.4...0.8)
            case .bubbles:  return (5...10, 5.0...10.0, 0.3...0.6)
            case .rain:     return (1...3, 1.5...3.0, 0.4...0.7)
            case .orbs:     return (3...7, 4.0...8.0, 0.2...0.5)
            case .none:     return (1...1, 1.0...1.0, 0.0...0.0)
            }
        }
    }

    enum BackgroundStyle: String, Hashable, Sendable {
        /// 流动渐变（旧 ColorTheme 行为）。
        case flowGradient
        /// 星空深紫（带闪烁点）。
        case starfield
        /// 森林深绿。
        case forest
        /// 无背景动效（仅纯色）。
        case none
    }

    /// 主色（环形中心 + 按钮用色）。
    var primaryColor: Color { colors.first ?? .blue }

    /// 用于 radial glow 的色。
    var glowColor: Color {
        guard colors.indices.contains(glowColorIndex) else { return primaryColor }
        return colors[glowColorIndex]
    }

    var localizedName: String {
        "theme.shop.item.\(id).name".localized()
    }

    var localizedDescription: String {
        "theme.shop.item.\(id).description".localized()
    }
}

// MARK: - ThemeShopCatalog

/// 静态主题目录（编译期常量）。所有条目 id 必须稳定 — id 变更等同于删档。
nonisolated enum ThemeShopCatalog {

    // MARK: Accent Palettes

    nonisolated static let accentPalettes: [AccentPalette] = [
        // --- 永久免费：与旧 ThemeAccent rawValue 字符串完全兼容 ---
        AccentPalette(
            id: "system", displayNameKey: "system", descriptionKey: "system",
            unlockAchievementId: nil,
            primary: .accentColor, secondary: .blue,
            icon: "circle.righthalf.fill"
        ),
        AccentPalette(
            id: "blue", displayNameKey: "blue", descriptionKey: "blue",
            unlockAchievementId: nil,
            primary: .blue, secondary: .cyan,
            icon: "circle.fill"
        ),
        AccentPalette(
            id: "cyan", displayNameKey: "cyan", descriptionKey: "cyan",
            unlockAchievementId: nil,
            primary: .cyan, secondary: .teal,
            icon: "circle.fill"
        ),
        AccentPalette(
            id: "teal", displayNameKey: "teal", descriptionKey: "teal",
            unlockAchievementId: nil,
            primary: .teal, secondary: .green,
            icon: "circle.fill"
        ),
        AccentPalette(
            id: "green", displayNameKey: "green", descriptionKey: "green",
            unlockAchievementId: nil,
            primary: .green, secondary: .mint,
            icon: "circle.fill"
        ),
        AccentPalette(
            id: "mint", displayNameKey: "mint", descriptionKey: "mint",
            unlockAchievementId: nil,
            primary: .mint, secondary: .green,
            icon: "circle.fill"
        ),
        AccentPalette(
            id: "orange", displayNameKey: "orange", descriptionKey: "orange",
            unlockAchievementId: nil,
            primary: .orange, secondary: .yellow,
            icon: "circle.fill"
        ),
        AccentPalette(
            id: "red", displayNameKey: "red", descriptionKey: "red",
            unlockAchievementId: nil,
            primary: .red, secondary: .orange,
            icon: "circle.fill"
        ),
        AccentPalette(
            id: "pink", displayNameKey: "pink", descriptionKey: "pink",
            unlockAchievementId: nil,
            primary: .pink, secondary: .purple,
            icon: "circle.fill"
        ),
        AccentPalette(
            id: "purple", displayNameKey: "purple", descriptionKey: "purple",
            unlockAchievementId: nil,
            primary: .purple, secondary: .indigo,
            icon: "circle.fill"
        ),
        AccentPalette(
            id: "indigo", displayNameKey: "indigo", descriptionKey: "indigo",
            unlockAchievementId: nil,
            primary: .indigo, secondary: .blue,
            icon: "circle.fill"
        ),

        // --- 成就解锁：限定主题色 ---
        AccentPalette(
            id: "sakura_pink", displayNameKey: "sakura_pink", descriptionKey: "sakura_pink",
            unlockAchievementId: "streak_30",
            primary: Color(red: 1.0, green: 0.62, blue: 0.78),
            secondary: Color(red: 0.95, green: 0.45, blue: 0.65),
            icon: "leaf.fill"
        ),
        AccentPalette(
            id: "galaxy_violet", displayNameKey: "galaxy_violet", descriptionKey: "galaxy_violet",
            unlockAchievementId: "streak_100",
            primary: Color(red: 0.45, green: 0.30, blue: 0.95),
            secondary: Color(red: 0.20, green: 0.15, blue: 0.65),
            icon: "moon.stars.fill"
        ),
        AccentPalette(
            id: "aurora_cyan", displayNameKey: "aurora_cyan", descriptionKey: "aurora_cyan",
            unlockAchievementId: "focus_3000",
            primary: Color(red: 0.25, green: 0.85, blue: 0.75),
            secondary: Color(red: 0.10, green: 0.55, blue: 0.90),
            icon: "sparkles"
        ),
        AccentPalette(
            id: "midnight_indigo", displayNameKey: "midnight_indigo", descriptionKey: "midnight_indigo",
            unlockAchievementId: "streak_365",
            primary: Color(red: 0.10, green: 0.10, blue: 0.45),
            secondary: Color(red: 0.05, green: 0.05, blue: 0.25),
            icon: "moon.fill"
        ),
        AccentPalette(
            id: "sunset_orange", displayNameKey: "sunset_orange", descriptionKey: "sunset_orange",
            unlockAchievementId: "reviews_200",
            primary: Color(red: 1.0, green: 0.50, blue: 0.20),
            secondary: Color(red: 1.0, green: 0.30, blue: 0.45),
            icon: "sun.max.fill"
        ),
    ]

    // MARK: Card Skins

    nonisolated static let cardSkins: [CardSkin] = [
        // --- 永久免费：默认皮肤（与改卡前的 .background/.cornerRadius/.shadow 完全一致）---
        CardSkin(
            id: "minimal_paper", displayNameKey: "minimal_paper", descriptionKey: "minimal_paper",
            unlockAchievementId: nil,
            icon: "rectangle.fill",
            cornerRadius: 20, borderWidth: 0, borderOpacity: 0,
            shadowRadius: 10, shadowOpacity: 0.05,
            isGlass: false,
            accentColor: .blue,
            backgroundOpacity: 1.0,
            styleVariant: .plain
        ),
        CardSkin(
            id: "frosted_glass", displayNameKey: "frosted_glass", descriptionKey: "frosted_glass",
            unlockAchievementId: nil,
            icon: "drop.fill",
            cornerRadius: 18, borderWidth: 0.5, borderOpacity: 0.2,
            shadowRadius: 12, shadowOpacity: 0.08,
            isGlass: true,
            accentColor: .cyan,
            backgroundOpacity: 1.0,
            styleVariant: .frosted
        ),
        CardSkin(
            id: "aurora_mist", displayNameKey: "aurora_mist", descriptionKey: "aurora_mist",
            unlockAchievementId: nil,
            icon: "sparkles",
            cornerRadius: 20, borderWidth: 1, borderOpacity: 0.25,
            shadowRadius: 10, shadowOpacity: 0.08,
            isGlass: false,
            accentColor: Color(red: 0.25, green: 0.85, blue: 0.75),
            backgroundOpacity: 1.0,
            styleVariant: .aurora
        ),

        // --- 成就解锁 ---
        CardSkin(
            id: "sakura_blossom", displayNameKey: "sakura_blossom", descriptionKey: "sakura_blossom",
            unlockAchievementId: "reviews_200",
            icon: "leaf.fill",
            cornerRadius: 22, borderWidth: 1, borderOpacity: 0.35,
            shadowRadius: 10, shadowOpacity: 0.10,
            isGlass: false,
            accentColor: Color(red: 1.0, green: 0.62, blue: 0.78),
            backgroundOpacity: 1.0,
            styleVariant: .sakura
        ),
        CardSkin(
            id: "galaxy_nebula", displayNameKey: "galaxy_nebula", descriptionKey: "galaxy_nebula",
            unlockAchievementId: "streak_100",
            icon: "moon.stars.fill",
            cornerRadius: 20, borderWidth: 1, borderOpacity: 0.4,
            shadowRadius: 14, shadowOpacity: 0.12,
            isGlass: false,
            accentColor: Color(red: 0.45, green: 0.30, blue: 0.95),
            backgroundOpacity: 1.0,
            styleVariant: .galaxy
        ),
        CardSkin(
            id: "parchment", displayNameKey: "parchment", descriptionKey: "parchment",
            unlockAchievementId: "grades_200",
            icon: "book.closed.fill",
            cornerRadius: 14, borderWidth: 1.5, borderOpacity: 0.35,
            shadowRadius: 8, shadowOpacity: 0.10,
            isGlass: false,
            accentColor: Color(red: 0.60, green: 0.40, blue: 0.20),
            backgroundOpacity: 1.0,
            styleVariant: .parchment
        ),
    ]

    // MARK: Timer Animations

    nonisolated static let timerAnimations: [TimerAnimation] = [
        // --- 永久免费：与旧 ColorTheme rawValue 字符串完全兼容 ---
        TimerAnimation(
            id: "aurora", displayNameKey: "aurora", descriptionKey: "aurora",
            unlockAchievementId: nil,
            icon: "sparkles",
            colors: [
                Color(red: 0.2, green: 0.8, blue: 0.5),
                Color(red: 0.1, green: 0.6, blue: 0.9),
                Color(red: 0.5, green: 0.3, blue: 0.9)
            ],
            particleStyle: .orbs, particleCount: 12,
            backgroundStyle: .flowGradient, glowColorIndex: 0
        ),
        TimerAnimation(
            id: "sunset", displayNameKey: "sunset", descriptionKey: "sunset",
            unlockAchievementId: "reviews_200",
            icon: "sun.max.fill",
            colors: [
                Color(red: 1.0, green: 0.4, blue: 0.2),
                Color(red: 1.0, green: 0.6, blue: 0.1),
                Color(red: 0.9, green: 0.2, blue: 0.5)
            ],
            particleStyle: .orbs, particleCount: 10,
            backgroundStyle: .flowGradient, glowColorIndex: 0
        ),
        TimerAnimation(
            id: "ocean", displayNameKey: "ocean", descriptionKey: "ocean",
            unlockAchievementId: nil,
            icon: "water.waves",
            colors: [
                Color(red: 0.1, green: 0.5, blue: 0.9),
                Color(red: 0.0, green: 0.8, blue: 0.8),
                Color(red: 0.2, green: 0.3, blue: 0.9)
            ],
            particleStyle: .bubbles, particleCount: 14,
            backgroundStyle: .flowGradient, glowColorIndex: 0
        ),
        TimerAnimation(
            id: "forest", displayNameKey: "forest", descriptionKey: "forest",
            unlockAchievementId: nil,
            icon: "leaf.fill",
            colors: [
                Color(red: 0.2, green: 0.7, blue: 0.3),
                Color(red: 0.1, green: 0.5, blue: 0.2),
                Color(red: 0.6, green: 0.8, blue: 0.2)
            ],
            particleStyle: .fireflies, particleCount: 12,
            backgroundStyle: .forest, glowColorIndex: 0
        ),
        TimerAnimation(
            id: "lavender", displayNameKey: "lavender", descriptionKey: "lavender",
            unlockAchievementId: nil,
            icon: "flower",
            colors: [
                Color(red: 0.6, green: 0.4, blue: 0.9),
                Color(red: 0.8, green: 0.3, blue: 0.7),
                Color(red: 0.4, green: 0.5, blue: 1.0)
            ],
            particleStyle: .petals, particleCount: 10,
            backgroundStyle: .flowGradient, glowColorIndex: 0
        ),
        TimerAnimation(
            id: "neon", displayNameKey: "neon", descriptionKey: "neon",
            unlockAchievementId: nil,
            icon: "bolt.fill",
            colors: [
                Color(red: 0.0, green: 1.0, blue: 0.5),
                Color(red: 1.0, green: 0.0, blue: 0.5),
                Color(red: 0.5, green: 0.0, blue: 1.0)
            ],
            particleStyle: .orbs, particleCount: 14,
            backgroundStyle: .flowGradient, glowColorIndex: 0
        ),

        // --- 成就解锁：Polar / Sakura / Galaxy 是用户指定的 3 个示例 ---
        TimerAnimation(
            id: "polar", displayNameKey: "polar", descriptionKey: "polar",
            unlockAchievementId: "focus_3000",
            icon: "snowflake",
            colors: [
                Color(red: 0.55, green: 0.85, blue: 1.0),
                Color(red: 0.85, green: 0.95, blue: 1.0),
                Color(red: 0.30, green: 0.65, blue: 0.95)
            ],
            particleStyle: .snowfall, particleCount: 18,
            backgroundStyle: .flowGradient, glowColorIndex: 0
        ),
        TimerAnimation(
            id: "sakura", displayNameKey: "sakura", descriptionKey: "sakura",
            unlockAchievementId: "streak_30",
            icon: "leaf.fill",
            colors: [
                Color(red: 1.0, green: 0.78, blue: 0.85),
                Color(red: 0.98, green: 0.55, blue: 0.70),
                Color(red: 0.95, green: 0.40, blue: 0.55)
            ],
            particleStyle: .petals, particleCount: 14,
            backgroundStyle: .flowGradient, glowColorIndex: 1
        ),
        TimerAnimation(
            id: "galaxy", displayNameKey: "galaxy", descriptionKey: "galaxy",
            unlockAchievementId: "streak_100",
            icon: "moon.stars.fill",
            colors: [
                Color(red: 0.35, green: 0.20, blue: 0.85),
                Color(red: 0.10, green: 0.05, blue: 0.45),
                Color(red: 0.85, green: 0.55, blue: 1.0)
            ],
            particleStyle: .stars, particleCount: 24,
            backgroundStyle: .starfield, glowColorIndex: 2
        ),
        TimerAnimation(
            id: "midnight", displayNameKey: "midnight", descriptionKey: "midnight",
            unlockAchievementId: "streak_365",
            icon: "moon.fill",
            colors: [
                Color(red: 0.05, green: 0.05, blue: 0.20),
                Color(red: 0.10, green: 0.15, blue: 0.40),
                Color(red: 0.30, green: 0.40, blue: 0.95)
            ],
            particleStyle: .stars, particleCount: 18,
            backgroundStyle: .starfield, glowColorIndex: 2
        ),
        TimerAnimation(
            id: "mint_fresh", displayNameKey: "mint_fresh", descriptionKey: "mint_fresh",
            unlockAchievementId: "active_180",
            icon: "leaf.fill",
            colors: [
                Color(red: 0.40, green: 0.95, blue: 0.70),
                Color(red: 0.20, green: 0.75, blue: 0.55),
                Color(red: 0.55, green: 1.0, blue: 0.85)
            ],
            particleStyle: .bubbles, particleCount: 14,
            backgroundStyle: .flowGradient, glowColorIndex: 0
        ),
    ]

    // MARK: Lookups

    /// 通过 id 查找主色预设；找不到返回第一个免费项。
    static func accentPalette(forId id: String?) -> AccentPalette {
        if let id, let p = accentPalettes.first(where: { $0.id == id }) { return p }
        return accentPalettes.first(where: { $0.unlockAchievementId == nil }) ?? accentPalettes[0]
    }

    /// 通过 id 查找卡片皮肤。
    static func cardSkin(forId id: String?) -> CardSkin {
        if let id, let s = cardSkins.first(where: { $0.id == id }) { return s }
        return cardSkins.first(where: { $0.unlockAchievementId == nil }) ?? cardSkins[0]
    }

    /// 通过 id 查找计时器动画。
    static func timerAnimation(forId id: String?) -> TimerAnimation {
        if let id, let t = timerAnimations.first(where: { $0.id == id }) { return t }
        return timerAnimations.first(where: { $0.unlockAchievementId == nil }) ?? timerAnimations[0]
    }

    // MARK: Unlock helpers

    /// 给定已解锁成就 id 集合 + debug 模式，判定条目是否可装备。
    ///  - `isDebugMode == true` ⇒ 一律返回 true（设计预览 / 回归测试用）。
    ///  - `item.unlockAchievementId == nil` ⇒ 永久免费。
    ///  - 否则要求 `achievementIds.contains(item.unlockAchievementId)`。
    @MainActor
    static func isUnlocked(
        unlockAchievementId: String?,
        achievementIds: Set<String>,
        isDebugMode: Bool
    ) -> Bool {
        if isDebugMode { return true }
        guard let required = unlockAchievementId else { return true }
        return achievementIds.contains(required)
    }

    /// 通过成就 id 找到受其解锁影响的所有条目 id（用于"刚解锁"高亮）。
    static func itemsUnlockedBy(_ achievementId: String) -> Set<String> {
        var result = Set<String>()
        for p in accentPalettes where p.unlockAchievementId == achievementId { result.insert(p.id) }
        for s in cardSkins where s.unlockAchievementId == achievementId { result.insert(s.id) }
        for t in timerAnimations where t.unlockAchievementId == achievementId { result.insert(t.id) }
        return result
    }
}
