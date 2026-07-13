//
//  MarkdownTextEditor.swift
//  StudyPulse
//
//  Cursor-aware `UITextView` wrapper used by `MarkdownEditorView`.
//  The stock SwiftUI `TextEditor` does not expose its `selectedRange`,
//  so a UIViewRepresentable is required for the keyboard accessory
//  toolbar (`MarkdownKeyboardToolbar`) to insert and wrap text at the
//  current cursor position. The accessory is mounted as the text
//  view's `inputAccessoryView`, giving it the same Notes-style
//  positioning above the keyboard.
//

import SwiftUI
import UIKit

// MARK: - Cursor-aware Markdown Text Editor

/// A `UITextView` wrapper that exposes its `text` and `selectedRange`
/// as SwiftUI bindings, and installs the markdown keyboard accessory
/// toolbar as its `inputAccessoryView`.
struct MarkdownTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var selectedRange: NSRange
    var font: UIFont = .preferredFont(forTextStyle: .body)

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.font = font
        view.textContainerInset = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        view.textContainer.lineFragmentPadding = 0
        view.text = text
        view.selectedRange = clampedRange(selectedRange, in: text)

        // Install the markdown keyboard accessory
        let toolbar = MarkdownKeyboardToolbar(
            text: $text,
            selectedRange: $selectedRange
        )
        let host = UIHostingController(rootView: toolbar)
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = true
        host.view.frame = CGRect(
            x: 0,
            y: 0,
            width: UIScreen.main.bounds.width,
            height: 60
        )
        view.inputAccessoryView = host.view
        context.coordinator.hostController = host

        return view
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // 当用户正在使用中文拼音或 IME 输入法处于“标记文本（Marked Text）”组合状态时，
        // 切勿修改 uiView.text 或 uiView.selectedRange，否则一定会中断/吞除拼音或候选词。
        guard uiView.markedTextRange == nil else { return }
        if uiView.text != text {
            uiView.text = text
        }
        let target = clampedRange(selectedRange, in: text)
        if uiView.selectedRange != target {
            uiView.selectedRange = target
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    static func dismantleUIView(_ uiView: UITextView, coordinator: Coordinator) {
        if uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
        uiView.inputAccessoryView = nil
        if let host = coordinator.hostController {
            host.willMove(toParent: nil)
            host.view.removeFromSuperview()
            host.removeFromParent()
            coordinator.hostController = nil
        }
    }

    /// Clamp an external `NSRange` to the valid range within `text` so
    /// that programmatically setting the selection cannot crash when
    /// the text was just shortened (e.g. after the toolbar wrapped
    /// something and the cursor offset became out of bounds).
    private func clampedRange(_ range: NSRange, in text: String) -> NSRange {
        let count = text.count
        let location = min(max(range.location, 0), count)
        let length = min(max(range.length, 0), count - location)
        return NSRange(location: location, length: length)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: MarkdownTextEditor
        /// Retained for the lifetime of the underlying UIView so the
        /// keyboard accessory stays alive.
        var hostController: UIHostingController<MarkdownKeyboardToolbar>?

        init(_ parent: MarkdownTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            if textView.markedTextRange == nil {
                parent.selectedRange = textView.selectedRange
            }
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard textView.markedTextRange == nil else { return }
            if parent.selectedRange != textView.selectedRange {
                parent.selectedRange = textView.selectedRange
            }
        }
    }
}

// MARK: - Markdown Keyboard Toolbar

/// A horizontal, scrolling keyboard accessory with quick-insert buttons
/// for common markdown syntax. The background is a capsule ("rounded
/// rect with both sides fully rounded") that uses the real iOS 26
/// `glassEffect` material when running on iOS 26+, and falls back to
/// `.regularMaterial` on older OSes.
struct MarkdownKeyboardToolbar: View {
    @Binding var text: String
    @Binding var selectedRange: NSRange

    private let glassHeight: CGFloat = 60
    private let bottomGap: CGFloat = 12
    private let horizontalMargin: CGFloat = 12

