//
//  ReportRenderer.swift
//  StudyPulse
//
//  Bridges SwiftUI views to UIImage using iOS 16+'s `ImageRenderer`.
//  Used by the report / single-card share flows.
//
//  单卡分享的坑 / Known issues fixed here:
//  1. iOS 26 `glassEffect` 在 `ImageRenderer` 渲染管线里会变成几乎透明的
//     `Color.clear`,导致卡片发灰。 → 调用方在传入前用 `.exportMode(true)`
//     注入,卡片内部用纯色背景绕开。
//  2. `Menu` / SwiftUI 内部系统资源在 ImageRenderer 里会渲染成"黄底红禁止"
//     占位符。 → 调用方在传入前用 `.exportMode(true)` 注入,卡片内部用纯文本
//     替身绕开(例如 TrendChartCard 的焦点规则选择器)。
//  3. `proposedSize = (width, nil)` 对复杂 VStack(多行建议 + LLMCallIndicator
//     + Stats)经常渲染出截断的高度。 → 先用 `UIHostingController.sizeThatFits`
//     量出真实高度,再传给 ImageRenderer 用具体尺寸渲染。
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// 把 SwiftUI 视图渲染为 UIImage。共享 `ImageRenderer` 配方。
/// Render a SwiftUI view into a UIImage. Centralised so the share
/// flows (full report + single card) share the same recipe.
@MainActor
enum ReportRenderer {

    /// 默认 A4 宽度（pt）。612 = 8.5 inch × 72 dpi 减去 24pt 边距后留出 padding。
    /// Default A4-ish width in points.
    static let defaultWidth: CGFloat = 612

    /// 渲染 SwiftUI 视图为 UIImage。返回 nil 时表示渲染失败。
    /// Render the given SwiftUI view to a UIImage.
    /// - Parameters:
    ///   - view: 要渲染的 SwiftUI 视图。建议外部已 `.exportMode(true)` 注入,
    ///           以及 `.frame(width: ReportRenderer.defaultWidth)` 限定宽度。
    ///   - scale: 缩放比例（默认 2.0 = 视网膜屏近似 144 dpi 打印品质）。
    static func render<Content: View>(
        _ view: Content,
        scale: CGFloat = 2.0
    ) -> UIImage? {
        // 1) 先用 UIHostingController 在目标宽度上做 sizeThatFits,量出真实高度。
        //    对复杂 VStack / LazyVStack 直接给 ImageRenderer 传
        //    (width, nil) 经常只返回"首屏高度",导致学习建议/趋势图被截断。
        //    Use UIHostingController.sizeThatFits at the target width to get the
        //    real height. Passing (width, nil) directly to ImageRenderer often
        //    only returns the "first screen" height, truncating complex cards.
        let targetWidth = defaultWidth
        let host = UIHostingController(rootView: view)
        let measured = host.sizeThatFits(
            in: CGSize(width: targetWidth, height: .greatestFiniteMagnitude)
        )
        let targetHeight = max(measured.height, 1)

        // 2) 用 ImageRenderer 渲染,使用量出的精确尺寸避免内容被截断。
        //    ImageRenderer is the iOS 16+ SwiftUI → UIImage bridge.
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        renderer.proposedSize = ProposedViewSize(width: targetWidth, height: targetHeight)
        renderer.isOpaque = true
        guard let image = renderer.uiImage else {
            // 渲染失败打 error 日志(常见于含 zero-size 子视图的 layout)
            // Log on render failure (often caused by zero-size subviews).
            Log.record(.error, category: "Export", message: "学习报告渲染失败 / Report render returned nil image target=\(Int(targetWidth))x\(Int(targetHeight))")
            return nil
        }
        return image
    }

    /// Render a view at an explicit size, for content-sized canvas exports.
    static func render<Content: View>(
        _ view: Content,
        size: CGSize,
        scale: CGFloat = 2.0
    ) -> UIImage? {
        let targetSize = CGSize(width: max(size.width, 1), height: max(size.height, 1))
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        renderer.proposedSize = ProposedViewSize(width: targetSize.width, height: targetSize.height)
        renderer.isOpaque = true
        return renderer.uiImage
    }

    /// 把 UIImage 编码为 PNG / JPEG Data。
    /// Encode UIImage to PNG / JPEG.
    static func encode(_ image: UIImage, format: ReportImageFormat, jpegQuality: CGFloat = 0.9) -> Data? {
        switch format {
        case .png:
            return image.pngData()
        case .jpeg:
            return image.jpegData(compressionQuality: max(0.1, min(1.0, jpegQuality)))
        }
    }
}

/// 输出格式。
/// Output format for the generated report image.
enum ReportImageFormat: String, CaseIterable, Sendable {
    case png
    case jpeg

    var fileExtension: String {
        switch self {
        case .png: return "png"
        case .jpeg: return "jpg"
        }
    }

    var utType: UTType {
        switch self {
        case .png: return .png
        case .jpeg: return .jpeg
        }
    }
}
