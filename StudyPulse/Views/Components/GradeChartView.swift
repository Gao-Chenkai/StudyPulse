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
    
    var filteredGrades: [Grade] {
        grades.filter { $0.subject == subject }.sorted { $0.date < $1.date }
    }
    
    var fullScore: Double {
        dataManager.fullScore(for: subject)
    }
    
    var body: some View {
        if !filteredGrades.isEmpty {
            Chart(filteredGrades) { grade in
                LineMark(
                    x: .value("Date", grade.date),
                    y: .value("Score", grade.score)
                )
                .foregroundStyle(.blue)
                
                PointMark(
                    x: .value("Date", grade.date),
                    y: .value("Score", grade.score)
                )
                .foregroundStyle(scoreColor(grade.score, fullScore: fullScore))
            }
            .frame(height: 200)
            .padding()
        } else {
            Text("No data available".localized())
                .foregroundColor(.secondary)
                .frame(height: 200)
        }
    }
}
