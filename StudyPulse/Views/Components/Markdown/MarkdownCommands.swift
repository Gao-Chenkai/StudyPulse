//
//  MarkdownCommands.swift
//  StudyPulse
//
//  Scene-level menu commands that surface the markdown editor's
//  formatting actions in the iPadOS 26 windowed-mode menu bar (and
//  as keyboard shortcuts whenever a hardware keyboard is attached).
//
//  Attached to the `WindowGroup` in `StudyPulseApp`:
//
//      WindowGroup { … }
//          .commands { MarkdownCommands() }
//
//  The commands read the currently focused `MarkdownEditorView`'s
//  text + cursor from `@FocusedValue(\.markdownFormatting)`. When
//  no editor is on screen (or focused) the entire menu is omitted
//  via `if ctx != nil`, so the menu bar stays uncluttered in the
//  rest of the app.
//
//  `@FocusedValue` in a `Commands` body re-evaluates whenever the
//  focused value changes, so the `ctx` captured by each `Button`
//  action closure is always the live, current one — no need to
//  re-read it at fire time.
//
//  场景级菜单命令:在 iPadOS 26 窗口化模式的菜单栏(以及
//  连接硬件键盘时的快捷键)里暴露 markdown 编辑器的格式化操作。
//  在 StudyPulseApp 的 WindowGroup 上通过 .commands 挂载。
//

import SwiftUI

/// 场景级菜单:把 MarkdownEditorView 的格式化动作暴露到菜单栏 / 键盘快捷键。
/// Scene-level menu: expose the MarkdownEditorView's formatting actions to the menu bar / keyboard shortcuts.
struct MarkdownCommands: Commands {
    /// 当前聚焦的 MarkdownEditorView 的 text + cursor 绑定
    /// Text + cursor bindings of the currently focused MarkdownEditorView.
    @FocusedValue(\.markdownFormatting) private var ctx

    var body: some Commands {
        if let ctx {
            formatMenu(ctx: ctx)
            viewMenu
        }
    }

    // MARK: - Format
    // MARK: - 格式菜单

