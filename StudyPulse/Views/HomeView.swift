//
//  HomeView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import SwiftUI
import Charts
import UIKit

struct HomeView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingAddGradeSheet = false
    
    var recentGrades: [Grade] {
        return Array(dataManager.grades.sorted { $0.date > $1.date }.prefix(5))
    }
    
    // 新增：过滤未来 14 天内的考试
    var upcomingExams: [Exam] { // 请确认你的模型类型是 ExamSet 还是 Exam
        let twoWeeksFromNow = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
        
        return dataManager.examSets
            .filter { exam in
                // 条件：考试日期在今天之后，且在两周之内
                return exam.examDate > Date() && exam.examDate <= twoWeeksFromNow
            }
            .sorted { $0.examDate < $1.examDate } // 按日期最近排序
    }

    var body: some View {
        let haptic = UIImpactFeedbackGenerator(style: .rigid)
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // ... (欢迎横幅代码保持不变) ...
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
                    
                    // ... (快速统计卡片代码保持不变) ...
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 15), count: 2), spacing: 15) {
                        StatCardView(title: "Total Exams", value: "\(dataManager.grades.count)")
                        StatCardView(title: "Upcoming Exams", value: "\(upcomingExams.count)") // 这里也可以改成显示总数或两周内数量
                        // ... 其他卡片 ...
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
                    
                    // ... (登记成绩按钮代码保持不变) ...
                    Button(action: {
                        showingAddGradeSheet = true
                        haptic.prepare()
                        haptic.impactOccurred()
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
                    
                    // ================= 新增区域开始 =================
                    // 即将到来的考试 (未来两周)
                    if !upcomingExams.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Upcoming Exams (2 Weeks)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Spacer()
                                Text("\(upcomingExams.count)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(4)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(4)
                            }
                            
                            ForEach(upcomingExams) { exam in
                                UpcomingExamCard(exam: exam)
                            }
                        }
                        .padding(.horizontal)
                    }
                    // ================= 新增区域结束 =================
                    
                    // ... (成绩趋势图表代码保持不变) ...
                    if !recentGrades.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Recent Grades Trend")
                                .font(.title2)
                                .fontWeight(.bold)
                            // ... Chart 代码 ...
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
                    
                    // ... (最近成绩列表代码保持不变) ...
                    if !recentGrades.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Recent Grades")
                                .font(.title2)
                                .fontWeight(.bold)
                            ForEach(recentGrades) { grade in
                                NavigationLink(destination: GradeDetailView(grade: grade)) {
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
    
    // ... (calculateOverallAverage 和其他辅助函数保持不变) ...
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

// 修改点 2: 重命名结构体为 GradeDetailView
struct GradeDetailView: View {
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
        .navigationTitle("Grade Detail")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// 新增：即将到来的考试卡片组件
struct UpcomingExamCard: View {
    let exam: Exam // 假设你的模型叫 ExamSet，如果有不同请替换为实际模型名
    @State private var daysRemaining: Int = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 第一行：名称和科目标签
            HStack {
                Text(exam.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(exam.subject)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
            }
            
            // 第二行：日期
            Text(exam.examDate, style: .date)
                .font(.caption)
                .foregroundColor(.secondary)
            
            // 第三行：两个进度条 (时间剩余 & 掌握程度)
            HStack(spacing: 15) {
                // 左侧：时间剩余
                VStack(alignment: .leading, spacing: 2) {
                    Text("Time Left")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    ProgressView(value: calculateTimeProgress(), total: 1.0)
                        .tint(daysRemaining <= 3 ? .red : (daysRemaining <= 7 ? .orange : .green))
                    
                    Text(daysRemaining > 0 ? "\(daysRemaining) days" : "Today!")
                        .font(.caption2)
                        .foregroundColor(daysRemaining > 2 ? .secondary : .red)
                }
                
                Spacer()
                
                // 右侧：掌握程度
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mastery")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    // 确保 masteryDegree 是 Double 或转换为 Double
                    let mastery = Double(exam.masteryDegree)
                    ProgressView(value: mastery, total: 100.0)
                        .tint(exam.masteryDegree <= 20 ? .red : (exam.masteryDegree <= 60 ? .orange : .green))

                    Text("\(exam.masteryDegree)%")
                        .font(.caption2)
                        .foregroundColor(exam.masteryDegree <= 20 ? .red : .secondary)
                }
            }
        }
        .padding(12)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .onAppear {
            calculateDays()
        }
    }
    
    private func calculateDays() {
        let components = Calendar.current.dateComponents([.day], from: Date(), to: exam.examDate)
        daysRemaining = max(0, components.day ?? 0)
    }
    
    private func calculateTimeProgress() -> Double {
        // 假设最大预警时间为 30 天，超过 30 天显示满格或根据需求调整
        let maxDays = 30.0
        return min(Double(daysRemaining) / maxDays, 1.0)
    }
}


#Preview {
    HomeView()
        .environmentObject(DataManager())
}
