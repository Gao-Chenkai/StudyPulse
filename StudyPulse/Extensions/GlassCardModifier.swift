//  GlassCardModifier.swift
//  StudyPulse
//
//  玻璃效果修饰符:iOS 26+ 用系统 `glassEffect`;老版本 fallback `.regularMaterial`。
//  Glass-effect modifier: iOS 26+ uses system `glassEffect`; older falls back to `.regularMaterial`.
//  默认关闭(由 AppEnvironmentManager.glassEffectEnabled 控制)。
//  Disabled by default (toggled by AppEnvironmentManager.glassEffectEnabled).
//

import SwiftUI

/// 玻璃卡片背景 / Glass card background.
struct GlassCardBackground: View {
    var cornerRadius: CGFloat = 18  // 卡片圆角 / Card corner radius.
    var style: GlassStyle = .regular  // 玻璃样式 / Glass style.

    /// 玻璃样式 / Glass style options.
    enum GlassStyle {
        case regular  // 标准 / Standard glass.
        case clear  // 透明 / Clear glass (more lightweight).
    }

    var body: some View {
        if #available(iOS 26, *) {
            // 必须作用在透明画布(`Color.clear`)上 + `in:` 传入形状;
            // 直接给形状调 `glassEffect` 会得到几乎不透明的大色块。
            // Apply to a transparent canvas (`Color.clear`) with shape via `in:`;
            // applying `glassEffect` directly to the shape yields a near-opaque block.
            Color.clear
                .glassEffect(
                    style == .regular ? .regular : .clear,
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
        } else {
            // iOS 26 之前没有 glassEffect,regularMaterial 兜底 / Pre-iOS 26 fallback.
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.regularMaterial)
        }
    }
}

extension View {
    /// 把当前视图作为玻璃卡片渲染(替换原本的卡片背景)/ Render as a glass card.
    func glassCard(enabled: Bool, cornerRadius: CGFloat = 18, style: GlassCardBackground.GlassStyle = .regular) -> some View {
        modifier(GlassCardModifier(enabled: enabled, cornerRadius: cornerRadius, style: style))
    }
}

/// 条件性包装:开启时把背景替换为 `GlassCardBackground`,关闭时保留原"二级分组背景"。
/// Conditional wrapper: when enabled, replaces background with `GlassCardBackground`.
private struct GlassCardModifier: ViewModifier {
    let enabled: Bool  // 是否启用 / Whether the glass effect is enabled.
    let cornerRadius: CGFloat  // 卡片圆角 / Card corner radius.
    let style: GlassCardBackground.GlassStyle  // 玻璃样式 / Glass style.

    func body(content: Content) -> some View {
        if enabled {
            content.background(GlassCardBackground(cornerRadius: cornerRadius, style: style))
        } else {
            content.background(  // 保留 `secondarySystemGroupedBackground` 白底 / Keep the original background.
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }
}
