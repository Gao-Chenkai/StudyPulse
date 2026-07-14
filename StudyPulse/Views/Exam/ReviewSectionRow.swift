//
//  ReviewSectionRow.swift
//  StudyPulse
//
//  复盘单段折叠行:点击展开渲染后的 Markdown。
//  Collapsible row showing a single review section's rendered markdown.
//
//  Phase 3 拆分 (2026-07-14):原 `ExamDetailView.swift` 抽出,可独立预览。
//

import SwiftUI

/// 复盘单段折叠行:点击展开渲染后的 Markdown。
/// Collapsible row showing a single review section's rendered markdown.
struct ReviewSectionRow: View {
    let title: String
    let icon: String
    let markdown: String

    @State private var isExpanded: Bool = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Empty".localized())
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            } else {
                MarkdownPreviewView(text: markdown)
                    .frame(minHeight: 80)
                    .frame(maxHeight: 240)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                    .frame(width: 22)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                if markdown.isEmpty {
                    Text("Empty".localized())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .listRowBackground(Color(.secondarySystemGroupedBackground))
    }
}

// MARK: - Preview / 独立预览入口

#Preview("With Content") {
    List {
        ReviewSectionRow(
            title: "What Was Tested".localized(),
            icon: "doc.text.magnifyingglass",
            markdown: """
            # Ch.3-4
            - 二次函数顶点公式
            - 配方法
            """
        )
    }
    .listStyle(.insetGrouped)
}

#Preview("Empty") {
    List {
        ReviewSectionRow(
            title: "What Went Wrong".localized(),
            icon: "exclamationmark.triangle",
            markdown: ""
        )
    }
    .listStyle(.insetGrouped)
}
