//
//  iPadLayout.swift
//  StudyPulse
//
//  iPad 适配布局辅助工具
//

import SwiftUI

// MARK: - 设备/尺寸判断

// 注：horizontalSizeClass 仅在 View body 内可直接读取，
// 其他位置请使用 @Environment(\.horizontalSizeClass) 自行注入。

// MARK: - 内容最大宽度

/// 让内容在 iPad 等大屏设备上居中并限制最大宽度，避免被拉得过长。
/// 推荐用于：表单页、设置页、单列长内容。
struct AdaptiveContentWidth: ViewModifier {
    /// iPad 下的最大宽度。可根据内容密度微调。
    var maxWidth: CGFloat = 720
    @Environment(\.horizontalSizeClass) private var sizeClass

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: sizeClass == .regular ? maxWidth : .infinity)
            .frame(maxWidth: .infinity) // 居中
    }
}

extension View {
    /// 限制内容最大宽度（仅在大屏生效），并自动居中
    /// - Parameter maxWidth: iPad 下的最大宽度
    func adaptiveMaxWidth(_ maxWidth: CGFloat = 720) -> some View {
        modifier(AdaptiveContentWidth(maxWidth: maxWidth))
    }
}

// MARK: - 多列网格列数

/// iPad 下的自适应网格列数
/// - iPhone（compact）：1 列
/// - iPad（regular）：给定列数（默认 2）
struct AdaptiveGridColumns {
    let columns: [GridItem]

    init(compact: Int = 1, regular: Int = 2, spacing: CGFloat = 20) {
        let count = UIDevice.current.userInterfaceIdiom == .pad ? regular : compact
        self.columns = Array(
            repeating: GridItem(.flexible(), spacing: spacing),
            count: max(1, count)
        )
    }
}

// MARK: - 双列 HStack 包装

/// 在 iPad 常规宽度下水平并排显示两块内容；iPhone 仍然竖直堆叠。
struct AdaptiveHStack<Content: View>: View {
    let spacing: CGFloat
    let content: () -> Content
    @Environment(\.horizontalSizeClass) private var sizeClass

    init(spacing: CGFloat = 20, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        if sizeClass == .regular {
            HStack(alignment: .top, spacing: spacing) {
                content()
            }
        } else {
            VStack(alignment: .leading, spacing: spacing) {
                content()
            }
        }
    }
}

// MARK: - 卡片外层留白统一

/// 统一外层 padding：iPhone 横向 20pt；iPad 横向 0（由 maxWidth 容器统一管理）。
struct AdaptiveCardPadding: ViewModifier {
    @Environment(\.horizontalSizeClass) private var sizeClass

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, sizeClass == .regular ? 0 : 20)
    }
}

extension View {
    /// iPhone 横向 20pt 留白，iPad 不留白（由 maxWidth 容器负责边距）。
    func adaptiveCardPadding() -> some View {
        modifier(AdaptiveCardPadding())
    }
}
