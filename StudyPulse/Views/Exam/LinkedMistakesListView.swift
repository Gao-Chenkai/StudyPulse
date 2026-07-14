//
//  LinkedMistakesListView.swift
//  StudyPulse
//
//  复盘"关联错题"行点击进入的子页面:列出复盘里勾选的所有错题。
//  Sub-page shown when tapping "Linked Mistakes" on the review — lists
//  the mistakes the user ticked in the review editor.
//
//  Phase 3 拆分 (2026-07-14):原 `ExamDetailView.swift` 抽出,可独立预览。
//

import SwiftUI

/// 复盘"关联错题"行点击进入的子页面:列出复盘里勾选的所有错题。
/// Sub-page shown when tapping "Linked Mistakes" on the review — lists
/// the mistakes the user ticked in the review editor.
struct LinkedMistakesListView: View {
    let mistakeIds: [UUID]
    let subject: String

    @Environment(RepositoryContainer.self) private var container

    /// 实际能查到的错题(过滤掉已删除的 id)
    /// Resolved mistakes (filters out deleted IDs).
    private var resolved: [MistakeNote] {
        container.mistakeRepo.mistakeSets.filter { mistakeIds.contains($0.id) }
    }

    var body: some View {
        Form {
            if resolved.isEmpty {
                Section {
                    HStack {
                        Image(systemName: "tray")
                            .foregroundColor(.secondary)
                        Text("No related mistakes for this subject".localized())
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Section {
                    ForEach(resolved) { mistake in
                        NavigationLink {
                            MistakeSetDetailView(mistakeSet: mistake)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(mistake.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                if !mistake.subject.isEmpty {
                                    Text(mistake.subject.localized())
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Linked Mistakes".localized())
                } footer: {
                    Text(String(format: "%d mistakes".localized(), resolved.count))
                }
            }
        }
        .navigationTitle("Linked Mistakes".localized())
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview / 独立预览入口

#Preview("Empty") {
    NavigationStack {
        LinkedMistakesListView(mistakeIds: [], subject: "Mathematics")
    }
    .environment(RepositoryContainer())
}
