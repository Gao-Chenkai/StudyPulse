//
//  MarkdownFormatting.swift
//  StudyPulse
//
//  Shared markdown formatting actions used by both the on-screen
//  keyboard accessory toolbar (`MarkdownKeyboardToolbar`) and the
//  iPadOS 26 top menu bar / keyboard shortcuts (`MarkdownCommands`).
//
//  All functions are pure: they take the current text and selection
//  by reference, mutate them, and the caller is responsible for
//  writing the modified values back to whatever binding or state owns
//  them. This keeps the actions usable from both SwiftUI views
//  (where the owner is a `@State` / `@Binding`) and from command
//  handlers (where the owner is a binding recovered from
//  `@FocusedValue`).
//
//  屏幕键盘附件工具栏(`MarkdownKeyboardToolbar`)和 iPadOS 26
//  顶部菜单栏/键盘快捷键(`MarkdownCommands`)共用的 markdown
//  格式化动作。所有函数都是纯函数:按引用传入当前文本和选区,
//  原地变更,调用方负责把变更后的值写回所属的 binding 或 state。
//  这样既能在 SwiftUI 视图(@State / @Binding)中调用,也能在
//  命令处理器(从 @FocusedValue 拿 binding)中复用。
//

import Foundation

/// 共享的 Markdown 格式化原语:插入、包裹、行前缀、块包裹。
/// 由屏幕工具栏和场景级菜单命令共用。
/// Shared Markdown formatting primitives: insert, wrap, line prefix, block wrap.
/// Used by both the on-screen keyboard toolbar and the scene-level menu commands.
enum MarkdownFormatting {
    /// 把当前选区(或仅光标)替换为给定字符串,然后把光标移动到插入末尾。
    /// Replace the current selection (or just the cursor) with the
    /// given literal string, then move the cursor to the end of the
    /// inserted text.
    static func insertAtCursor(
        _ insertion: String,
        into text: inout String,
        range: inout NSRange
    ) {
        let nsText = text as NSString
        let newText = nsText.replacingCharacters(in: range, with: insertion)
        let newCursor = range.location + insertion.count
        text = newText
        range = NSRange(location: newCursor, length: 0)
    }

    /// 有选区时用 prefix/suffix 包裹;
    /// 无选区时插入 prefix + placeholder + suffix,并把光标放在两个标记之间,
    /// 用户可以立即开始输入被包裹的内容。
    /// If there is a selection, wrap it with `prefix`/`suffix`.
    /// Otherwise, insert `prefix + placeholder + suffix` at the cursor
    /// and place the cursor between the markers so the user can type
    /// the wrapped text immediately.
    static func wrap(
        prefix: String,
        suffix: String,
        placeholder: String,
        into text: inout String,
        range: inout NSRange
    ) {
        let nsText = text as NSString
        if range.length == 0 {
            let insertion = prefix + placeholder + suffix
            let newText = nsText.replacingCharacters(in: range, with: insertion)
            let newCursor = range.location + prefix.count + placeholder.count
            text = newText
            range = NSRange(location: newCursor, length: 0)
        } else {
            let selected = nsText.substring(with: range)
            let insertion = prefix + selected + suffix
            let newText = nsText.replacingCharacters(in: range, with: insertion)
            let newCursor = range.location + insertion.count
            text = newText
            range = NSRange(location: newCursor, length: 0)
        }
    }

    /// 在光标所在行的开头插入 prefix。用于 `# `、`- `、`1. `、`> ` 这类块级语法。
    /// Insert `prefix` at the start of the line containing the cursor.
    /// Useful for block-level syntax like `# `, `- `, `1. `, `> `.
    static func insertLinePrefix(
        _ prefix: String,
        into text: inout String,
        range: inout NSRange
    ) {
        let nsText = text as NSString
        var lineStart = range.location
        // 找到光标所在行的起点:向前扫描直到行首或字符串起点
        // Find the start of the cursor's line by scanning backwards until line-start or string start.
        let newline = UInt16(UnicodeScalar("\n").value)
        while lineStart > 0 && nsText.character(at: lineStart - 1) != newline {
            lineStart -= 1
        }
        let newText = nsText.replacingCharacters(
            in: NSRange(location: lineStart, length: 0),
            with: prefix
        )
        let newCursor = range.location + prefix.count
        text = newText
        range = NSRange(location: newCursor, length: 0)
    }

    /// 插入一个 prefix / suffix 包围的多行块。
    /// 若光标不在行首,自动在前面补一个换行,让块另起一行。
    /// Insert a multi-line block delimited by `prefix` / `suffix`. If
    /// the cursor is not at the start of a line, prepend a newline so
    /// the block opens on its own line.
    static func insertBlock(
        prefix: String,
        suffix: String,
        placeholder: String,
        into text: inout String,
        range: inout NSRange
    ) {
        let nsText = text as NSString
        let prevIndex = range.location - 1
        let needsLeadingNewline = range.location > 0
            && nsText.character(at: prevIndex) != UInt16(UnicodeScalar("\n").value)
        let leading = needsLeadingNewline ? "\n" : ""
        let insertion = leading + prefix + placeholder + suffix
        let newText = nsText.replacingCharacters(in: range, with: insertion)
        let newCursor = range.location + insertion.count
        text = newText
        range = NSRange(location: newCursor, length: 0)
    }
}
