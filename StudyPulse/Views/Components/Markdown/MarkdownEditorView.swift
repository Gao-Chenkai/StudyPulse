//
//  MarkdownEditorView.swift
//  StudyPulse
//
//  Full Markdown editor with adaptive split layout:
//    - iPhone / iPad compact: top = editor, bottom = preview,
//      split by a draggable horizontal hairline.
//    - iPad regular (landscape, no Split View): left = editor,
//      right = preview, split by a draggable vertical hairline.
//
//  The split direction is determined by `horizontalSizeClass`:
//    .regular → HStack (side-by-side)
//    .compact → VStack (top/bottom)
//
//  In iPadOS 26 windowed mode the top menu bar exposes a
//  `Format` menu (13 markdown formatting actions) and a
//  `View` menu (toggle preview, force vertical layout) wired up
//  in `MarkdownCommands`. The `MarkdownEditorView` publishes
//  itself to those commands via `focusedSceneValue`.
//
//  Draggable divider in both orientations. The "force vertical
//  layout" override lives in `@AppStorage` so it survives
//  dismiss/reopen of the editor sheet.
//
//  完整 Markdown 编辑器,自适应分屏布局:
//  - iPhone / iPad compact:上 = 编辑器,下 = 预览,中间一条可拖动横线分隔。
//  - iPad regular(横屏,未启用 Split View):左 = 编辑器,右 = 预览,中间一条可拖动竖线分隔。
//  分屏方向由 `horizontalSizeClass` 决定。
//

import SwiftUI
import SwiftStreamingMarkdown

// MARK: - Markdown Editor View
// MARK: - Markdown 编辑器视图

/// 完整的 Markdown 编辑体验:编辑器 + 实时预览,
/// iPad 上左右并排,iPhone 上上下堆叠。
/// A complete markdown editing experience: editor + live preview,
/// arranged side-by-side on iPad and stacked top/bottom on iPhone.
struct MarkdownEditorView: View {
    /// 正在编辑的原始 markdown 文本
    /// The raw markdown text being edited.
    @Binding var text: String
    /// 编辑器为空时显示的占位文本
    /// Placeholder text shown when editor is empty.
    var placeholder: String = "Write markdown..."

