//
//  MainStatsCard.swift
//  StudyPulse
//
//  主页 4 项核心统计卡(平均分 / 成绩总数 / 14 天内考试 / 错题数)。
// iPhone 2x2 网格,iPad 单行 4 项。
//
//  Extracted from HomeView.swift during card-extraction refactor (2026-07-05).
//

import SwiftUI

/// 主页主要统计卡:4 个核心指标(iPhone 2x2,iPad 单行 4 项)。
///
/// 之前在 HomeView 内的实现:用 onAppear + onChange 监听 grades / exams
/// 缓存到本地 `@State`,避免 body reduce 每次重算。
struct MainStatsCard: View {
    @Environment(RepositoryContainer.self) private var container
    @Environment(\.horizontalSizeClass) private var sizeClass
    @EnvironmentObject private var envManager: AppEnvironmentManager
    /// 平均分文本缓存(随 grades 变化重算,避免每次 body reduce 所有 grades)
    @State private var cachedAverageText: String = "N/A"
    /// 14 天内考试数量缓存(随 filteredExamSets 变化重算)
    @State private var cachedUpcomingExamsCount: Int = 0

    private var isWide: Bool { sizeClass == .regular || isIPad }

    var body: some View {
        VStack(spacing: 20) {
            // iPad 一行 4 个,iPhone 仍是 2x2
            if isWide {
                HStack(spacing: 12) {
                    StatItemView(
                        title: "Average".localized(),
                        value: cachedAverageText,
                        icon: "chart.line.uptrend.xyaxis",
                        color: .cyan
                    )
                    StatItemView(
                        title: "Total Grades".localized(),
                        value: "\(container.gradeRepo.grades.count)",
                        icon: "doc.text.fill",
                        color: .purple
                    )
                    StatItemView(
                        title: "Upcoming".localized(),
                        value: "\(cachedUpcomingExamsCount)",
                        icon: "calendar.badge.exclamationmark",
                        color: .orange
                    )
                    StatItemView(
                        title: "Mistakes".localized(),
                        value: "\(container.mistakeRepo.mistakeSets.count)",
                        icon: "exclamationmark.triangle.fill",
                        color: .red
                    )
                }
            } else {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        StatItemView(
                            title: "Average".localized(),
                            value: cachedAverageText,
                            icon: "chart.line.uptrend.xyaxis",
                            color: .cyan
                        )
                        StatItemView(
                            title: "Total Grades".localized(),
                            value: "\(container.gradeRepo.grades.count)",
                            icon: "doc.text.fill",
                            color: .purple
                        )
                    }
                    HStack(spacing: 12) {
                        StatItemView(
                            title: "Upcoming".localized(),
                            value: "\(cachedUpcomingExamsCount)",
                            icon: "calendar.badge.exclamationmark",
                            color: .orange
                        )
                        StatItemView(
                            title: "Mistakes".localized(),
                            value: "\(container.mistakeRepo.mistakeSets.count)",
                            icon: "exclamationmark.triangle.fill",
                            color: .red
                        )
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSkin(envManager.effectiveCardSkin, glassEnabled: envManager.glassEffectEnabled)
        .onAppear {
            recomputeStats()
        }
        .onChange(of: container.gradeRepo.grades) { _, _ in recomputeStats() }
        .onChange(of: container.examRepo.filteredExamSets) { _, _ in recomputeStats() }
        .debugLayoutBounds(envManager.debugLayoutBounds)
    }

    /// 集中计算 average / upcoming count,避免 body 中多次 reduce
    private func recomputeStats() {
        if container.gradeRepo.grades.isEmpty {
            cachedAverageText = "N/A"
        } else {
            let total = container.gradeRepo.grades.reduce(0) { $0 + $1.score }
            let average = total / Double(container.gradeRepo.grades.count)
            cachedAverageText = String(format: "%.1f", average)
        }
        let now = Date()
        let twoWeeksFromNow = Calendar.current.date(byAdding: .day, value: 14, to: now) ?? now
        cachedUpcomingExamsCount = container.examRepo.filteredExamSets
            .filter { $0.examDate > now && $0.examDate <= twoWeeksFromNow }
            .count
    }
}

// MARK: - 单个统计项目

/// MainStatsCard 内的单个指标 tile(图标 + 数值 + 标题)。
struct StatItemView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    @EnvironmentObject private var envManager: AppEnvironmentManager

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(color)
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .debugInspect(value, label: "\(title) value")
                    .debugLayoutBounds(envManager.debugLayoutBounds)

                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .debugInspect(title, label: "\(title) label")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color(.systemBackground).opacity(0.6))
        .cornerRadius(16)
    }
}
