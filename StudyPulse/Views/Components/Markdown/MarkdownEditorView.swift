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

import SwiftUI
import SwiftStreamingMarkdown

// MARK: - Markdown Editor View

/// A complete markdown editing experience: editor + live preview,
/// arranged side-by-side on iPad and stacked top/bottom on iPhone.
struct MarkdownEditorView: View {
    /// The raw markdown text being edited.
    @Binding var text: String
    /// Placeholder text shown when editor is empty.
    var placeholder: String = "Write markdown..."

    /// Current split position as fraction of the primary axis
    /// (height for vertical, width for horizontal). Clamped 0.2–0.8.
    @State private var splitFraction: CGFloat = 0.5
    /// The length of the container along the split axis, kept in
    /// sync with `GeometryReader` so drag deltas are translated
    /// into real fractions without a "snap on release" lag.
    @State private var containerLength: CGFloat = 600
    /// The current cursor / selection in the editor, exposed as a
    /// binding so the keyboard accessory toolbar (and the menu-bar
    /// commands) can insert at the cursor or wrap the selection.
    @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)

    /// Whether the preview pane is currently shown. Flipped by the
    /// `View → Toggle Preview` menu command (⌘\\).
    @State private var isPreviewVisible: Bool = true
    /// Force the editor into the top/bottom layout even on iPad.
    /// Flipped by the `View → Vertical Layout` menu command (⌘⌥L)
    /// and persisted across launches.
    @AppStorage("markdown.forceVerticalLayout") private var forceVertical: Bool = false

    /// The split direction is derived from the horizontal size class
    /// so Split View / Stage Manager on iPad automatically falls
    /// back to the compact (top/bottom) layout.
    @Environment(\.horizontalSizeClass) private var hSize

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
        // Publish the editor's text + cursor to the scene-level
        // menu commands (`MarkdownCommands`). When a different
        // editor takes focus, SwiftUI re-evaluates this view, the
        // focused value updates, and the menu commands point at
        // the new editor automatically.
        .focusedSceneValue(\.markdownFormatting, context)
        // Listen for the `View` menu commands, which post these
        // notifications because there is no binding to pass
        // through `FocusedValue` for view-level state.
        .onReceive(NotificationCenter.default.publisher(for: .markdownTogglePreview)) { _ in
            isPreviewVisible.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .markdownToggleVerticalLayout)) { _ in
            // The toggle is a no-op when the device is already
            // compact — there is nothing to switch to on iPhone.
            guard hSize == .regular else { return }
            forceVertical.toggle()
        }
    }

    // MARK: - Context for menu commands

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

    private var editorPane: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(Color(.placeholderText))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }
            // Use the cursor-aware `MarkdownTextEditor` (a `UITextView`
            // wrapper) instead of the stock SwiftUI `TextEditor` so the
            // markdown keyboard accessory can insert / wrap at the
            // actual cursor position.
            MarkdownTextEditor(text: $text, selectedRange: $selectedRange)
                .font(.body)
        }
        // No background fill — let the parent (Form Section's card)
        // show through so the editor, divider, and preview are all
        // the same continuous colour with no visible "block"
        // between them.
    }

    // MARK: - Dividers
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
                            splitFraction = min(0.8, max(0.2, raw))
                        }
                )
            Rectangle()
                .fill(Color.primary.opacity(0.18))
                .frame(width: 0.5)
        }
    }

    // MARK: - Preview Pane

    private var previewPane: some View {
        MarkdownPreviewView(text: text)
            .overlay(alignment: .topTrailing) {
                // Small label indicating preview
                Text("Preview")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
            }
    }

    // MARK: - Length Calculations

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

/// A compact Markdown editor suited for inline / form use.
/// Shows a TextEditor that expands into a full MarkdownEditorView via sheet.
struct CompactMarkdownEditorView: View {
    @Binding var text: String
    var title: String = "Content"
    @State private var showFullEditor = false

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
