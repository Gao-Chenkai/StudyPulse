//
//  HomeView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import SwiftUI
import Charts
import UIKit

// ========== GLOBE VARS & LETS ==========
let dailyQuotes = [
    "学习不是一场比赛，而是一场马拉松，坚持到最后的人才是赢家。",
    "每一次的努力，都是未来的你在向现在的你招手。",
    "知识就像海洋，越深入越发现自己的渺小，但也越接近真理。",
    "今天的汗水，是明天的收获；今天的坚持，是未来的成功。",
    "学习就像爬山，虽然过程艰辛，但登顶后的风景值得一切努力。",
    "不要因为一次失败就放弃，每一次挫折都是成长的机会。",
    "知识是最好的投资，时间是最宝贵的资源。",
    "学习的路上没有捷径，只有一步一个脚印的坚持。",
    "你的潜力超乎你的想象，只要不放弃，一切皆有可能。",
    "成功不是终点，而是不断学习和成长的过程。",
    "每天进步一点点，一年后你会感谢今天的自己。",
    "学习是照亮未来的灯塔，坚持是到达彼岸的船桨。",
    "因为歧路上有迷人的风景，看着、看着，就忍不住走进去了，走着、走着，就再也走不出来了。",
    "要成功，先发疯，下定决心往前冲!",
]

// MARK: - 每日变化的励志语录（基于日期）
var dailyQuote: String {
    let calendar = Calendar.current
    let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 0
    let index = dayOfYear % dailyQuotes.count
    return dailyQuotes[index]
}
// ========== GLOBE VARS & LETS ==========





// ========== MAIN VIEW ==========
// MARK: - 主视图
struct HomeView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var dataManager: DataManager
    @State private var currentQuoteIndex = 0
    
    
    var recentGrades: [Grade] {
        return Array(dataManager.grades.sorted { $0.date > $1.date }.prefix(5))
    }
    
    // 过滤未来 14 天内的考试
    var upcomingExams: [Exam] {
        let twoWeeksFromNow = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
        
        return dataManager.examSets
            .filter { exam in
                return exam.examDate > Date() && exam.examDate <= twoWeeksFromNow
            }
            .sorted { $0.examDate < $1.examDate }
    }
    
    // ========== BODY ==========
    var body: some View {
        NavigationView {
            ScrollView {
                WelcomeCardView()
            }
            .background(getBackgroundColor(colorScheme)) // 修改为与SettingsView一致的灰白色背景
            .navigationTitle("Dashboard")
            .navigationBarHidden(true)

        }
    }
    // ========== ENDD ==========
}
// ========== MAIN VIEW ==========





// ========== DAILY QUOTE CARD ==========
// MARK: - 鸡汤组件
// 被调用：WelcomeCardView -> HomeView
struct DailyQuoteCard: View {
    let quote: String
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "quote.bubble.fill")
                    .font(.title2)
                    .foregroundColor(Color(.cyan))
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Daily Inspiration")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(.label))
                    
                    Text(quote)
                        .font(.body)
                        .foregroundColor(Color(.secondaryLabel))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack {
                        Spacer()
                        Text("StudyPulse")
                            .font(.caption)
                            .foregroundColor(Color(.tertiaryLabel))
                            .italic()
                    }
                }
            }
            .padding()
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.secondarySystemGroupedBackground),
                    Color(.secondarySystemGroupedBackground).opacity(0.95)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.cyan).opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}
// ========== DAILY QUOTE CARD ==========





// ========== STAT CARD VIEW ==========
// MARK: - 快速统计卡片
// 被调用: WelcomeCardView -> HomeView
struct StatCardView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(Color(.secondaryLabel))
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color(.label))
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(11)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .stroke(Color(.cyan).opacity(0.3), lineWidth: 1)
        )
    }
}
// ========== STAT CARD VIEW ==========





// ========== GRADE DETAIL VIEW ==========
// MARK: - 最近成绩列表
// 被调用: WelcomeCardView -> HomeView
struct GradeDetailView: View {
    let grade: Grade
    
