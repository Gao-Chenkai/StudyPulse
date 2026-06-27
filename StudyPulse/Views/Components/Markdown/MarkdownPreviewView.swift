//
//  MarkdownPreviewView.swift
//  StudyPulse
//
//  Scrollable preview that renders a markdown string via
//  SwiftStreamingMarkdown's `MarkdownView`. Adapts to light/dark mode
//  automatically through the package's render config.
//

import SwiftUI
import SwiftStreamingMarkdown

/// The scrollable rendered preview of markdown content.
struct MarkdownPreviewView: View {
    /// The raw markdown source to render.
    let text: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if text.isEmpty {
                    emptyPreview
                } else {
                    MarkdownView(text: text.normalisingSingleDollarMath(), config: .previewConfig)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // No background fill — let the parent show through so the
        // preview flows seamlessly out of the editor without a
        // visible "block" at the divider.
    }

    private var emptyPreview: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.viewfinder")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.5))
            Text("Start typing markdown above")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }
}

/// A simplified preview used for snapshot / share views.
struct StaticMarkdownPreviewView: View {
    let markdownText: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                MarkdownView(text: markdownText.normalisingSingleDollarMath(), config: .previewConfig)
            }
            .padding(12)
        }
    }
}

// MARK: - Render config used by the app's previews

// Internal (not private) so other views in the app — e.g. the
// `MistakeSetDetailView` read-only page — can reuse the same renderer
// config and single-dollar math normalisation.
extension MarkdownRenderConfig {
    /// Lighter block spacing matches the previous in-house preview layout.
    static let previewConfig: MarkdownRenderConfig = {
        var config = MarkdownRenderConfig.default
        config = config.withShouldAnimateText(value: false)
        config = config.withBlockSpacing(value: 8)
        return config
    }()
}

#Preview {
    let sampleMD = """
    # Sample Markdown

    This is a **bold** and *italic* paragraph with `inline code`.

    ## Math Formulas

    Inline: $E = mc^2$

    Display:
    $$
    \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}
    $$

    ## Chemistry

    $\\ce{H2O}$ is water. Reaction:
    $$
    \\ce{2H2 + O2 -> 2H2O}
    $$

    ### Lists

    - Item one
    - Item **two**
    - Item *three*

    1. First step
    2. Second step

    ### Tasks

    - [x] Completed task
    - [ ] Pending task

    > This is a blockquote with **bold** text.

    ```
    func hello() {
        print("Hello World")
    }
    ```

    | Name | Score |
    |------|-------|
    | Math | 95    |
    | English | 88 |
    """
    MarkdownPreviewView(text: sampleMD)
}

// MARK: - Single-dollar inline math normalisation

// Internal (not private) so `MistakeSetDetailView` and other read-only
// markdown renderers in the app can normalise `$…$` → `\(…\)` before
// passing the source to `MarkdownView`.
extension String {
    /// SwiftStreamingMarkdown's LaTeX pre-processor only recognises the
    /// delimiters `$$…$$` (block), `\[…\]` (block) and `\(…\)` (inline).
    /// It does **not** recognise the more common single-dollar form
    /// `$…$` for inline math, so this helper rewrites every occurrence
    /// of `$…$` into `\(…\)` before the source is handed to `MarkdownView`.
    ///
    /// Rules:
    /// - The opening `$` must not be preceded by a backslash (i.e. `\$`
    ///   is left untouched as a literal dollar sign) and must not be
    ///   adjacent to another `$` (so `$$…$$` block math is preserved).
    /// - The closing `$` is treated symmetrically.
    /// - The body must not contain another `$` or a newline, so the
    ///   match stays on a single line and inside the original delimiters.
    /// - An unmatched opening `$` (e.g. "100$ price") is left as-is.
    func normalisingSingleDollarMath() -> String {
        // (?<!\$)(?<!\\)\$(?!\$)  – opening $ that is not part of \$, $$
        //                         or the right side of a $$ sequence
        // ([^\$\n]+?)              – the inline math body (no $, no \n)
        // \$(?!\$)                 – closing $ that is not part of $$
        let pattern = #"(?<!\$)(?<!\\)\$(?!\$)([^\$\n]+?)\$(?!\$)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return self
        }
        let range = NSRange(startIndex..., in: self)
        return regex.stringByReplacingMatches(
            in: self,
            options: [],
            range: range,
            withTemplate: "\\\\($1\\\\)"
        )
    }
}
