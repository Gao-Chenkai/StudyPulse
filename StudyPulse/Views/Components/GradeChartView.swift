//
//  GradeChartView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import SwiftUI
import Charts

struct GradeChartView: View {
    let grades: [Grade]
    let subject: String
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var envManager: AppEnvironmentManager
    @Environment(\.horizontalSizeClass) private var sizeClass

    var filteredGrades: [Grade] {
        grades.filter { $0.subject == subject }.sorted { $0.date < $1.date }
    }

    var fullScore: Double {
        dataManager.fullScore(for: subject)
    }

    private var chartHeight: CGFloat {
        sizeClass == .regular ? 280 : 200
    }

    var body: some View {
        if !filteredGrades.isEmpty {
            TrendChartView(
                grades: filteredGrades,
                fullScore: fullScore,
                chartType: envManager.preferences.chartType
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
