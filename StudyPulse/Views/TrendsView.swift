//
//  TrendsView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import SwiftUI
import Charts

struct TrendsView: View {
    @EnvironmentObject var dataManager: DataManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(dataManager.subjects.filter { $0.enabled }, id: \.name) { subject in
                        if hasGrades(for: subject.name) {
                            NavigationLink(destination: SubjectDetailView(subject: subject.name)) {
                                SubjectCardView(subject: subject.name, latestGrade: getLatestGrade(for: subject.name))
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Trends")
        }
    }
    
    private func hasGrades(for subject: String) -> Bool {
        return dataManager.grades.contains { $0.subject == subject }
    }
    
    private func getLatestGrade(for subject: String) -> Grade? {
        return dataManager.grades.filter { $0.subject == subject }.max { $0.date < $1.date }
    }
}

struct SubjectDetailView: View {
    let subject: String
    @EnvironmentObject var dataManager: DataManager
    
    var filteredGrades: [Grade] {
        dataManager.grades.filter { $0.subject == subject }.sorted { $0.date < $1.date }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 科目统计信息
                HStack {
                    VStack(alignment: .leading) {
                        Text(subject)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        if filteredGrades.count > 0 {
                            let total = filteredGrades.map({ $0.score }).reduce(0, +)
                            let avg = total / Double(filteredGrades.count)
                            Text("Average: \(String(format: "%.1f", avg))")
                                .foregroundColor(.secondary)
                        } else {
                            Text("Average: No data")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Latest")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if let latest = filteredGrades.last {
                            Text(String(format: "%.1f", latest.score))
                                .font(.title2)
                                .fontWeight(.bold)
                        } else {
                            Text("N/A")
                        }
                    }
                }
                .padding()
                
                // 成绩图表
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
                    .frame(height: 300)
                    .padding()
                } else {
                    Text("No data available")
                        .foregroundColor(.secondary)
                        .frame(height: 300)
                }
                
                // 成绩列表
                VStack(alignment: .leading, spacing: 10) {
                    Text("All Grades")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if !filteredGrades.isEmpty {
                        ForEach(filteredGrades.reversed()) { grade in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(grade.examName.isEmpty ? "Exam" : grade.examName)
                                        .fontWeight(.medium)
                                    Text(grade.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Text(String(format: "%.1f", grade.score))
                                    .fontWeight(.bold)
                            }
                            .padding()
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(10)
                        }
                    } else {
                        Text("No grades recorded for this subject")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
                .padding()
            }
        }
        .navigationTitle(subject)
    }
}

struct SubjectCardView: View {
    let subject: String
    let latestGrade: Grade?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(subject)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                if let grade = latestGrade {
                    Text(String(format: "%.1f", grade.score))
                        .font(.title3)
                        .fontWeight(.bold)
                } else {
                    Text("--")
                        .font(.title3)
                        .fontWeight(.bold)
                }
            }
            
            if let grade = latestGrade {
                HStack {
                    ForEach(0..<grade.importance, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .imageScale(.small)
                    }
                    
                    Spacer()
                    
                    Text(grade.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("No data")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}