    var body: some View {
        VStack(spacing: 0) {
            // 玻璃胶囊本身保持 60pt 高，左右各缩进 12pt 让它变窄。
            // 玻璃底下的 12pt 留白让玻璃看起来像是浮在键盘上方。
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                toolbarButton("bold") { MarkdownFormatting.wrap(prefix: "**", suffix: "**", placeholder: "bold", into: &text, range: &selectedRange) }
                toolbarButton("italic") { MarkdownFormatting.wrap(prefix: "*", suffix: "*", placeholder: "italic", into: &text, range: &selectedRange) }
                toolbarButton("textformat.size") { MarkdownFormatting.insertLinePrefix("# ", into: &text, range: &selectedRange) }
                listMenuButton
                toolbarButton("text.quote") { MarkdownFormatting.insertLinePrefix("> ", into: &text, range: &selectedRange) }
                toolbarButton("chevron.left.forwardslash.chevron.right") { MarkdownFormatting.wrap(prefix: "`", suffix: "`", placeholder: "code", into: &text, range: &selectedRange) }
                toolbarButton("curlybraces") { MarkdownFormatting.insertBlock(prefix: "```\n", suffix: "\n```", placeholder: "code", into: &text, range: &selectedRange) }
                mathMenuButton
                toolbarButton("link") { MarkdownFormatting.wrap(prefix: "[", suffix: "](url)", placeholder: "text", into: &text, range: &selectedRange) }
                toolbarButton("minus") { MarkdownFormatting.insertAtCursor("\n---\n", into: &text, range: &selectedRange) }
            }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .frame(height: glassHeight)
            .background {
                // 液态玻璃背景：iOS 26+ 用系统真正的 `glassEffect`，
                // 低版本用 `.regularMaterial` 兜底。不要自己造液态玻璃。
                //
                // 注意：`glassEffect(_:in:)` 必须作用在透明画布上
                // （`Color.clear`），并通过 `in:` 把形状传进去。
                // 直接给 `Capsule()` 调 `glassEffect` 会得到一个
                // 几乎不透明的大色块，而不是液态玻璃。
                if #available(iOS 26, *) {
                    Color.clear
                        .glassEffect(.regular, in: Capsule())
                } else {
                    Capsule()
                        .fill(.regularMaterial)
                }
            }
            .padding(.horizontal, horizontalMargin)

            // 玻璃胶囊下方的留白，让玻璃看起来"浮"在键盘上方
            Color.clear
                .frame(height: bottomGap)
        }
        .frame(height: glassHeight + bottomGap)
    }

    // MARK: - Button

    @ViewBuilder
    private func toolbarButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .medium))
                .frame(width: 44, height: 44)
                .foregroundColor(.primary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// 把"无序 / 有序 / 待办"三种列表合并到一个按钮：
    /// 点击 `list.bullet` 弹出 iOS 原生菜单，三选一后插入对应 markdown。
    @ViewBuilder
    private var listMenuButton: some View {
        Menu {
            Button {
                MarkdownFormatting.insertLinePrefix("- ", into: &text, range: &selectedRange)
            } label: {
                Label("Bullet".localized(), systemImage: "list.bullet")
            }
            Button {
                MarkdownFormatting.insertLinePrefix("1. ", into: &text, range: &selectedRange)
            } label: {
                Label("Number".localized(), systemImage: "list.number")
            }
            Button {
                MarkdownFormatting.insertLinePrefix("- [ ] ", into: &text, range: &selectedRange)
            } label: {
                Label("Checklist".localized(), systemImage: "checklist")
            }
        } label: {
            Image(systemName: "list.bullet")
                .font(.system(size: 20, weight: .medium))
                .frame(width: 44, height: 44)
                .foregroundColor(.primary)
                .contentShape(Rectangle())
        }
        .menuStyle(.button)
    }

    /// 把"行内公式 / 行间公式"合并到一个按钮：
    /// 点击 `function` 弹出 iOS 原生菜单，二选一后插入 `$…$` 或 `$$…$$`。
    @ViewBuilder
    private var mathMenuButton: some View {
        Menu {
            Button {
                MarkdownFormatting.wrap(prefix: "$", suffix: "$", placeholder: "x", into: &text, range: &selectedRange)
            } label: {
                Label("Inline Math".localized(), systemImage: "x.squareroot")
            }
            Button {
                MarkdownFormatting.insertBlock(prefix: "$$\n", suffix: "\n$$", placeholder: "x", into: &text, range: &selectedRange)
            } label: {
                Label("Block Math".localized(), systemImage: "function")
            }
        } label: {
            Image(systemName: "function")
                .font(.system(size: 20, weight: .medium))
                .frame(width: 44, height: 44)
                .foregroundColor(.primary)
                .contentShape(Rectangle())
        }
        .menuStyle(.button)
    }

    // Text manipulation helpers used to live here as `private func`
    // methods. They were extracted to `MarkdownFormatting` so the
    // iPad menu-bar commands (`MarkdownCommands`) can call the same
    // code path as the on-screen toolbar — keeping both inputs
    // behaviourally identical.
}
