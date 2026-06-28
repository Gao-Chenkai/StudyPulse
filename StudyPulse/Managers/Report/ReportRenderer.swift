//
//  ReportRenderer.swift
//  StudyPulse
//
//  Bridges SwiftUI views to UIImage using iOS 16+'s `ImageRenderer`.
//  Used by the report / single-card share flows.
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
    ///   - view: 要渲染的 SwiftUI 视图。建议外部已 `.frame(width:)`。
    ///   - scale: 缩放比例（默认 2.0 = 视网膜屏近似 144 dpi 打印品质）。
    static func render<Content: View>(
        _ view: Content,
        scale: CGFloat = 2.0
    ) -> UIImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        renderer.proposedSize = .init(width: defaultWidth, height: nil)
        renderer.isOpaque = true
        guard let image = renderer.uiImage else {
            Log.record(.error, category: "Export", message: "学习报告渲染失败 / Report render returned nil image")
            return nil
        }
        return image
    }

    /// 把 UIImage 编码为 PNG / JPEG Data。
    /// Encode UIImage to PNG or JPEG.
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
