//
//  ExportModeEnvironment.swift
//  StudyPulse
//
//  当 SwiftUI 视图正在被 `ImageRenderer` 渲染为导出图片时,允许子 View 知道。
//  Allows subviews to know they're being rasterised for export by `ImageRenderer`.
//
//  用法 / Usage:
//      - HomeView.renderAndShareSingleCard / generateReport 在传给
//        ReportRenderer.render 前注入 `.environment(\.exportMode, true)`
//      - 卡片修饰符(`.cardSkin(...)` / 内部 Menu)在 export 模式下:
//          * 用纯白/纯色 opaque 背景代替 glassEffect(避免 iOS 26 glass
//            在 ImageRenderer 渲染管线里变透明导致发灰)
//          * 跳过交互组件(`.menu` 系统指示器)避免在导出图里出现
//            "黄底红禁止"占位符
//

import SwiftUI

/// 导出模式开关：true 表示视图正在被 `ImageRenderer` 截图。
/// Export mode flag: true means the view is being rasterised by `ImageRenderer`.
private struct ExportModeKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    /// 当前视图是否处于"导出图片"模式。
    /// Whether the current view is in "image export" mode.
    var exportMode: Bool {
        get { self[ExportModeKey.self] }
        set { self[ExportModeKey.self] = newValue }
    }
}

extension View {
    /// 标记当前子树为"导出模式":子 View 会用非 glass / 非交互的占位元素
    /// 渲染,保证 `ImageRenderer` 截图清晰。
    /// Mark the subtree as "export mode": child views render with non-glass /
    /// non-interactive placeholders so `ImageRenderer` produces a clean image.
    func exportMode(_ enabled: Bool = true) -> some View {
        environment(\.exportMode, enabled)
    }
}
