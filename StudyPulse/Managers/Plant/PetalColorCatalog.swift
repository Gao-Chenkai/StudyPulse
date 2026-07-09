//
//  PetalColorCatalog.swift
//  StudyPulse
//
//  5 个花瓣颜色预设，每个有独立的 light / dark 配色，避免 dark mode 下出现荧光色。
//  5 petal-color presets, each with separate light/dark swatches to avoid
//  fluorescent tones in dark mode.
//

import SwiftUI

// MARK: - PetalColor

/// 单个花瓣颜色预设。
/// A single petal-color preset.
nonisolated struct PetalColor: Identifiable, Hashable, Sendable {
    /// 持久化主键（同时是 `plantPetalColorId` 的值）。
    let id: String
    /// 浅色模式下的花瓣主色。
    /// Petal primary color in light mode.
    let light: Color
    /// 深色模式下的花瓣主色（饱和度降低，避免荧光感）。
    /// Petal primary color in dark mode (lowered saturation, no fluorescence).
    let dark: Color
    /// SF Symbol 图标（用于颜色选择器）。
    /// SF Symbol shown in the color picker.
    let icon: String

    /// 当前模式下的实际颜色（用于 Canvas 渲染）。
    /// Resolved color for the current color scheme.
    func resolved(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? dark : light
    }
}

// MARK: - PetalColorCatalog

/// 花瓣颜色目录常量。
/// Compile-time catalog of every available petal color.
nonisolated enum PetalColorCatalog {
    /// 5 个固定顺序的花瓣颜色。顺序就是 Settings → Appearance → Plant Garden 里的展示顺序。
    /// Fixed order; matches the order shown in Settings.
    static let all: [PetalColor] = [
        rose,
        lavender,
        sunflower,
        jasmine,
        aqua,
    ]

    /// Rose — 经典粉红色（默认）。
    static let rose = PetalColor(
        id: "rose",
        light: Color(red: 0.93, green: 0.36, blue: 0.51),
        dark: Color(red: 0.85, green: 0.50, blue: 0.60),
        icon: "leaf.fill"
    )

    /// Lavender — 紫色。
    static let lavender = PetalColor(
        id: "lavender",
        light: Color(red: 0.62, green: 0.45, blue: 0.85),
        dark: Color(red: 0.65, green: 0.55, blue: 0.85),
        icon: "sparkles"
    )

    /// Sunflower — 黄色 / 橙色。
    static let sunflower = PetalColor(
        id: "sunflower",
        light: Color(red: 0.96, green: 0.74, blue: 0.20),
        dark: Color(red: 0.92, green: 0.75, blue: 0.30),
        icon: "sun.max.fill"
    )

    /// Jasmine — 奶白色。
    static let jasmine = PetalColor(
        id: "jasmine",
        light: Color(red: 0.95, green: 0.93, blue: 0.85),
        dark: Color(red: 0.85, green: 0.82, blue: 0.72),
        icon: "circle.hexagongrid.fill"
    )

    /// Aqua — 青色 / 蓝绿色。
    static let aqua = PetalColor(
        id: "aqua",
        light: Color(red: 0.30, green: 0.74, blue: 0.85),
        dark: Color(red: 0.36, green: 0.78, blue: 0.82),
        icon: "drop.fill"
    )

    /// 默认色（rose）。nil 也回退到它。
    /// Default color (rose). nil resolves to it.
    static let defaultColor = rose

    /// 解析持久化的 id（nil 或未知值都回退到 default）。
    /// Resolve a persisted id; nil or unknown values fall back to the default.
    static func resolve(_ id: String?) -> PetalColor {
        guard let id, let match = all.first(where: { $0.id == id }) else { return defaultColor }
        return match
    }

    /// 本地化显示名（key: `plant.petal.<id>.name`）。
    /// Localized display name (key: `plant.petal.<id>.name`).
    @MainActor
    static func localizedName(for id: String) -> String {
        "plant.petal.\(id).name".localized()
    }
}
