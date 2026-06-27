//
//  MarkdownEditorView.swift
//  StudyPulse
//
//  Full Markdown editor with split layout:
//    Top half: TextEditor for raw markdown input.
//    Bottom half: Live-rendered preview via SwiftStreamingMarkdown's
//    `MarkdownView`. The package does incremental parsing, so we no longer
//    debounce a custom parser here — we just hand the bound text to the
//    preview, which re-parses on each change.
//    Draggable divider for height adjustment.
//

import SwiftUI
import SwiftStreamingMarkdown

// MARK: - Markdown Editor View

/// A complete markdown editing experience: editor on top, preview on bottom.
struct MarkdownEditorView: View {
    /// The raw markdown text being edited.
    @Binding var text: String
    /// Placeholder text shown when editor is empty.
    var placeholder: String = "Write markdown..."

    /// Current divider position as fraction of total height (0.2–0.8).
    @State private var dividerFraction: CGFloat = 0.5
    /// The height of the container, used to calculate split positions.
    @State private var containerHeight: CGFloat = 600
    /// The current cursor / selection in the editor, exposed as a
    /// binding so the keyboard accessory toolbar can insert at the
    /// cursor or wrap the selected text.
    @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Editor pane
                editorPane
                    .frame(height: max(120, editorHeight(in: geometry.size.height)))

                // Draggable divider
                divider

                // Preview pane
                previewPane
                    .frame(height: max(120, previewHeight(in: geometry.size.height)))
            }
            .onAppear {
                updateContainerHeight(geometry.size.height)
            }
            .onChange(of: geometry.size.height) { _, newHeight in
                updateContainerHeight(newHeight)
            }
        }
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

    // MARK: - Divider
    //
    // The only visible element is a 0.5pt hairline in `Color.primary`
    // (auto light/dark). The strip itself is short (12pt) and the
    // surrounding area has no extra padding, so nothing else draws a
    // white block around the line. A 24pt invisible touch target
    // overlaps the strip to make it easy to grab and drag.
    //
    // The drag updates `dividerFraction` directly in `onChanged`, so
    // the editor and preview panes resize in real-time as the user
    // drags — no "wait until release" lag.

    private var divider: some View {
        // The strip is exactly 12pt tall so the white "block" between
        // the editor and the preview is as small as possible while
        // still leaving a generous grab target. The only visible
        // thing inside it is a 0.5pt hairline; the rest of the
        // 12pt is the transparent drag-handle area.
        ZStack {
            // The drag-handle area (transparent, 12pt tall)
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // Update in real-time so the panes follow
                            // the finger, not just snap on release.
                            let total = containerHeight
                            guard total > 0 else { return }
                            let raw = dividerFraction + value.translation.height / total
                            dividerFraction = min(0.8, max(0.2, raw))
                        }
                )

            // The only visible thing: a 0.5pt hairline, centred.
            Rectangle()
                .fill(Color.primary.opacity(0.18))
                .frame(height: 0.5)
        }
        .frame(height: 12)
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

    // MARK: - Height Calculations

    /// Guard against tiny sizes from Form/List parents.
    private func updateContainerHeight(_ height: CGFloat) {
        containerHeight = max(height, 200)
    }

    private func editorHeight(in total: CGFloat) -> CGFloat {
        total * dividerFraction
    }

    private func previewHeight(in total: CGFloat) -> CGFloat {
        total * (1 - dividerFraction)
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