    /// 当前分屏位置(主轴长度的比例,垂直时为高度,水平时为宽度)。夹紧在 0.2–0.8。
    /// Current split position as fraction of the primary axis
    /// (height for vertical, width for horizontal). Clamped 0.2–0.8.
    @State private var splitFraction: CGFloat = 0.5
    /// 主轴上容器的长度,由 GeometryReader 同步,
    /// 这样拖动偏移可以直接换算成分数,不会有「松手后回弹」的延迟。
    /// The length of the container along the split axis, kept in
    /// sync with `GeometryReader` so drag deltas are translated
    /// into real fractions without a "snap on release" lag.
    @State private var containerLength: CGFloat = 600
    /// 编辑器当前的光标 / 选择区间,以 binding 形式暴露,
    /// 让键盘附件工具栏(以及菜单栏命令)能在光标处插入或包裹选区。
    /// The current cursor / selection in the editor, exposed as a
    /// binding so the keyboard accessory toolbar (and the menu-bar
    /// commands) can insert at the cursor or wrap the selection.
    @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)

    /// 预览面板是否当前显示。由 `View → Toggle Preview` 菜单命令(⌘\\) 翻转。
    /// Whether the preview pane is currently shown. Flipped by the
    /// `View → Toggle Preview` menu command (⌘\\).
    @State private var isPreviewVisible: Bool = true
    /// 即使在 iPad 上也强制使用上下布局。由 `View → Vertical Layout` 菜单命令(⌘⌥L)
    /// 翻转并跨启动持久化。
    /// Force the editor into the top/bottom layout even on iPad.
    /// Flipped by the `View → Vertical Layout` menu command (⌘⌥L)
    /// and persisted across launches.
    @AppStorage("markdown.forceVerticalLayout") private var forceVertical: Bool = false

    /// 分屏方向由 horizontal size class 推导,iPad 的 Split View / Stage Manager
    /// 会自动回退到 compact(上下)布局。
    /// The split direction is derived from the horizontal size class
    /// so Split View / Stage Manager on iPad automatically falls
    /// back to the compact (top/bottom) layout.
    @Environment(\.horizontalSizeClass) private var hSize

    /// 编辑器是否使用左右并排布局。false = 上下堆叠。
    /// True when the editor should lay out editor + preview
    /// side-by-side. False = stack them top/bottom.
    private var usesSideBySide: Bool {
        hSize == .regular && !forceVertical
    }

    var body: some View {
        GeometryReader { geometry in
            Group {
                if usesSideBySide {
                    HStack(spacing: 0) {
                        editorPane
                            .frame(width: max(160, primaryLength(in: geometry.size)))
                        verticalDivider
                        previewPane
                            .frame(width: max(160, secondaryLength(in: geometry.size)))
                    }
                } else {
                    VStack(spacing: 0) {
                        editorPane
                            .frame(height: max(120, primaryLength(in: geometry.size)))
                        horizontalDivider
                        if isPreviewVisible {
                            previewPane
                                .frame(height: max(120, secondaryLength(in: geometry.size)))
                        }
                    }
                }
            }
            .onAppear {
                updateContainerLength(for: geometry.size)
            }
            .onChange(of: geometry.size) { _, newSize in
                updateContainerLength(for: newSize)
            }
            .onChange(of: isPreviewVisible) { _, visible in
                // 上下布局下隐藏预览时,让编辑器占满高度,让分隔线计算保持合理。
                // When the preview is hidden in the vertical layout,
                // give the editor the full height for the divider
                // math to stay sensible.
                if !usesSideBySide && !visible {
                    splitFraction = 1.0
                } else if splitFraction > 0.95 {
                    splitFraction = 0.5
                }
            }
        }
        // 把编辑器的 text + cursor 发布到场景级菜单命令(`MarkdownCommands`)。
        // 当焦点切换到另一个编辑器时,SwiftUI 重新评估此视图,
        // focused value 同步更新,菜单命令自动指向新编辑器。
        // Publish the editor's text + cursor to the scene-level
        // menu commands (`MarkdownCommands`). When a different
        // editor takes focus, SwiftUI re-evaluates this view, the
        // focused value updates, and the menu commands point at
        // the new editor automatically.
        .focusedSceneValue(\.markdownFormatting, context)
        // 监听 View 菜单命令:这些命令通过 NotificationCenter 通知,
        // 因为 view 级状态没有 binding 可以穿过 FocusedValue 传递。
        // Listen for the `View` menu commands, which post these
        // notifications because there is no binding to pass
        // through `FocusedValue` for view-level state.
        .onReceive(NotificationCenter.default.publisher(for: .markdownTogglePreview)) { _ in
            isPreviewVisible.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .markdownToggleVerticalLayout)) { _ in
            // 设备已经是 compact 时该切换是空操作(iPhone 上没什么可切)。
            // The toggle is a no-op when the device is already
            // compact — there is nothing to switch to on iPhone.
            guard hSize == .regular else { return }
            forceVertical.toggle()
        }
    }

    // MARK: - Context for menu commands
    // MARK: - 菜单命令的 context

    /// 交给 Format 菜单命令的实时 binding。每次渲染都重新计算,
    /// 保证 binding 永远指向当前的 @State 存储。
    /// Live bindings handed to the `Format` menu commands. Recomputed
    /// on every render so the bindings always point at the current
    /// `@State` storage.
    private var context: MarkdownFormattingContext {
        MarkdownFormattingContext(
            text: $text,
            selectedRange: $selectedRange
        )
    }

    // MARK: - Editor Pane
    // MARK: - 编辑面板

    private var editorPane: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(Color(.placeholderText))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }
            // 使用光标感知的 `MarkdownTextEditor`(UITextView 包装),
            // 而不是系统 SwiftUI `TextEditor`,以便 markdown 键盘附件
            // 能在真实光标位置插入 / 包裹。
            // Use the cursor-aware `MarkdownTextEditor` (a `UITextView`
            // wrapper) instead of the stock SwiftUI `TextEditor` so the
            // markdown keyboard accessory can insert / wrap at the
            // actual cursor position.
            MarkdownTextEditor(text: $text, selectedRange: $selectedRange)
                .font(.body)
        }
        // 不填背景色,让父层(Form Section 的卡片)透出来,
        // 这样编辑器、分隔线、预览都是同一种连续颜色,中间没有可见的"色块"。
        // No background fill — let the parent (Form Section's card)
        // show through so the editor, divider, and preview are all
        // the same continuous colour with no visible "block"
        // between them.
    }

    // MARK: - Dividers
    // MARK: - 分隔线
    //
    // 两个视觉上相同的 0.5pt 细线,各负责一个方向。
    // 每个都包在 12pt 的隐形触摸目标里,提供宽松的抓取区。
    // 拖动时在 onChanged 中更新 splitFraction,让面板实时跟随手指。
    //
    // Two visually identical 0.5pt hairlines, one for each axis.
    // Each is wrapped in a 12pt invisible touch target so the user
    // has a generous grab zone. Drag updates `splitFraction` in
    // `onChanged` so the panes follow the finger in real time.

    private var horizontalDivider: some View {
        ZStack {
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .frame(height: 12)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let total = containerLength
                            guard total > 0 else { return }
                            let raw = splitFraction + value.translation.height / total
                            // 分屏比例夹紧在 0.2 ~ 0.95
                            // Split fraction clamped to 0.2 ~ 0.95.
                            splitFraction = min(0.95, max(0.2, raw))
                        }
                )
            Rectangle()
                .fill(Color.primary.opacity(0.18))
                .frame(height: 0.5)
        }
    }

    private var verticalDivider: some View {
        ZStack {
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .frame(width: 12)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let total = containerLength
                            guard total > 0 else { return }
                            let raw = splitFraction + value.translation.width / total
                            // 分屏比例夹紧在 0.2 ~ 0.8(水平方向给预览留更多空间)
                            // Split fraction clamped to 0.2 ~ 0.8 (give preview more room horizontally).
                            splitFraction = min(0.8, max(0.2, raw))
                        }
                )
            Rectangle()
                .fill(Color.primary.opacity(0.18))
                .frame(width: 0.5)
        }
    }

    // MARK: - Preview Pane
    // MARK: - 预览面板

    private var previewPane: some View {
        MarkdownPreviewView(text: text)
            .overlay(alignment: .topTrailing) {
                // 右上角小标签:Preview
                // Small label indicating preview
                Text("Preview")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
            }
    }

    // MARK: - Length Calculations
    // MARK: - 长度计算

    private func updateContainerLength(for size: CGSize) {
        containerLength = max(usesSideBySide ? size.width : size.height, 200)
    }

    private func primaryLength(in size: CGSize) -> CGFloat {
        let total = usesSideBySide ? size.width : size.height
        return total * splitFraction
    }

    private func secondaryLength(in size: CGSize) -> CGFloat {
        let total = usesSideBySide ? size.width : size.height
        return total * (1 - splitFraction)
    }
}

