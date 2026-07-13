//
//  GradeChartView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//
//  单科目成绩趋势图。
//  - 数据从外部注入 grades,本视图按 subject 过滤后交给 TrendChartView
//  - 图表类型 / 主题色取自 envManager.preferences 与 effectiveAccentColor
//  - iPad/regular:280pt;iPhone/compact:200pt
//
//  Per-subject grade trend chart.
//  - Grades are injected from outside; this view filters by `subject` and forwards to `TrendChartView`.
//  - Chart type and tint color come from `envManager.preferences` and `effectiveAccentColor`.
//  - iPad / regular: 280pt; iPhone / compact: 200pt.
//

import SwiftUI
import Charts

/// 单科目成绩趋势图(供 Grade / Stats / Subject detail 等页复用)
/// Per-subject grade trend chart (reused by Grade / Stats / Subject detail pages).
struct GradeChartView: View {
    let grades: [Grade]
    let subject: String
    @Environment(RepositoryContainer.self) private var container
    @EnvironmentObject var envManager: AppEnvironmentManager
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// 当前 subject 下的成绩(按日期升序)
    /// Grades for the current subject, sorted ascending by date.
    var filteredGrades: [Grade] {
        grades.filter { $0.subject == subject }.sorted { $0.date < $1.date }
    }

    /// 该科目的满分(从 RepositoryContainer 的全科配置中取)
    /// Full score for this subject (from `RepositoryContainer`'s per-subject config).
    var fullScore: Double {
        container.fullScore(for: subject)
    }

    /// 图表高度:iPad/regular 280,iPhone/compact 200
    /// Chart height: iPad / regular = 280, iPhone / compact = 200.
    private var chartHeight: CGFloat {
        sizeClass == .regular ? 280 : 200
    }

    var body: some View {
        if !filteredGrades.isEmpty {
            TrendChartView(
                grades: filteredGrades,
                fullScore: fullScore,
                chartType: envManager.preferences.chartType,
                tintColor: envManager.effectiveAccentColor
            )
            .frame(height: chartHeight)
            .padding()
        } else {
            Text("No data available".localized())
                .foregroundColor(.secondary)
                .frame(height: chartHeight)
        }
    }
}