    var body: some View {
        List {
            Section(header: Text("Exam Details")
                .foregroundColor(Color(.secondaryLabel))
            ) {
                HStack {
                    Text("Exam Name")
                        .foregroundColor(Color(.label))
                    Spacer()
                    Text(grade.examName.isEmpty ? "N/A" : grade.examName)
                        .foregroundColor(Color(.label))
                }
                
                HStack {
                    Text("Subject")
                        .foregroundColor(Color(.label))
                    Spacer()
                    Text(grade.subject)
                        .foregroundColor(Color(.label))
                }
                
                HStack {
                    Text("Date")
                        .foregroundColor(Color(.label))
                    Spacer()
                    Text(grade.date.formatted(date: .long, time: .shortened))
                        .foregroundColor(Color(.label))
                }
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))
            
            Section(header: Text("Score")
                .foregroundColor(Color(.secondaryLabel))
            ) {
                HStack {
                    Text("Score")
                        .foregroundColor(Color(.label))
                    Spacer()
                    Text(String(format: "%.1f", grade.score))
                        .foregroundColor(scoreColor(grade.score))
                }
                
                HStack {
                    Text("Importance")
                        .foregroundColor(Color(.label))
                    Spacer()
                    HStack {
                        ForEach(0..<grade.importance, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                        }
                    }
                }
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemBackground)) // 修改为与SettingsView一致的灰白色背景
        .navigationTitle("Grade Detail")
        .navigationBarTitleDisplayMode(.inline)
    }
    
}
// ========== GRADE DETAIL VIEW ==========





// ========== UPCOMING EXAM CARD ==========
// MARK: - 即将到来的考试
// 被调用: WelcomeCardView -> HomeView
struct UpcomingExamCard: View {
    let exam: Exam
    @State private var daysRemaining: Int = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 第一行：名称和科目标签
            HStack {
                Text(exam.name)
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundColor(Color(.label))
                Spacer()
                Text(exam.subject)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemBlue).opacity(0.15))
                    .foregroundColor(Color(.systemBlue))
                    .cornerRadius(4)
            }
            
            // 第二行：日期
            Text(exam.examDate, style: .date)
                .font(.caption)
                .foregroundColor(Color(.secondaryLabel))
            
            // 第三行：两个进度条 (时间剩余 & 掌握程度)
            HStack(spacing: 15) {
                // 左侧：时间剩余
                VStack(alignment: .leading, spacing: 2) {
                    Text("Time Left")
                        .font(.caption2)
                        .foregroundColor(Color(.secondaryLabel))
                    
                    ProgressView(value: calculateTimeProgress(), total: 1.0)
                        .tint(timeLeftColor)
                    
                    Text(daysRemaining > 0 ? "\(daysRemaining) days" : "Today!")
                        .font(.caption2)
                        .foregroundColor(daysRemaining > 2 ? Color(.secondaryLabel) : Color(.systemRed))
                }
                
                Spacer()
                
                // 右侧：掌握程度
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mastery")
                        .font(.caption2)
                        .foregroundColor(Color(.secondaryLabel))
                    
                    let mastery = Double(exam.masteryDegree)
                    ProgressView(value: mastery, total: 100.0)
                        .tint(masteryColor)

                    Text("\(exam.masteryDegree)%")
                        .font(.caption2)
                        .foregroundColor(exam.masteryDegree <= 20 ? Color(.systemRed) : Color(.secondaryLabel))
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
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
        let maxDays = 30.0
        return min(Double(daysRemaining) / maxDays, 1.0)
    }
    
    private var timeLeftColor: Color {
        if daysRemaining <= 3 {
            return Color(.systemRed)
        } else if daysRemaining <= 7 {
            return Color(.systemOrange)
        } else {
            return Color(.systemGreen)
        }
    }
    
    private var masteryColor: Color {
        if exam.masteryDegree <= 20 {
            return Color(.systemRed)
        } else if exam.masteryDegree <= 60 {
            return Color(.systemOrange)
        } else {
            return Color(.systemGreen)
        }
    }
}
// ========== UPCOMING EXAM CARD ==========





// ========== MAIN INFO CARD ==========
// MARK: 主要信息卡片
//
struct HomeMainInfoView: View {
    @EnvironmentObject var dataManager: DataManager
    
    var recentGrades: [Grade] {
        return Array(dataManager.grades.sorted { $0.date > $1.date }.prefix(5))
    }
    
