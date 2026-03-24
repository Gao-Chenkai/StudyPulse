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
    
    // 获取所有有成绩的科目列表，避免在 ForEach 中重复计算
    var activeSubjects: [String] {
        dataManager.subjects
            .filter { $0.enabled }
            .map { $0.name }
            .filter { hasGrades(for: $0) }
    }
    
    var body: some View {
        // 1. 使用 NavigationStack 替代 NavigationView (iOS 16+)
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(activeSubjects, id: \.self) { subjectName in
                        // 2. 简化 NavigationLink
                        // 只传递 value (subjectName)，目标视图由 navigationDestination 处理
                        NavigationLink(value: subjectName) {
                            SubjectCardView(
                                subject: subjectName,
                                latestGrade: getLatestGrade(for: subjectName)
                            )
                        }
                        .buttonStyle(.plain) // 移除默认点击高亮，保持卡片样式
                    }
                }
                .padding()
            }
            .navigationTitle("Trends")
            // 3. 注册路由处理器
            // 当 NavigationLink 传递 String 类型的 value 时，自动构建 SubjectDetailView
            .navigationDestination(for: String.self) { subjectName in
                SubjectDetailView(subject: subjectName)
                    .environmentObject(dataManager)
            }
        }
    }
    
    private func hasGrades(for subject: String) -> Bool {
        return dataManager.grades.contains { $0.subject == subject }
    }
    
    private func getLatestGrade(for subject: String) -> Grade? {
        return dataManager.grades
            .filter { $0.subject == subject }
            .max { $0.date < $1.date }
    }
}

// --- 详情页 ---

struct SubjectDetailView: View {
    let subject: String
    @EnvironmentObject var dataManager: DataManager
    
    var filteredGrades: [Grade] {
        dataManager.grades
            .filter { $0.subject == subject }
            .sorted { $0.date < $1.date }
    }
    
    var averageScore: Double {
        guard !filteredGrades.isEmpty else { return 0.0 }
        let total = filteredGrades.map { $0.score }.reduce(0, +)
        return total / Double(filteredGrades.count)
    }
    
    var body: some View {
        // 4. 详情页不再需要 NavigationView 或 navigationTitle
        // 标题由 NavigationStack 根据 push 状态自动管理
        ScrollView {
            VStack {
                // 科目统计信息卡片
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(subject)
                            .font(.title)
                            .fontWeight(.bold)
                        Spacer()
                    }
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Average Score")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f", averageScore))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(filteredGrades.isEmpty ? .secondary : scoreColor(averageScore))
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
                                    .foregroundColor(scoreColor(latest.score))
                            } else {
                                Text("N/A")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                
                // 成绩图表
                Group {
                    if !filteredGrades.isEmpty {
                        Chart(filteredGrades) { grade in
                            LineMark(
                                x: .value("Date", grade.date),
                                y: .value("Score", grade.score)
                            )
                            .foregroundStyle(.blue)
                            .interpolationMethod(.catmullRom) // 让线条更平滑
                            
                            PointMark(
                                x: .value("Date", grade.date),
                                y: .value("Score", grade.score)
                            )
                            .foregroundStyle(.blue)
                            .symbolSize(60)
                        }
                        .frame(height: 300)
                        .padding(.horizontal, 4)
                    } else {
                        ContentUnavailableView(
                            "No Data",
                            systemImage: "chart.line.xaxis.dashed",
                            description: Text("No grades recorded for \(subject) yet.")
                        )
                        .frame(height: 300)
                    }
                }
                .background(Color(UIColor.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                
                // 成绩列表
                VStack(alignment: .leading, spacing: 12) {
                    Text("History")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if !filteredGrades.isEmpty {
                        ForEach(filteredGrades.reversed()) { grade in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(grade.examName.isEmpty ? "Unnamed Exam" : grade.examName)
                                        .fontWeight(.medium)
                                    Text(grade.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Text(String(format: "%.1f", grade.score))
                                    .fontWeight(.bold)
                                    .foregroundColor(scoreColor(grade.score))
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(10)
                        }
                    } else {
                        Text("No records found.")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 20)
                    }
                }
            }
            .padding()
        }
        // 5. 设置导航栏显示模式
        .navigationBarTitleDisplayMode(.large)
    }
    
    // 辅助函数：根据分数返回颜色
    private func scoreColor(_ score: Double) -> Color {
        if score >= 90 { return .green }
        if score >= 60 { return .orange }
        return .red
    }
}

// --- 卡片组件 (保持不变，微调样式) ---

struct SubjectCardView: View {
    let subject: String
    let latestGrade: Grade?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(subject)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                if let grade = latestGrade {
                    Text(String(format: "%.1f", grade.score))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(scoreColor(grade.score))
                } else {
                    Text("--")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            if let grade = latestGrade {
                HStack {
                    HStack(spacing: 2) {
                        ForEach(0..<min(grade.importance, 5), id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .imageScale(.small)
                        }
                        if grade.importance > 5 {
                            Text("+")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                        }
                    }
                    
                    Spacer()
                    
                    Text(grade.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("No data available")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    private func scoreColor(_ score: Double) -> Color {
        if score >= 120 { return .blue }
        else if score >= 90 { return .green }
        else if score >= 60 { return .orange }
        return .red
    }
}

#Preview {
    TrendsView()
        .environmentObject(DataManager())
}
