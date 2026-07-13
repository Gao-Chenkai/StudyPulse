//
//  iPadLayout.swift
//  StudyPulse
//
//  iPad 自适应布局工具集。
//  为 iPhone 和 iPad 提供一致且优雅的自适应布局体验。
//  iPad adaptive-layout helpers — provide a consistent and
//  tasteful experience on both iPhone and iPad.
//

import SwiftUI

// MARK: - 设备判断
// MARK: - Device Detection

/// 当前设备是否为 iPad
/// Whether the current device is an iPad.
var isIPad: Bool {
    UIDevice.current.userInterfaceIdiom == .pad
}

// MARK: - 内容最大宽度
// MARK: - Adaptive Content Width

/// 让内容在 iPad 等大屏设备上居中并限制最大宽度,避免被拉得过长。
/// 推荐用于:表单页、设置页、单列长内容。
/// Centers the content on iPad-class screens and clamps it to a
/// maximum width so it doesn't stretch out.
struct AdaptiveContentWidth: ViewModifier {
    /// iPad 下的最大宽度。可根据内容密度微调。
    /// iPad maximum width. Tune to match the content density.
    var maxWidth: CGFloat = 720
    @Environment(\.horizontalSizeClass) private var sizeClass

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: sizeClass == .regular ? maxWidth : .infinity)
            .frame(maxWidth: .infinity) // 居中 / center
    }
}

extension View {
    /// 限制内容最大宽度(仅在大屏生效),并自动居中
    /// - Parameter maxWidth: iPad 下的最大宽度
    /// Clamp content to a maximum width (large screens only) and center it.
    /// - Parameter maxWidth: iPad maximum width.
    func adaptiveMaxWidth(_ maxWidth: CGFloat = 720) -> some View {
        modifier(AdaptiveContentWidth(maxWidth: maxWidth))
    }
}

// MARK: - 多列网格列数
// MARK: - Adaptive Grid Columns

/// iPad 下的自适应网格列数
/// - iPhone(compact):1 列
/// - iPad(regular):给定列数(默认 2)
/// Adaptive grid column count.
/// - iPhone (compact): 1 column.
/// - iPad (regular): configurable (default 2).
struct AdaptiveGridColumns {
    let columns: [GridItem]

    init(compact: Int = 1, regular: Int = 2, spacing: CGFloat = 20) {
        let count = isIPad ? regular : compact
        self.columns = Array(
            repeating: GridItem(.flexible(), spacing: spacing),
            count: max(1, count)
        )
    }
}

// MARK: - 双列 HStack 包装
// MARK: - Adaptive HStack (two-column)

/// 在 iPad 常规宽度下水平并排显示两块内容;iPhone 仍然竖直堆叠。
/// On iPad regular width, lays two blocks side-by-side; on iPhone
/// they remain vertically stacked.
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
// MARK: - Adaptive Card Padding

/// 统一外层 padding:iPhone 横向 20pt;iPad 横向 0(由 maxWidth 容器统一管理)。
/// Unified outer padding: 20pt horizontal on iPhone, none on iPad
/// (the maxWidth container handles the iPad margins).
struct AdaptiveCardPadding: ViewModifier {
    @Environment(\.horizontalSizeClass) private var sizeClass

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, sizeClass == .regular ? 0 : 20)
    }
}

extension View {
    /// iPhone 横向 20pt 留白,iPad 不留白(由 maxWidth 容器负责边距)
    /// 20pt horizontal padding on iPhone; none on iPad (the maxWidth container manages the margins).
    func adaptiveCardPadding() -> some View {
        modifier(AdaptiveCardPadding())
    }
}

// MARK: - Form 自适应宽度
// MARK: - Adaptive Form Width

/// 为 Form 视图添加 iPad 自适应最大宽度和居中效果。
/// 推荐用于所有基于 Form 的 Sheet 视图。
/// Add an iPad-adaptive maximum width and centering for Form views.
/// Recommended for all Form-based sheet views.
struct AdaptiveFormModifier: ViewModifier {
    var maxWidth: CGFloat
    @Environment(\.horizontalSizeClass) private var sizeClass

    func body(content: Content) -> some View {
        if sizeClass == .regular {
            content
                .frame(maxWidth: maxWidth)
                .frame(maxWidth: .infinity)
        } else {
            content
        }
    }
}

extension View {
    /// iPad 下端 Form 的自适应宽度与居中
    /// - Parameter maxWidth: iPad 下的最大宽度,默认 680
    /// Apply iPad-adaptive max width + centering to a Form.
    /// - Parameter maxWidth: iPad maximum width, default 680.
    func adaptiveForm(maxWidth: CGFloat = 680) -> some View {
        modifier(AdaptiveFormModifier(maxWidth: maxWidth))
    }
}

// MARK: - Sheet 展示尺寸控制
// MARK: - Sheet Sizing

/// iPad-friendly sheet sizing with configurable detents.
/// On iPad (regular size class), applies presentationDetents and drag indicator;
/// on iPhone, passes through unchanged.
extension View {
    /// 默认 .large detent 的 iPad 友好 sheet。
    /// Apply iPad-friendly sheet sizing with default `.large` detent.
    func adaptiveSheet() -> some View {
        self.modifier(AdaptiveSheetModifier())
    }

    /// 自定义 detent 的 iPad 友好 sheet。
    /// Apply iPad-friendly sheet sizing with custom detents.
    func adaptiveSheet(detents: Set<PresentationDetent> = [.large], selection: Binding<PresentationDetent>? = nil) -> some View {
        self.modifier(AdaptiveSheetModifier(detents: detents, selection: selection))
    }
}

private struct AdaptiveSheetModifier: ViewModifier {
    var detents: Set<PresentationDetent> = [.large]
    var selection: Binding<PresentationDetent>? = nil
    @Environment(\.horizontalSizeClass) private var sizeClass

    func body(content: Content) -> some View {
        if sizeClass == .regular {
            if let selection {
                content
                    .presentationDetents(detents, selection: selection)
                    .presentationDragIndicator(.visible)
            } else {
                content
                    .presentationDetents(detents)
                    .presentationDragIndicator(.visible)
            }
        } else {
            content
        }
    }
}

// MARK: - Pointer Hover Support
// MARK: - Pointer Hover Support

/// Button style that responds to iPad pointer/trackpad hover with a visual highlight.
struct HoverableButtonStyle: ButtonStyle {
    var hoverScale: CGFloat = 1.02
    var hoverOpacity: Double = 0.85

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

/// View modifier that applies a subtle hover highlight for iPad pointer.
struct HoverHighlightModifier: ViewModifier {
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .brightness(isHovering ? 0.04 : 0)
            .scaleEffect(isHovering ? 1.01 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHovering)
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

extension View {
    /// Subtle highlight on iPad pointer hover — useful for tappable cards and list rows.
    func hoverHighlight() -> some View {
        modifier(HoverHighlightModifier())
    }
}
