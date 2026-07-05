//
//  RecentGradesCard.swift
//  StudyPulse
//
//  主页"最近成绩"区域:取最近 5 条成绩(按日期倒序)。
//
//  Extracted from HomeView.swift during card-extraction refactor (2026-07-05).
//

import SwiftUI

/// 主页"最近成绩"区域。
/// 之前直接读 `container.gradeRepo.grades` 现地 sort + prefix(5)。
struct RecentGradesCard: View {
    @Environment(RepositoryContainer.self) private var container

    var recentGrades: [Grade] {
        Array(container.gradeRepo.grades.sorted { $0.date > $1.date }.prefix(5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Grades".localized())
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)

            VStack(spacing: 10) {
                ForEach(recentGrades) { grade in
                    CompactGradeRow(grade: grade)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(
            color: Color.black.opacity(0.05),
            radius: 10,
            x: 0,
            y: 4
        )
    }
}

// MARK: - 紧凑成绩行

/// RecentGradesCard 内的行式成绩卡(分数圆 + 科目 + 日期 + 排名)。
///
/// 分数颜色阈值 0.85 / 0.6:≥0.85 绿、≥0.6 橙、其余红。
struct CompactGradeRow: View {
    let grade: Grade

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(scoreColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Text("\(Int(grade.score))")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(scoreColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(grade.subject.localized())
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)

                Text(grade.date, style: .date)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let ranking = grade.ranking {
                Text("#\(ranking)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(.systemBackground).opacity(0.6))
        .cornerRadius(12)
    }

    private var scoreColor: Color {
        let rate = grade.scoreRate()
        if rate >= 0.85 { return .green }
        if rate >= 0.6 { return .orange }
        return .red
    }
}
