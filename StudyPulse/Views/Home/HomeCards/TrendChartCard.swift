//
//  TrendChartCard.swift
//  StudyPulse
//
//  主页"单科目趋势"图表卡。菜单选聚焦规则 → 选科目 → TrendChartView。
// 选科 / 科目-成绩查询已迁入 HomeViewModel,本卡只负责 UI。
//  Home "Single-Subject Trend" chart card. Menu selects a focus rule → picks a subject
//  → renders TrendChartView. Subject selection and per-subject grade lookup have
//  been moved into HomeViewModel; this card only handles UI.
//
//  Extracted from HomeView.swift during card-extraction refactor (2026-07-05).
//

import SwiftUI
import Charts

/// 单科目趋势图表卡:用户通过 Menu 选择聚焦规则,
/// VM 根据规则选出一门科目,卡片渲染对应 TrendChartView + 三项统计。
///
/// 由父 View 注入 `HomeViewModel`(VM 拥有选科状态);卡片只读取不写入。
/// Single-subject trend chart card: user picks a focus rule from the Menu,
/// the VM selects a subject per the rule, and the card renders the corresponding
/// TrendChartView + 3 statistics tiles.
///
/// The parent View injects `HomeViewModel` (VM owns the chart subject selection);
/// the card only reads, never writes.
struct TrendChartCard: View {
    @Environment(RepositoryContainer.self) private var container
    @EnvironmentObject var envManager: AppEnvironmentManager
    /// 注入 HomeViewModel(图表选科逻辑已迁入)
    /// Injected HomeViewModel (chart subject selection has been moved here).
    @ObservedObject var viewModel: HomeViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var animateChart = false

    /// 图表区域高度:iPad/regular 用 260,iPhone 用 180
    /// Chart area height: 260 on iPad / regular, 180 on iPhone.
    private var chartHeight: CGFloat {
        isIPad || sizeClass == .regular ? 260 : 180
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Subject Trend".localized())
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                Menu {
                    Button(action: { viewModel.selectChartSubject(rule: .lowestScore) }) {
                        Label("Focus: Lowest Score".localized(), systemImage: "chart.line.downtrend.xyaxis")
                    }
                    Button(action: { viewModel.selectChartSubject(rule: .mostGrades) }) {
                        Label("Focus: Most Data".localized(), systemImage: "doc.text.fill")
                    }
                    Button(action: { viewModel.selectChartSubject(rule: .recentMost) }) {
                        Label("Focus: Recent Activity".localized(), systemImage: "clock")
                    }
                    Button(action: { viewModel.selectChartSubject(rule: .mostImprovement) }) {
                        Label("Focus: Improvement".localized(), systemImage: "chart.line.uptrend.xyaxis")
                    }
                    Button(action: { viewModel.selectChartSubject(rule: .random) }) {
                        Label("Random Subject".localized(), systemImage: "shuffle")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(viewModel.chartRule.displayName)
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }

            if let subject = viewModel.chartSelectedSubject, let grades = viewModel.gradesForSubject(subject) {
                VStack(spacing: 12) {
                    HStack {
                        Text(subject.localized())
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)

                        Spacer()

                        Text(String(format: "%d records".localized(), grades.count))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    TrendChartView(
                        grades: grades.sorted(by: { $0.date < $1.date }),
                        fullScore: container.fullScore(for: subject),
                        chartType: envManager.preferences.chartType,
                        tintColor: envManager.effectiveAccentColor
                    )
                    .frame(height: chartHeight)
                    .opacity(animateChart ? 1 : 0)
                    .offset(y: animateChart ? 0 : 20)

                    HStack(spacing: 20) {
                        ChartStatisticItem(title: "Average".localized(), value: String(format: "%.1f", SubjectAggregator.averageScore(for: grades)), color: .cyan)
                        ChartStatisticItem(title: "Highest".localized(), value: String(format: "%.1f", SubjectAggregator.highestScore(for: grades)), color: .green)
                        ChartStatisticItem(title: "Lowest".localized(), value: String(format: "%.1f", SubjectAggregator.lowestScore(for: grades)), color: .orange)
                    }
                }
                .padding(16)
                .background(Color(.systemBackground).opacity(0.6))
                .cornerRadius(16)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("Select a subject to view trends".localized())
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color(.systemBackground).opacity(0.6))
                .cornerRadius(16)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSkin(envManager.effectiveCardSkin, glassEnabled: envManager.glassEffectEnabled)
        .debugLayoutBoundsAuto()
        .onAppear {
            viewModel.selectChartSubject(rule: viewModel.chartRule)
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                animateChart = true
            }
        }
    }
}

// MARK: - 统计项视图
// MARK: - Statistics Item View

/// TrendChartCard 底部三段式统计 tile(平均/最高/最低)。
///
/// 注:名字为 `ChartStatisticItem` 是为了避免与 HomeView 之前叫 `StatisticItem`
/// 的全局类型产生歧义;旧名仍保留在 HomeView 删完之前,这里先新名站稳。
/// 3-segment statistics tile at the bottom of TrendChartCard (average / highest / lowest).
///
/// Note: renamed to `ChartStatisticItem` to avoid ambiguity with the old global
/// `StatisticItem` type that previously lived on HomeView; once HomeView is fully
/// cleaned up, the new name is the one to keep.
struct ChartStatisticItem: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