    var body: some View {
        VStack(spacing: 0) { // 整体间距归零
            // 顶部两个卡片：强制左右撑满
            HStack {
                // 左侧：总体平均分
                VStack(alignment: .leading) {
                    Spacer()
                    
                    Text("Overall Average")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    
                    if let overallAvg = calculateOverallAverage() {
                        Text(String(format: "%.1f", overallAvg)) // 格式化显示
                            .font(.title)
                            .bold()
                    } else {
                        Text("N/A")
                            .font(.title)
                            .bold()
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading) // 关键：左撑满

                // 右侧：最近成绩
                VStack(alignment: .leading) {
                    Spacer()
                    
                    Text("Latest Grade")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    
                    if let latestGrade = dataManager.grades.max(by: { $0.date < $1.date }) {
                        Text(String(format: "%.1f", latestGrade.score))
                            .font(.title)
                            .bold()
                    } else {
                        Text("N/A")
                            .font(.title)
                            .bold()
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading) // 关键：右撑满
            }
            .padding(.horizontal) // 内边距
            .padding(.vertical, 8)
            
            
            // 状态行：也撑满、对齐
            VStack(alignment: .leading) {
                Text("State")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                
                let latestGradeItem = dataManager.grades.max(by: { $0.date < $1.date })
                let overallAvg = calculateOverallAverage()

                if let latestScore = latestGradeItem?.score,
                   (latestScore - (overallAvg ?? 0.0)) > 5.0 {
                    HStack {
                        Image(systemName: "chevron.up.2")
                            .foregroundStyle(.green)
                        Text("Progressing")
                            .font(.title2)
                            .bold()
                    }
                } else if let latestScore = latestGradeItem?.score,
                          (latestScore - (overallAvg ?? 0.0)) < -5.0 {
                    HStack {
                        Image(systemName: "chevron.down.2")
                            .foregroundStyle(.yellow)
                        Text("Going Down")
                            .font(.title2)
                            .bold()
                    }
                } else {
                    HStack {
                        Image(systemName: "arrow.down.left.arrow.up.right")
                            .foregroundStyle(.blue)
                        Text("Smooth & Steady")
                            .font(.title2)
                            .bold()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading) // 👈 状态行也左对齐+撑满
            .padding(.horizontal)
            .padding(.bottom, 12)
            
//            VStack(alignment: .leading) {
//                if !recentGrades.isEmpty {
//                    VStack(alignment: .leading) {
//                        Text("Recent Grades Trend")
//                            .font(.title2)
//                            .fontWeight(.bold)
//                            .foregroundColor(Color(.label))
//                        Chart(recentGrades.reversed()) { grade in
//                        //    LineMark(
//                        //        x: .value("Date", grade.date),
//                        //        y: .value("Score", grade.score)
//                        //    )
//                        //    .foregroundStyle(Color(.systemBlue))
//                            PointMark(
//                                x: .value("Date", grade.date),
//                                y: .value("Score", grade.score)
//                            )
//                            .symbol {
//                                Circle()
//                                    .fill(Color(.secondarySystemGroupedBackground)) // 填充白色，制造空心效果
//                                    .frame(width: 8, height: 8) // 控制空心点的大小
//                                    .overlay {
//                                        Circle()
//                                            .stroke(scoreColor(grade.score), lineWidth: 2) // 描边使用原本的动态颜色
//                                    }
//                            }
//                            // .foregroundStyle(scoreColor(grade.score)) // 颜色已经放在描边里了，这行可以去掉
//                        }
//                        .frame(height: 200)
//                    }
//                    .padding()
//                    .background(Color(.secondarySystemGroupedBackground))
//                    .cornerRadius(12)
//                    .padding(.horizontal)
//                } else {
//                    VStack {
//                        Text("No recent grades to display")
//                            .foregroundColor(Color(.secondaryLabel))
//                            .frame(maxWidth: .infinity, minHeight: 40, maxHeight: 40)
//                            .background(Color(.secondarySystemGroupedBackground))
//                            .cornerRadius(12)
//                    }
//                    .padding(.horizontal)
//                }
//            }
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.secondarySystemGroupedBackground),
                    Color(.secondarySystemGroupedBackground).opacity(0.95)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.cyan).opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal) // 卡片离屏幕两侧留空隙
        
        
    }
    
    private func calculateOverallAverage() -> Double? {
        guard !dataManager.grades.isEmpty else { return nil }
        let total = dataManager.grades.reduce(0) { $0 + $1.score }
        return total / Double(dataManager.grades.count)
    }
}
// ========== MAIN INFO CARD ==========





// ========== WELCOME CARD VIEW ==========
// MARK: - 主要视图，从HomeView剥离
// 被调用: HomeView
struct WelcomeCardView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingAddGradeSheet = false
    @State private var currentQuoteIndex = 0
    
    
    var recentGrades: [Grade] {
        return Array(dataManager.grades.sorted { $0.date > $1.date }.prefix(5))
    }
    
    // 过滤未来 14 天内的考试
    var upcomingExams: [Exam] {
        let twoWeeksFromNow = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
        
        return dataManager.examSets
            .filter { exam in
                return exam.examDate > Date() && exam.examDate <= twoWeeksFromNow
            }
            .sorted { $0.examDate < $1.examDate }
    }
    
    var body: some View {
        let haptic = UIImpactFeedbackGenerator(style: .rigid)
        VStack(spacing: 10) {
            
            Spacer(minLength: 20)
            
            // 欢迎横幅
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome back!")
                        .font(.largeTitle)
                        .bold()
                        .fontWeight(.semibold)
                        .foregroundColor(Color(.label))
                    Text("Here's your academic progress")
                        .font(.callout)
                        .foregroundColor(Color(.secondaryLabel))
                }
                
                Spacer()
            }
            .padding()
//            .background(Color(.systemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
            
            
            // 每日励志语录卡片
            DailyQuoteCard(quote: dailyQuote)
                .padding(.horizontal)
            
            HomeMainInfoView()
            
            // 快速统计卡片
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 15), count: 2), spacing: 15) {
                StatCardView(title: "Total Exams", value: "\(dataManager.grades.count)")
                StatCardView(title: "Upcoming Exams", value: "\(upcomingExams.count)")
//                if let overallAvg = calculateOverallAverage() {
//                    StatCardView(title: "Overall Average", value: String(format: "%.1f", overallAvg))
//                } else {
//                    StatCardView(title: "Overall Average", value: "N/A")
//                }
//                
//                if let latestGrade = dataManager.grades.max(by: { $0.date < $1.date }) {
//                    StatCardView(title: "Latest Grade", value: String(format: "%.1f", latestGrade.score))
//                } else {
//                    StatCardView(title: "Latest Grade", value: "N/A")
//                }
            }
            .padding(.horizontal)
            
            // 登记成绩按钮
            Button(action: {
                showingAddGradeSheet = true
                haptic.prepare()
                haptic.impactOccurred()
            }) {
                HStack {
                    Image(systemName: "plus.circle")
                        .font(.title3)
                        .foregroundColor(.white)
                    Text("Add New Grade")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.cyan))
                .cornerRadius(10)
            }
            .padding(.horizontal)
            
            // 即将到来的考试 (未来两周)
            if !upcomingExams.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Upcoming Exams (2 Weeks)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Color(.label))
                        Spacer()
                        Text("\(upcomingExams.count)")
                            .font(.caption)
                            .foregroundColor(Color(.secondaryLabel))
                            .padding(4)
                            .background(Color(.systemGray5))
                            .cornerRadius(4)
                    }
                    
                    ForEach(upcomingExams) { exam in
                        UpcomingExamCard(exam: exam)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            // 成绩趋势图表
            if !recentGrades.isEmpty {
                VStack(alignment: .leading) {
                    Text("Recent Grades Trend")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color(.label))
                    Chart(recentGrades.reversed()) { grade in
                    //    LineMark(
                    //        x: .value("Date", grade.date),
                    //        y: .value("Score", grade.score)
                    //    )
                    //    .foregroundStyle(Color(.systemBlue))
                        PointMark(
                            x: .value("Date", grade.date),
                            y: .value("Score", grade.score)
                        )
                        .symbol {
                            Circle()
                                .fill(Color(.secondarySystemGroupedBackground)) // 填充白色，制造空心效果
                                .frame(width: 8, height: 8) // 控制空心点的大小
                                .overlay {
                                    Circle()
                                        .stroke(scoreColor(grade.score), lineWidth: 2) // 描边使用原本的动态颜色
                                }
                        }
                        // .foregroundStyle(scoreColor(grade.score)) // 颜色已经放在描边里了，这行可以去掉
                    }
                    .frame(height: 200)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)
            } else {
                VStack {
                    Text("No recent grades to display")
                        .foregroundColor(Color(.secondaryLabel))
                        .frame(maxWidth: .infinity, minHeight: 40, maxHeight: 40)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            
            // 最近成绩列表
            if !recentGrades.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Recent Grades")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color(.label))
                    ForEach(recentGrades) { grade in
                        NavigationLink(destination: GradeDetailView(grade: grade)) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(grade.examName.isEmpty ? "Exam" : grade.examName)
                                        .fontWeight(.medium)
                                        .foregroundColor(Color(.label))
                                    Text(grade.subject)
                                        .font(.caption)
                                        .foregroundColor(Color(.secondaryLabel))
                                }
                                Spacer()
                                Text(String(format: "%.1f", grade.score))
                                    .fontWeight(.bold)
                                    .foregroundColor(scoreColor(grade.score))
                            }
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(10)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
        .sheet(isPresented: $showingAddGradeSheet) {
            AddGradeView()
                .environmentObject(dataManager)
        }
    }
    
    
    private func calculateOverallAverage() -> Double? {
        guard !dataManager.grades.isEmpty else { return nil }
        let total = dataManager.grades.reduce(0) { $0 + $1.score }
        return total / Double(dataManager.grades.count)
    }
    
}
// ========== WELCOME CARD VIEW ==========

#Preview {
    HomeView()
        .environmentObject(DataManager())
        .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    HomeView()
        .environmentObject(DataManager())
        .preferredColorScheme(.dark)
}
