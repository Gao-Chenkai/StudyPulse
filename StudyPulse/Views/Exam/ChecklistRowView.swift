//
//  ChecklistRowView.swift
//  StudyPulse
//
//  考试详情页的"考前清单"行:整行点击 toggle。
//  Pre-exam checklist row in `ExamDetailView` — tap anywhere to toggle.
//
//  Phase 3 拆分 (2026-07-14):原 `ExamDetailView.swift` 抽出,可独立预览。
//

import SwiftUI

/// 考前清单行(显示 + 整行点击 toggle)
/// Pre-exam checklist row — tap anywhere to toggle.
struct ChecklistRowView: View {
    let item: ExamChecklistItem
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(item.isChecked ? Color(.systemGreen) : Color(.tertiaryLabel))
                Text(item.title)
                    .strikethrough(item.isChecked, color: .secondary)
                    .foregroundColor(item.isChecked ? Color(.secondaryLabel) : Color(.label))
                    .font(.subheadline)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview / 独立预览入口

#Preview("Empty") {
    List {
        ChecklistRowView(item: ExamChecklistItem(title: "身份证", sortOrder: 0), onToggle: {})
    }
    .listStyle(.insetGrouped)
}

#Preview("Mixed") {
    List {
        ChecklistRowView(item: ExamChecklistItem(title: "身份证", sortOrder: 0), onToggle: {})
        ChecklistRowView(item: ExamChecklistItem(title: "准考证", isChecked: true, sortOrder: 1), onToggle: {})
        ChecklistRowView(item: ExamChecklistItem(title: "2B 铅笔 + 橡皮", sortOrder: 2), onToggle: {})
    }
    .listStyle(.insetGrouped)
}