    private func formatMenu(ctx: MarkdownFormattingContext) -> some Commands {
        CommandMenu("markdown.menu.format".localized()) {
            Button("markdown.cmd.bold".localized()) { ctx.mutate { MarkdownFormatting.wrap(prefix: "**", suffix: "**", placeholder: "bold", into: &$0, range: &$1) } }
                .keyboardShortcut("b", modifiers: .command)
            Button("markdown.cmd.italic".localized()) { ctx.mutate { MarkdownFormatting.wrap(prefix: "*", suffix: "*", placeholder: "italic", into: &$0, range: &$1) } }
                .keyboardShortcut("i", modifiers: .command)

            Divider()

            Button("markdown.cmd.h1".localized()) { ctx.mutate { MarkdownFormatting.insertLinePrefix("# ", into: &$0, range: &$1) } }
                .keyboardShortcut("1", modifiers: .command)
            Button("markdown.cmd.h2".localized()) { ctx.mutate { MarkdownFormatting.insertLinePrefix("## ", into: &$0, range: &$1) } }
                .keyboardShortcut("2", modifiers: .command)
            Button("markdown.cmd.h3".localized()) { ctx.mutate { MarkdownFormatting.insertLinePrefix("### ", into: &$0, range: &$1) } }
                .keyboardShortcut("3", modifiers: .command)
            Button("markdown.cmd.h4".localized()) { ctx.mutate { MarkdownFormatting.insertLinePrefix("#### ", into: &$0, range: &$1) } }
                .keyboardShortcut("4", modifiers: .command)
            Button("markdown.cmd.h5".localized()) { ctx.mutate { MarkdownFormatting.insertLinePrefix("##### ", into: &$0, range: &$1) } }
                .keyboardShortcut("5", modifiers: .command)
            Button("markdown.cmd.h6".localized()) { ctx.mutate { MarkdownFormatting.insertLinePrefix("###### ", into: &$0, range: &$1) } }
                .keyboardShortcut("6", modifiers: .command)

            Divider()

            Button("markdown.cmd.bulletList".localized()) { ctx.mutate { MarkdownFormatting.insertLinePrefix("- ", into: &$0, range: &$1) } }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            Button("markdown.cmd.numberedList".localized()) { ctx.mutate { MarkdownFormatting.insertLinePrefix("1. ", into: &$0, range: &$1) } }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            Button("markdown.cmd.checklist".localized()) { ctx.mutate { MarkdownFormatting.insertLinePrefix("- [ ] ", into: &$0, range: &$1) } }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            Button("markdown.cmd.quote".localized()) { ctx.mutate { MarkdownFormatting.insertLinePrefix("> ", into: &$0, range: &$1) } }
                .keyboardShortcut("q", modifiers: [.command, .shift])

            Divider()

            Button("markdown.cmd.inlineCode".localized()) { ctx.mutate { MarkdownFormatting.wrap(prefix: "`", suffix: "`", placeholder: "code", into: &$0, range: &$1) } }
                .keyboardShortcut("e", modifiers: .command)
            Button("markdown.cmd.codeBlock".localized()) { ctx.mutate { MarkdownFormatting.insertBlock(prefix: "```\n", suffix: "\n```", placeholder: "code", into: &$0, range: &$1) } }
                .keyboardShortcut("c", modifiers: [.command, .option])
            Button("markdown.cmd.inlineMath".localized()) { ctx.mutate { MarkdownFormatting.wrap(prefix: "$", suffix: "$", placeholder: "x", into: &$0, range: &$1) } }
                .keyboardShortcut("m", modifiers: .command)
            Button("markdown.cmd.blockMath".localized()) { ctx.mutate { MarkdownFormatting.insertBlock(prefix: "$$\n", suffix: "\n$$", placeholder: "x", into: &$0, range: &$1) } }
                .keyboardShortcut("m", modifiers: [.command, .option])

            Divider()

            Button("markdown.cmd.link".localized()) { ctx.mutate { MarkdownFormatting.wrap(prefix: "[", suffix: "](url)", placeholder: "text", into: &$0, range: &$1) } }
                .keyboardShortcut("k", modifiers: .command)
            Button("markdown.cmd.divider".localized()) { ctx.mutate { MarkdownFormatting.insertAtCursor("\n---\n", into: &$0, range: &$1) } }
                .keyboardShortcut("h", modifiers: [.command, .option])
        }
    }

    // MARK: - View
    // MARK: - 视图菜单

    private var viewMenu: some Commands {
        CommandMenu("markdown.menu.view".localized()) {
            Button("markdown.view.togglePreview".localized()) {
                NotificationCenter.default.post(name: .markdownTogglePreview, object: nil)
            }
            .keyboardShortcut("\\", modifiers: .command)

            Button("markdown.view.toggleVertical".localized()) {
                NotificationCenter.default.post(name: .markdownToggleVerticalLayout, object: nil)
            }
            .keyboardShortcut("l", modifiers: [.command, .option])
        }
    }
}

// MARK: - Mutate helper
// MARK: - 变更辅助

private extension MarkdownFormattingContext {
    /// 读取当前 text + cursor,执行 MarkdownFormatting 动作,把新值写回。
    /// 所有 Format 菜单 Button 都用它,这样闭包可以保持单行。
    /// Read the current text + cursor, run a `MarkdownFormatting` action, and write the new values back.
    /// Used by every `Format`-menu `Button` so the closure stays a one-liner.
    func mutate(_ action: (inout String, inout NSRange) -> Void) {
        var text = self.text.wrappedValue
        var range = self.selectedRange.wrappedValue
        action(&text, &range)
        self.text.wrappedValue = text
        self.selectedRange.wrappedValue = range
    }
}
