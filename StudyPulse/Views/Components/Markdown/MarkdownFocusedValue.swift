//
//  MarkdownFocusedValue.swift
//  StudyPulse
//
//  Bridges `MarkdownEditorView` (a regular SwiftUI view living
//  inside a sheet or a `NavigationStack`) and the scene-level menu
//  commands attached in `StudyPulseApp`.
//
//  `WindowGroup.commands { … }` is a `Scene`-level modifier, so it
//  cannot capture local `@Binding` values from a child view. SwiftUI
//  solves this with `FocusedValue` / `focusedSceneValue`: a view
//  publishes its current state through a `FocusedValueKey`, and a
//  command reads it back via `@FocusedValue` at fire time.
//
//  The `text` and `selectedRange` are passed as bindings, not
//  snapshots, so the command handler can mutate them and the change
//  propagates back to the editor's `@State` (and from there, into
//  the underlying `UITextView` through `updateUIView`).
//
//  桥接 `MarkdownEditorView`(普通的 SwiftUI 视图,位于 sheet
//  或 NavigationStack 内)和 `StudyPulseApp` 中挂载的场景级菜单命令。
//  WindowGroup.commands 是 Scene 级 modifier,无法捕获子视图的本地
//  @Binding。SwiftUI 用 FocusedValue / focusedSceneValue 解决:
//  视图通过 FocusedValueKey 发布自己的状态,命令在触发时通过
//  @FocusedValue 读回。text 和 selectedRange 以 binding 形式
//  传递而非快照,因此命令可以变更它们,变更会传回编辑器的
//  @State(再经由 updateUIView 进入底层 UITextView)。
//

import SwiftUI

/// Markdown 编辑器文本缓冲区 + 光标的实时句柄,
/// 通过 focusedSceneValue 暴露,让场景级菜单命令能读写。
/// A live handle to the markdown editor's text buffer and cursor,
/// exposed via `focusedSceneValue` so the scene-level menu commands
/// can read and mutate it.
struct MarkdownFormattingContext {
    /// 文本 binding(命令写入后会回流到 MarkdownEditorView 的 @State)
    /// Text binding (writes propagate back into MarkdownEditorView's @State).
    let text: Binding<String>
    /// 光标 / 选择区间 binding
    /// Cursor / selection binding.
    let selectedRange: Binding<NSRange>
}

private struct MarkdownFormattingKey: FocusedValueKey {
    typealias Value = MarkdownFormattingContext
}

extension FocusedValues {
    /// 当前聚焦的 markdown 编辑器的 text + cursor binding,
    /// 当屏幕/焦点中没有 MarkdownEditorView 时为 nil。
    /// The currently focused markdown editor's text + cursor binding,
    /// or `nil` when no `MarkdownEditorView` is on screen / focused.
    var markdownFormatting: MarkdownFormattingContext? {
        get { self[MarkdownFormattingKey.self] }
        set { self[MarkdownFormattingKey.self] = newValue }
    }
}

// MARK: - Editor state notifications
// MARK: - 编辑器状态通知
//
// Format 菜单命令操作的是活跃编辑器的文本缓冲区,它位于
// @FocusedValue 中,可以通过 binding 变更。但 View 菜单命令
//("Toggle Preview"、"Vertical Layout")要变更的是视图级状态
//(isPreviewVisible、forceVertical),这些状态由 MarkdownEditorView
// 持有——没有 binding 可以穿过 FocusedValue。
//
// SwiftUI 中让 Commands body 修改 View 状态的标准方式是发
// Notification,让 View 自己监听。通知名放在这里,生产方
// (MarkdownCommands)和消费方(MarkdownEditorView)共享一份事实来源。
//
// The `Format` menu commands operate on the active editor's text
// buffer, which lives in `@FocusedValue` and can be mutated through
// the binding. But the `View` menu commands ("Toggle Preview",
// "Vertical Layout") mutate *view-level* state owned by
// `MarkdownEditorView` (`isPreviewVisible`, `forceVertical`) — there
// is no binding to pass through `FocusedValue`.
//
// The standard SwiftUI way for a `Commands` body to change a View's
// state is to post a notification and let the View observe it. The
// names live here so the producer (`MarkdownCommands`) and the
// consumer (`MarkdownEditorView`) share a single source of truth.

extension Notification.Name {
    /// `View → Toggle Preview` 菜单命令发送此通知。
    /// MarkdownEditorView 监听后翻转 isPreviewVisible。
    /// Posted by the `View → Toggle Preview` menu command.
    /// `MarkdownEditorView` observes it and flips `isPreviewVisible`.
    static let markdownTogglePreview = Notification.Name("StudyPulse.markdown.togglePreview")
    /// `View → Vertical Layout` 菜单命令发送此通知。
    /// MarkdownEditorView 监听后翻转 forceVertical。
    /// Posted by the `View → Vertical Layout` menu command.
    /// `MarkdownEditorView` observes it and flips `forceVertical`.
    static let markdownToggleVerticalLayout = Notification.Name("StudyPulse.markdown.toggleVerticalLayout")
}
