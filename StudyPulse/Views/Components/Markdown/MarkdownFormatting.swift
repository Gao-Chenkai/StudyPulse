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

import Foundation

enum MarkdownFormatting {
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

    /// Insert `prefix` at the start of the line containing the cursor.
    /// Useful for block-level syntax like `# `, `- `, `1. `, `> `.
    static func insertLinePrefix(
        _ prefix: String,
        into text: inout String,
        range: inout NSRange
    ) {
        let nsText = text as NSString
        var lineStart = range.location
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
