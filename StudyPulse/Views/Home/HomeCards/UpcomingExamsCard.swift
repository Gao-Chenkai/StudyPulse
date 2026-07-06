//
//  UpcomingExamsCard.swift
//  StudyPulse
//
//  主页"即将到来的考试"卡片:14 天内考试列表(取前 3 个)。
// 含 CompactExamCard(行卡,带日期色块 + 倒计时)。
//
//  Extracted from HomeView.swift during card-extraction refactor (2026-07-05).
//

import SwiftUI

/// 主页"即将到来的考试"区域。
/// 之前直接读 `container.examRepo.filteredExamSets` 现地计算 14 天窗口。
struct UpcomingExamsCard: View {
    @Environment(RepositoryContainer.self) private var container

    var upcomingExams: [Exam] {
        let twoWeeksFromNow = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
        return container.examRepo.filteredExamSets
            .filter { $0.examDate > Date() && $0.examDate <= twoWeeksFromNow }
            .sorted { $0.examDate < $1.examDate }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Upcoming Exams".localized())
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                Text("\(upcomingExams.count)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(.systemOrange), Color(.orange)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
            }

            VStack(spacing: 12) {
                ForEach(upcomingExams.prefix(3)) { exam in
                    CompactExamCard(exam: exam)
                        .equatable()
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
        .debugLayoutBoundsAuto()
    }
}

// MARK: - 紧凑考试卡片

/// UpcomingExamsCard 内的行式考试卡(左侧日期色块 + 中部信息 + 倒计时)。
struct CompactExamCard: View, Equatable {
    let exam: Exam
    @State private var animateIn = false

    /// 只按 exam.id 比较,避免在 DataManager 变化时重建无关卡片
    /// Only compare by exam.id so unrelated DataManager changes don't rebuild this card.
    static func == (lhs: CompactExamCard, rhs: CompactExamCard) -> Bool {
        lhs.exam.id == rhs.exam.id
    }

    private var daysRemaining: Int {
        let components = Calendar.current.dateComponents([.day], from: Date(), to: exam.examDate)
        return max(0, components.day ?? 0)
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(spacing: 4) {
                Text(dayString(from: exam.examDate))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)

                Text(monthString(from: exam.examDate))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(width: 60)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(exam.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(exam.subject.localized())
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(.systemBlue).opacity(0.8), Color(.blue)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )

                    Text(daysRemainingText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(daysRemaining <= 3 ? Color(.systemRed) : .secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(14)
        .background(Color(.systemBackground).opacity(0.6))
        .cornerRadius(14)
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 12)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                animateIn = true
            }
        }
    }

    private var daysRemainingText: String {
        if daysRemaining == 0 {
            return "Today!".localized()
        } else if daysRemaining == 1 {
            return "Tomorrow".localized()
        } else {
            return "\(daysRemaining) " + "days".localized()
        }
    }

    private func dayString(from date: Date) -> String {
        DateFormatters.dayOfMonth.string(from: date)
    }

    private func monthString(from date: Date) -> String {
        DateFormatters.monthShort.string(from: date)
    }
}
