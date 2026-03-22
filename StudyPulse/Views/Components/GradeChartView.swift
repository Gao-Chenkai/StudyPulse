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
    
    var filteredGrades: [Grade] {
        grades.filter { $0.subject == subject }.sorted { $0.date < $1.date }
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
                .foregroundStyle(.blue)
            }
            .frame(height: 200)
            .padding()
        } else {
            Text("No data available")
                .foregroundColor(.secondary)
                .frame(height: 200)
        }
    }
}
