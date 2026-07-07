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

import SwiftUI

/// A live handle to the markdown editor's text buffer and cursor,
/// exposed via `focusedSceneValue` so the scene-level menu commands
/// can read and mutate it.
struct MarkdownFormattingContext {
    let text: Binding<String>
    let selectedRange: Binding<NSRange>
}

private struct MarkdownFormattingKey: FocusedValueKey {
    typealias Value = MarkdownFormattingContext
}

extension FocusedValues {
    /// The currently focused markdown editor's text + cursor binding,
    /// or `nil` when no `MarkdownEditorView` is on screen / focused.
    var markdownFormatting: MarkdownFormattingContext? {
        get { self[MarkdownFormattingKey.self] }
        set { self[MarkdownFormattingKey.self] = newValue }
    }
}

// MARK: - Editor state notifications
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
    /// Posted by the `View → Toggle Preview` menu command.
    /// `MarkdownEditorView` observes it and flips `isPreviewVisible`.
    static let markdownTogglePreview = Notification.Name("StudyPulse.markdown.togglePreview")
    /// Posted by the `View → Vertical Layout` menu command.
    /// `MarkdownEditorView` observes it and flips `forceVertical`.
    static let markdownToggleVerticalLayout = Notification.Name("StudyPulse.markdown.toggleVerticalLayout")
}
