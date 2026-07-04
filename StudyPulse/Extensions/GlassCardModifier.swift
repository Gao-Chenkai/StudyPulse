//
//  GlassCardModifier.swift
//  StudyPulse
//
//  玻璃效果修饰符：iOS 26+ 使用系统 `glassEffect`，老版本 fallback 到 `.regularMaterial`。
//  默认关闭（由 AppEnvironmentManager.glassEffectEnabled 控制）。
//
//  用法：把卡片原本的 `.background(RoundedRectangle.fill(...))` 替换为
//  `.glassCard(enabled: envManager.glassEffectEnabled, cornerRadius: 18)`。
//  - 关闭时：保留 `Color(.secondarySystemGroupedBackground)` 白底（视觉与原版一致）
//  - 开启时：iOS 26+ 用系统 `glassEffect`，老版本回退到 `.regularMaterial`
//

import SwiftUI

/// 玻璃卡片背景：iOS 26+ 用 `glassEffect`，老版本用 `.regularMaterial`。
struct GlassCardBackground: View {
    var cornerRadius: CGFloat = 18
    var style: GlassStyle = .regular

    enum GlassStyle {
        case regular
        case clear
    }

    var body: some View {
        if #available(iOS 26, *) {
            // 必须作用在透明画布（`Color.clear`）上，再通过 `in:` 传入形状；
            // 直接给形状调 `glassEffect` 会得到几乎不透明的大色块。
            Color.clear
                .glassEffect(
                    style == .regular ? .regular : .clear,
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.regularMaterial)
        }
    }
}

extension View {
    /// 把当前视图作为玻璃卡片渲染（替换原本的卡片背景）。
    /// - Parameters:
    ///   - enabled: 开关；通常传 `envManager.glassEffectEnabled`。
    ///   - cornerRadius: 卡片圆角。
    ///   - style: 玻璃样式（regular / clear）。
    func glassCard(enabled: Bool, cornerRadius: CGFloat = 18, style: GlassCardBackground.GlassStyle = .regular) -> some View {
        modifier(GlassCardModifier(enabled: enabled, cornerRadius: cornerRadius, style: style))
    }
}

/// 条件性包装：开启时把背景替换为 `GlassCardBackground`（iOS 26 glassEffect / 旧版 material）；
/// 关闭时仍然要保留原本的「二级分组背景」，否则卡片会变成透明。
private struct GlassCardModifier: ViewModifier {
    let enabled: Bool
    let cornerRadius: CGFloat
    let style: GlassCardBackground.GlassStyle

    func body(content: Content) -> some View {
        if enabled {
            content.background(GlassCardBackground(cornerRadius: cornerRadius, style: style))
        } else {
            // 关闭玻璃效果：保留原本 `Color(.secondarySystemGroupedBackground)` 白底，
            // 这样替换原 `.background(.fill(...))` 后视觉一致。
            content.background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }
}
