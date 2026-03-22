//
//  HomeView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import SwiftUI
import Charts

struct HomeView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingAddGradeSheet = false
    
    var recentGrades: [Grade] {
        return Array(dataManager.grades.sorted { $0.date > $1.date }.prefix(5))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 欢迎横幅
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Welcome back!")
                                .font(.title)
                                .fontWeight(.semibold)
                            
                            Text("Here's your academic progress")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    
                    // 快速统计卡片
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 15), count: 2), spacing: 15) {
                        StatCardView(title: "Total Exams", value: "\(dataManager.grades.count)")
                        StatCardView(title: "Subjects", value: "\(dataManager.subjects.filter { $0.enabled }.count)")
                        
                        if let overallAvg = calculateOverallAverage() {
                            StatCardView(title: "Overall Average", value: String(format: "%.1f", overallAvg))
                        } else {
                            StatCardView(title: "Overall Average", value: "N/A")
                        }
                        
                        if let latestGrade = dataManager.grades.max(by: { $0.date < $1.date }) {
                            StatCardView(title: "Latest Grade", value: String(format: "%.1f", latestGrade.score))
                        } else {
                            StatCardView(title: "Latest Grade", value: "N/A")
                        }
                    }
                    .padding(.horizontal)
                    
                    // 登记成绩按钮
                    Button(action: {
                        showingAddGradeSheet = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle")
                                .font(.title3)
                            Text("Add New Grade")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    
                    // 成绩趋势图表
                    if !recentGrades.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Recent Grades Trend")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Chart(recentGrades.reversed()) { grade in
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
                        }
                        .padding()
                    } else {
                        Text("No recent grades to display")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: 200)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(10)
                            .padding()
                    }
                    
                    // 最近考试
                    if !recentGrades.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Recent Exams")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            ForEach(recentGrades) { grade in
                                NavigationLink(destination: ExamDetailView(grade: grade)) {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(grade.examName.isEmpty ? "Exam" : grade.examName)
                                                .fontWeight(.medium)
                                            
                                            Text(grade.subject)
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
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddGradeSheet) {
                AddGradeView()
                    .environmentObject(dataManager)
            }
        }
    }
    
    private func calculateOverallAverage() -> Double? {
        guard !dataManager.grades.isEmpty else { return nil }
        let total = dataManager.grades.reduce(0) { $0 + $1.score }
        return total / Double(dataManager.grades.count)
    }
}

struct StatCardView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

struct ExamDetailView: View {
    let grade: Grade
    
    var body: some View {
        List {
            Section(header: Text("Exam Details")) {
                HStack {
                    Text("Exam Name")
                    Spacer()
                    Text(grade.examName.isEmpty ? "N/A" : grade.examName)
                }
                
                HStack {
                    Text("Subject")
                    Spacer()
                    Text(grade.subject)
                }
                
                HStack {
                    Text("Date")
                    Spacer()
                    Text(grade.date.formatted(date: .long, time: .shortened))
                }
            }
            
            Section(header: Text("Score")) {
                HStack {
                    Text("Score")
                    Spacer()
                    Text(String(format: "%.1f", grade.score))
                }
                
                HStack {
                    Text("Importance")
                    Spacer()
                    HStack {
                        ForEach(0..<grade.importance, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                        }
                    }
                }
            }
        }
        .navigationTitle("Exam Detail")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    HomeView()
        .environmentObject(DataManager())
}
