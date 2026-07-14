//
//  MistakeSetHeaderSection.swift
//  StudyPulse
//
//  错题详情页的"顶部 header"区块:掌握度曲线 + 错题基本字段。
//  Top "header" section of the mistake detail page: mastery curve + basic fields.
//
//  Phase 3 拆分 (2026-07-14):原 `MistakeSetDetailView.swift` 抽出,可独立预览。
//

import SwiftUI
import SwiftStreamingMarkdown

/// 错题详情页的顶部 header 区块:掌握度曲线 + 错题基本字段。
/// Top header block of the mistake detail page (mastery curve + basic fields).
struct MistakeSetHeaderSection: View {
    let mistake: MistakeNote
    let tintColor: Color

    var body: some View {
        Section {
            MasteryCurveView(
                history: mistake.masteryHistory,
                currentScore: mistake.masteryScore,
                exposureCount: mistake.exposureCount,
                createdAt: mistake.date,
                tintColor: tintColor
            )
            .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
            .listRowBackground(Color.clear)
        }

        // Basic Info Section
        Section(header: Text("Details".localized())) {
            HStack {
                Text("Title".localized())
                    .foregroundColor(.secondary)
                Spacer()
                Text(mistake.title)
                    .fontWeight(.medium)
            }

            if !mistake.subject.isEmpty {
                HStack {
                    Text("Subject".localized())
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(mistake.subject.localized())
                        .fontWeight(.medium)
                }
            }

            if !mistake.source.isEmpty {
                HStack {
                    Text("Source".localized())
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(mistake.source)
                }
            }

            HStack {
                Text("Date".localized())
                    .foregroundColor(.secondary)
                Spacer()
                Text(mistake.date.formatted(date: .abbreviated, time: .omitted))
            }

            // 难度自评
            if mistake.difficulty > 0 {
                HStack {
                    Text("Difficulty".localized())
                        .foregroundColor(.secondary)
                    Spacer()
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { i in
                            Image(systemName: i <= mistake.difficulty ? "star.fill" : "star")
                                .font(.caption2)
                                .foregroundStyle(i <= mistake.difficulty ? Color.orange : Color.gray.opacity(0.4))
                        }
                    }
                }
            }

            // 标签(只读)
            if !mistake.tags.isEmpty {
                HStack(alignment: .top) {
                    Text("Tags".localized())
                        .foregroundColor(.secondary)
                    Spacer()
                    TagChipsView(tags: mistake.tags, compact: true)
                        .frame(maxWidth: 240, alignment: .trailing)
                }
            }

            // 语音备忘录
            if let audioFileName = mistake.audioFileName {
                AudioPlaybackView(audioFileName: audioFileName, onDelete: nil)
                    .padding(.top, 4)
            }
        }
    }
}

// MARK: - Preview / 独立预览入口

#Preview("Header") {
    let m = MistakeNote(
        title: "二次函数顶点公式",
        subject: "Mathematics",
        originalQuestion: "已知 f(x) = x² - 4x + 3,求顶点坐标。",
        source: "数学课本",
        date: Date(),
        errorReason: "忘记配方",
        wrongSolution: "x = -b/2a = 2",
        correctSolution: "顶点 (2, -1)",
        tags: ["跳步", "计算粗心"]
    )
    List {
        MistakeSetHeaderSection(mistake: m, tintColor: .blue)
    }
    .listStyle(.insetGrouped)
}