// MARK: - Compact Editor (single-line mode)
// MARK: - 紧凑编辑器(单行模式)

/// 适用于内联 / 表单的紧凑 Markdown 编辑器。
/// 显示一个 TextEditor,可点击展开为完整的 MarkdownEditorView(sheet)。
/// A compact Markdown editor suited for inline / form use.
/// Shows a TextEditor that expands into a full MarkdownEditorView via sheet.
struct CompactMarkdownEditorView: View {
    @Binding var text: String
    var title: String = "Content"
    @State private var showFullEditor = false
    /// 是否显示完整编辑器 sheet
    /// Whether the full editor sheet is presented.

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    showFullEditor = true
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption)
                }
            }

            Text(text.isEmpty ? "Tap to edit..." : text)
                .font(.callout)
                .foregroundColor(text.isEmpty ? .secondary : .primary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(8)
                .onTapGesture {
                    showFullEditor = true
                }
        }
        .sheet(isPresented: $showFullEditor) {
            fullEditorSheet
        }
    }

    private var fullEditorSheet: some View {
        NavigationStack {
            MarkdownEditorView(text: $text, placeholder: "Write in markdown...")
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showFullEditor = false
                        }
                        .fontWeight(.semibold)
                    }
                }
        }
    }
}

// MARK: - Preview
// MARK: - 预览

#Preview("Markdown Editor") {
    @Previewable @State var text = """
    # Physics Problem

    A ball is thrown upward with initial velocity $v_0 = 20\\ \\text{m/s}$.

    ## Given
    - $g = 9.8\\ \\text{m/s}^2$
    - $v_0 = 20\\ \\text{m/s}$

    ## Formula
    $$
    h_{\\max} = \\frac{v_0^2}{2g}
    $$

    ## Answer
    $h_{\\max} = \\frac{400}{19.6} \\approx 20.4\\ \\text{m}$

    > Remember: always check units!

    ---

    ### Steps
    1. Write the kinematic equation
    2. Substitute known values
    3. Solve for $h_{\\max}$

    ### Check
    - [x] Units consistent
    - [ ] Round correctly
    """
    MarkdownEditorView(text: $text, placeholder: "Describe the mistake...")
}

#Preview("Compact Editor") {
    @Previewable @State var text = "Some markdown **content** here"
    CompactMarkdownEditorView(text: $text, title: "Error Reason")
        .padding()
}
