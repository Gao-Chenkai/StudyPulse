//
//  RelatedMistakeCard.swift
//  StudyPulse
//
//  "关联错题"行卡片(在预测 / 综合 / 等扩展列表里用)
//
//  Phase 3 拆分 (2026-07-14):原 `ExamDetailView.swift` 抽出,可独立预览。
//

import SwiftUI

/// 关联错题列表里的一行卡片
/// Row card used inside the related mistakes list.
struct RelatedMistakeCard: View {
    let mistake: MistakeNote
    @State private var animateIn = false

    /// 四段图总张数
    /// Total images across all four sections.
    var totalImages: Int {
        mistake.questionImages.count + mistake.reasonImages.count +
        mistake.wrongSolutionImages.count + mistake.correctSolutionImages.count
    }

    /// 距加入日期的相对文案(今天 / 昨天 / N 天前 / 具体日期)
    /// Relative label from the add-date (Today / Yesterday / N days ago / absolute date).
    var daysSinceAdded: String {
        let components = Calendar.current.dateComponents([.day], from: mistake.date, to: Date())
        let days = components.day ?? 0
        if days == 0 {
            return "Today".localized()
        } else if days == 1 {
            return "Yesterday".localized()
        } else if days < 7 {
            return "\(days) " + "days ago".localized()
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: mistake.date)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(mistake.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                if !mistake.originalQuestion.isEmpty {
                    Text(mistake.originalQuestion)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    if !mistake.subject.isEmpty {
                        Text(mistake.subject.localized())
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemPurple).opacity(0.15))
                            .foregroundColor(Color(.systemPurple))
                            .cornerRadius(4)
                    }

                    Text(daysSinceAdded)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if totalImages > 0 {
                        Label("\(totalImages)", systemImage: "photo")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(.systemGroupedBackground))
        .cornerRadius(10)
        .opacity(animateIn ? 1 : 0)
        .offset(x: animateIn ? 0 : -15)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85).delay(0.05)) {
                animateIn = true
            }
        }
    }
}

// MARK: - Preview / 独立预览入口

#Preview("Card") {
    let m = MistakeNote(
        title: "二次函数顶点公式",
        subject: "Mathematics",
        originalQuestion: "原题",
        source: "来源",
        date: Date().addingTimeInterval(-2 * 86400),
        errorReason: "错因",
        wrongSolution: "错解",
        correctSolution: "正解",
        tags: ["跳步"]
    )
    VStack {
        RelatedMistakeCard(mistake: m)
        RelatedMistakeCard(
            mistake: MistakeNote(
                title: "一元二次方程求根公式",
                subject: "Mathematics",
                originalQuestion: "原题",
                source: "来源",
                date: Date().addingTimeInterval(-30 * 86400),
                errorReason: "错因",
                wrongSolution: "错解",
                correctSolution: "正解"
            )
        )
    }
    .padding()
}
