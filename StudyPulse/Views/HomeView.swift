//
//  HomeView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import SwiftUI
import Charts
import UIKit

// MARK: - 每日变化的励志语录（基于日期）
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

var dailyQuote: String {
    let calendar = Calendar.current
    let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 0
    let index = dayOfYear % dailyQuotes.count
    return dailyQuotes[index]
}

// MARK: - 主视图
struct HomeView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var dataManager: DataManager
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer(minLength: 8)
                    
                    // 顶部欢迎区域
                    WelcomeHeaderView()
                    
                    // 主要统计卡片
                    MainStatsCard()
                    
                    // 快捷操作卡片
                    QuickActionsCard()
                    
                    // 学习建议
                    StudySuggestionsCard()
                    
                    // 图表区域
                    if !recentGrades.isEmpty {
                        ChartSectionView()
                    }
                    
                    // 即将到来的考试
                    if !upcomingExams.isEmpty {
                        UpcomingExamsSection()
                    }
                    
                    // 每日励志语录
                    DailyQuoteCard(quote: dailyQuote)
                    
                    // 最近成绩趋势
                    if !recentGrades.isEmpty {
                        RecentGradesSection()
                    }
                    
                    Spacer(minLength: 20)
                }
            }
            .background(getBackgroundColor(colorScheme))
            .navigationTitle("Dashboard")
            .navigationBarHidden(true)
        }
    }
    
    var recentGrades: [Grade] {
        Array(dataManager.grades.sorted { $0.date > $1.date }.prefix(5))
    }
    
    var upcomingExams: [Exam] {
        let twoWeeksFromNow = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
        return dataManager.examSets
            .filter { $0.examDate > Date() && $0.examDate <= twoWeeksFromNow }
            .sorted { $0.examDate < $1.examDate }
    }
}

// MARK: - 顶部欢迎区域
struct WelcomeHeaderView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(greetingText())
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text("Ready to study!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(currentDateText())
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(.systemBlue).opacity(0.2), Color(.cyan).opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 28))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(.systemBlue), Color(.cyan)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .padding(.horizontal, 20)
    }
    
    private func greetingText() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "Good Morning"
        } else if hour < 18 {
            return "Good Afternoon"
        } else {
            return "Good Evening"
        }
    }
    
    private func currentDateText() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }
}

// MARK: - 主要统计卡片
struct MainStatsCard: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var animateGradient = false
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                // 平均分卡片
                StatItemView(
                    title: "Average",
                    value: averageScoreText(),
                    icon: "chart.line.uptrend.xyaxis",
                    color: .cyan
                )
                
                // 总分数卡片
                StatItemView(
                    title: "Total Grades",
                    value: "\(dataManager.grades.count)",
                    icon: "doc.text.fill",
                    color: .purple
                )
            }
            
            HStack(spacing: 16) {
                // 即将考试
                StatItemView(
                    title: "Upcoming",
                    value: "\(upcomingExamsCount)",
                    icon: "calendar.badge.exclamationmark",
                    color: .orange
                )
                
                // 错题本数量
                StatItemView(
                    title: "Mistakes",
                    value: "\(dataManager.mistakeSets.count)",
                    icon: "exclamationmark.triangle.fill",
                    color: .red
                )
            }
        }
        .padding(20)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.secondarySystemGroupedBackground))
                
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemBlue).opacity(0.06),
                        Color(.cyan).opacity(0.03)
                    ]),
                    startPoint: animateGradient ? .topLeading : .bottomTrailing,
                    endPoint: animateGradient ? .bottomTrailing : .topLeading
                )
                .clipShape(RoundedRectangle(cornerRadius: 24))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(.systemBlue).opacity(0.3),
                            Color(.cyan).opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(
            color: Color.black.opacity(0.08),
            radius: 16,
            x: 0,
            y: 8
        )
        .padding(.horizontal, 20)
        .onAppear {
            withAnimation(.easeInOut(duration: 6.0).repeatForever(autoreverses: true)) {
                animateGradient = true
            }
        }
    }
    
    private var upcomingExamsCount: Int {
        let twoWeeksFromNow = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
        return dataManager.examSets
            .filter { $0.examDate > Date() && $0.examDate <= twoWeeksFromNow }
            .count
    }
    
    private func averageScoreText() -> String {
        guard !dataManager.grades.isEmpty else { return "N/A" }
        let total = dataManager.grades.reduce(0) { $0 + $1.score }
        let average = total / Double(dataManager.grades.count)
        return String(format: "%.1f", average)
    }
}

// MARK: - 单个统计项目
struct StatItemView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(color)
                }
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color(.systemBackground).opacity(0.6))
        .cornerRadius(16)
    }
}

// MARK: - 快捷操作卡片
struct QuickActionsCard: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingAddGrade = false
    @State private var showingNewExam = false
    @State private var showingNewMistake = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            HStack(spacing: 12) {
                QuickActionButton(
                    title: "Add Grade",
                    icon: "plus.circle.fill",
                    color: .cyan,
                    action: { showingAddGrade = true }
                )
                
                QuickActionButton(
                    title: "New Exam",
                    icon: "calendar.badge.plus",
                    color: .purple,
                    action: { showingNewExam = true }
                )
                
                QuickActionButton(
                    title: "Mistake",
                    icon: "pencil.tip.crop.circle.badge.plus",
                    color: .orange,
                    action: { showingNewMistake = true }
                )
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(
            color: Color.black.opacity(0.05),
            radius: 10,
            x: 0,
            y: 4
        )
        .padding(.horizontal, 20)
        .sheet(isPresented: $showingAddGrade) {
            AddGradeView()
                .environmentObject(dataManager)
        }
        .sheet(isPresented: $showingNewExam) {
            NewExamSetView()
        }
        .sheet(isPresented: $showingNewMistake) {
            NewMistakeSetView()
                .environmentObject(dataManager)
        }
    }
}

// MARK: - 快捷操作按钮
struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.2), color.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 60)
                    
                    Image(systemName: icon)
                        .font(.system(size: 28))
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 缩放按钮样式
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - 即将到来的考试区域
struct UpcomingExamsSection: View {
    @EnvironmentObject var dataManager: DataManager
    
    var upcomingExams: [Exam] {
        let twoWeeksFromNow = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
        return dataManager.examSets
            .filter { $0.examDate > Date() && $0.examDate <= twoWeeksFromNow }
            .sorted { $0.examDate < $1.examDate }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Upcoming Exams")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(upcomingExams.count)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(.systemOrange), Color(.orange)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
            }
            
            VStack(spacing: 12) {
                ForEach(upcomingExams.prefix(3)) { exam in
                    CompactExamCard(exam: exam)
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(
            color: Color.black.opacity(0.05),
            radius: 10,
            x: 0,
            y: 4
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - 紧凑考试卡片
struct CompactExamCard: View {
    let exam: Exam
    @State private var animateIn = false
    
    private var daysRemaining: Int {
        let components = Calendar.current.dateComponents([.day], from: Date(), to: exam.examDate)
        return max(0, components.day ?? 0)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // 日期显示
            VStack(spacing: 4) {
                Text(dayString(from: exam.examDate))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(monthString(from: exam.examDate))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(width: 60)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
            
            // 考试信息
            VStack(alignment: .leading, spacing: 6) {
                Text(exam.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(exam.subject.localized())
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(.systemBlue).opacity(0.8), Color(.blue)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                    
                    Text(daysRemainingText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(daysRemaining <= 3 ? Color(.systemRed) : .secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(14)
        .background(Color(.systemBackground).opacity(0.6))
        .cornerRadius(16)
        .opacity(animateIn ? 1 : 0)
        .offset(x: animateIn ? 0 : 20)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                animateIn = true
            }
        }
    }
    
    private var daysRemainingText: String {
        if daysRemaining == 0 {
            return "Today!"
        } else if daysRemaining == 1 {
            return "1 day"
        } else {
            return "\(daysRemaining) days"
        }
    }
    
    private func dayString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private func monthString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }
}

// MARK: - 每日励志语录卡片
struct DailyQuoteCard: View {
    let quote: String
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "quote.opening")
                    .font(.system(size: 24))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(.systemBlue), Color(.cyan)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .shadow(color: Color(.cyan).opacity(0.2), radius: 4, x: 0, y: 2)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Daily Inspiration")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(quote)
                        .font(.system(size: 15, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack {
                        Spacer()
                        Text("StudyPulse")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary.opacity(0.6))
                            .italic()
                    }
                }
            }
        }
        .padding(20)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.secondarySystemGroupedBackground))
                
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemBlue).opacity(0.06),
                        Color(.cyan).opacity(0.02)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(.systemBlue).opacity(0.25),
                            Color(.cyan).opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(
            color: Color.black.opacity(0.06),
            radius: 12,
            x: 0,
            y: 6
        )
        .padding(.horizontal, 20)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - 最近成绩区域
struct RecentGradesSection: View {
    @EnvironmentObject var dataManager: DataManager
    
    var recentGrades: [Grade] {
        Array(dataManager.grades.sorted { $0.date > $1.date }.prefix(4))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Grades")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                NavigationLink(destination: TrendsView().environmentObject(dataManager)) {
                    Text("See All")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                }
            }
            
            VStack(spacing: 10) {
                ForEach(recentGrades) { grade in
                    GradeRowView(grade: grade)
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(
            color: Color.black.opacity(0.05),
            radius: 10,
            x: 0,
            y: 4
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - 成绩行视图
struct GradeRowView: View {
    let grade: Grade
    @State private var animateIn = false
    
    var body: some View {
        NavigationLink(destination: GradeDetailView(grade: grade)) {
            HStack(spacing: 16) {
                // 分数圆形
                ZStack {
                    Circle()
                        .fill(scoreColor(grade.score).opacity(0.15))
                        .frame(width: 56, height: 56)
                    
                    Text(String(format: "%.0f", grade.score))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(scoreColor(grade.score))
                }
                
                // 信息
                VStack(alignment: .leading, spacing: 6) {
                    Text(grade.examName.isEmpty ? "Exam" : grade.examName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text(grade.subject.localized())
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary.opacity(0.5))
                        
                        Text(grade.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(14)
            .background(Color(.systemBackground).opacity(0.6))
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(animateIn ? 1 : 0)
        .offset(x: animateIn ? 0 : 20)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05)) {
                animateIn = true
            }
        }
    }
}

// MARK: - 成绩详情视图
struct GradeDetailView: View {
    let grade: Grade
    
    var body: some View {
        List {
            Section(header: Text("Exam Details")
                .foregroundColor(.secondary)
            ) {
                HStack {
                    Text("Exam Name")
                        .foregroundColor(.primary)
                    Spacer()
                    Text(grade.examName.isEmpty ? "N/A" : grade.examName)
                        .foregroundColor(.primary)
                }
                
                HStack {
                    Text("Subject")
                        .foregroundColor(.primary)
                    Spacer()
                    Text(grade.subject.localized())
                        .foregroundColor(.primary)
                }
                
                HStack {
                    Text("Date")
                        .foregroundColor(.primary)
                    Spacer()
                    Text(grade.date.formatted(date: .long, time: .shortened))
                        .foregroundColor(.primary)
                }
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))
            
            Section(header: Text("Score")
                .foregroundColor(.secondary)
            ) {
                HStack {
                    Text("Score")
                        .foregroundColor(.primary)
                    Spacer()
                    Text(String(format: "%.1f", grade.score))
                        .foregroundColor(scoreColor(grade.score))
                        .font(.system(size: 20, weight: .bold))
                }
                
                HStack {
                    Text("Importance")
                        .foregroundColor(.primary)
                    Spacer()
                    HStack(spacing: 4) {
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
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Grade Detail")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 科目选择规则
enum SubjectSelectionRule {
    case lowestScore       // 最低分数科目
    case mostGrades        // 成绩最多的科目
    case recentMost        // 最近成绩最多的科目
    case mostImprovement   // 进步最大的科目
    case random            // 随机科目
}

// MARK: - 图表区域视图
struct ChartSectionView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var currentRule: SubjectSelectionRule = .lowestScore
    @State private var selectedSubject: String? = nil
    @State private var animateChart = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题和规则选择
            HStack {
                Text("Subject Trend")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Menu {
                    Button(action: { selectSubject(rule: .lowestScore) }) {
                        Label("Focus: Lowest Score", systemImage: "chart.line.downtrend.xyaxis")
                    }
                    Button(action: { selectSubject(rule: .mostGrades) }) {
                        Label("Focus: Most Data", systemImage: "doc.text.fill")
                    }
                    Button(action: { selectSubject(rule: .recentMost) }) {
                        Label("Focus: Recent Activity", systemImage: "clock")
                    }
                    Button(action: { selectSubject(rule: .mostImprovement) }) {
                        Label("Focus: Improvement", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    Button(action: { selectSubject(rule: .random) }) {
                        Label("Random Subject", systemImage: "shuffle")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(ruleDescription)
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
            
            // 图表显示
            if let subject = selectedSubject, let grades = gradesForSubject(subject) {
                VStack(spacing: 12) {
                    // 科目信息
                    HStack {
                        Text(subject.localized())
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("\(grades.count) records")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    // 图表
                    Chart(grades.sorted(by: { $0.date < $1.date })) { grade in
                        LineMark(
                            x: .value("Date", grade.date),
                            y: .value("Score", grade.score)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(.systemBlue), Color(.cyan)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .symbol(by: .value("Score", grade.score))
                        
                        PointMark(
                            x: .value("Date", grade.date),
                            y: .value("Score", grade.score)
                        )
                        .symbol {
                            Circle()
                                .fill(Color(.secondarySystemGroupedBackground))
                                .frame(width: 10, height: 10)
                                .overlay {
                                    Circle()
                                        .stroke(scoreColor(grade.score), lineWidth: 2)
                                }
                        }
                    }
                    .frame(height: 180)
                    .opacity(animateChart ? 1 : 0)
                    .offset(y: animateChart ? 0 : 20)
                    
                    // 统计信息
                    HStack(spacing: 20) {
                        StatisticItem(title: "Average", value: String(format: "%.1f", averageScore(for: grades)), color: .cyan)
                        StatisticItem(title: "Highest", value: String(format: "%.1f", highestScore(for: grades)), color: .green)
                        StatisticItem(title: "Lowest", value: String(format: "%.1f", lowestScore(for: grades)), color: .orange)
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
                    Text("Select a subject to view trends")
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
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(
            color: Color.black.opacity(0.05),
            radius: 10,
            x: 0,
            y: 4
        )
        .padding(.horizontal, 20)
        .onAppear {
            selectSubject(rule: currentRule)
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                animateChart = true
            }
        }
    }
    
    private var ruleDescription: String {
        switch currentRule {
        case .lowestScore: return "Focus: Weakest"
        case .mostGrades: return "Focus: Most Data"
        case .recentMost: return "Focus: Recent"
        case .mostImprovement: return "Focus: Improving"
        case .random: return "Random"
        }
    }
    
    private func selectSubject(rule: SubjectSelectionRule) {
        currentRule = rule
        
        let activeSubjects = Set(dataManager.grades.map { $0.subject })
        guard !activeSubjects.isEmpty else {
            selectedSubject = nil
            return
        }
        
        switch rule {
        case .lowestScore:
            selectedSubject = findLowestScoreSubject(from: activeSubjects)
        case .mostGrades:
            selectedSubject = findMostGradesSubject(from: activeSubjects)
        case .recentMost:
            selectedSubject = findRecentMostSubject(from: activeSubjects)
        case .mostImprovement:
            selectedSubject = findMostImprovedSubject(from: activeSubjects)
        case .random:
            selectedSubject = activeSubjects.randomElement()
        }
        
        // 重置并重新播放动画
        animateChart = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animateChart = true
            }
        }
    }
    
    private func findLowestScoreSubject(from subjects: Set<String>) -> String? {
        var lowestScore = Double.infinity
        var lowestSubject: String? = nil
        
        for subject in subjects {
            let grades = dataManager.grades.filter { $0.subject == subject }
            guard !grades.isEmpty else { continue }
            let avg = grades.reduce(0) { $0 + $1.score } / Double(grades.count)
            if avg < lowestScore {
                lowestScore = avg
                lowestSubject = subject
            }
        }
        return lowestSubject
    }
    
    private func findMostGradesSubject(from subjects: Set<String>) -> String? {
        subjects.max { subject1, subject2 in
            let count1 = dataManager.grades.filter { $0.subject == subject1 }.count
            let count2 = dataManager.grades.filter { $0.subject == subject2 }.count
            return count1 < count2
        }
    }
    
    private func findRecentMostSubject(from subjects: Set<String>) -> String? {
        var recentCounts: [String: Int] = [:]
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        
        for subject in subjects {
            let count = dataManager.grades.filter { 
                $0.subject == subject && $0.date >= thirtyDaysAgo 
            }.count
            recentCounts[subject] = count
        }
        
        return recentCounts.max { $0.value < $1.value }?.key
    }
    
    private func findMostImprovedSubject(from subjects: Set<String>) -> String? {
        var bestImprovement = -Double.infinity
        var bestSubject: String? = nil
        
        for subject in subjects {
            let grades = dataManager.grades
                .filter { $0.subject == subject }
                .sorted(by: { $0.date < $1.date })
            guard grades.count >= 2 else { continue }
            
            let first = grades.first!.score
            let last = grades.last!.score
            let improvement = last - first
            
            if improvement > bestImprovement {
                bestImprovement = improvement
                bestSubject = subject
            }
        }
        return bestSubject
    }
    
    private func gradesForSubject(_ subject: String) -> [Grade]? {
        let grades = dataManager.grades.filter { $0.subject == subject }
        return grades.isEmpty ? nil : grades
    }
    
    private func averageScore(for grades: [Grade]) -> Double {
        grades.reduce(0) { $0 + $1.score } / Double(grades.count)
    }
    
    private func highestScore(for grades: [Grade]) -> Double {
        grades.max { $0.score < $1.score }?.score ?? 0
    }
    
    private func lowestScore(for grades: [Grade]) -> Double {
        grades.min { $0.score < $1.score }?.score ?? 0
    }
}

// MARK: - 统计项视图
struct StatisticItem: View {
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

// MARK: - 学习建议卡片
struct StudySuggestionsCard: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var suggestions: [StudySuggestion] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Study Suggestions")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.yellow)
            }
            
            if suggestions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("Start adding grades to get suggestions!")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(suggestions.prefix(3), id: \.id) { suggestion in
                        SuggestionRowView(suggestion: suggestion)
                    }
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(
            color: Color.black.opacity(0.05),
            radius: 10,
            x: 0,
            y: 4
        )
        .padding(.horizontal, 20)
        .onAppear {
            generateSuggestions()
        }
    }
    
    private func generateSuggestions() {
        var newSuggestions: [StudySuggestion] = []
        
        // 建议1：关注最低分科目
        if let weakSubject = findWeakSubject() {
            newSuggestions.append(
                StudySuggestion(
                    icon: "exclamationmark.triangle.fill",
                    title: "Focus on \(weakSubject.localized())",
                    description: "Your scores in this subject are lower than average. Spend more time reviewing key concepts.",
                    priority: .high,
                    color: .orange
                )
            )
        }
        
        // 建议2：复习错题
        if dataManager.mistakeSets.count >= 3 {
            newSuggestions.append(
                StudySuggestion(
                    icon: "book.fill",
                    title: "Review Mistakes",
                    description: "You have \(dataManager.mistakeSets.count) mistake notes. Regular review helps prevent similar errors.",
                    priority: .medium,
                    color: .purple
                )
            )
        }
        
        // 建议3：即将到来的考试
        let upcomingExams = dataManager.examSets.filter { 
            $0.examDate > Date() && 
            $0.examDate <= Calendar.current.date(byAdding: .day, value: 14, to: Date())!
        }
        if !upcomingExams.isEmpty {
            newSuggestions.append(
                StudySuggestion(
                    icon: "calendar.badge.exclamationmark",
                    title: "Prepare for Exams",
                    description: "You have \(upcomingExams.count) exam(s) coming up in the next 2 weeks. Start your preparations now!",
                    priority: .high,
                    color: .red
                )
            )
        }
        
        // 建议4：保持势头
        if let strongSubject = findStrongSubject() {
            newSuggestions.append(
                StudySuggestion(
                    icon: "hand.thumbsup.fill",
                    title: "Great at \(strongSubject.localized())!",
                    description: "Keep up the good work! You're performing really well in this subject.",
                    priority: .low,
                    color: .green
                )
            )
        }
        
        // 建议5：记录更多成绩
        if dataManager.grades.count < 5 {
            newSuggestions.append(
                StudySuggestion(
                    icon: "plus.circle.fill",
                    title: "Add More Grades",
                    description: "Tracking more grades will help you get better insights into your learning progress.",
                    priority: .low,
                    color: .cyan
                )
            )
        }
        
        suggestions = newSuggestions
    }
    
    private func findWeakSubject() -> String? {
        let subjects = Set(dataManager.grades.map { $0.subject })
        guard subjects.count >= 2 else { return nil }
        
        var lowestScore = Double.infinity
        var lowestSubject: String? = nil
        
        for subject in subjects {
            let grades = dataManager.grades.filter { $0.subject == subject }
            guard grades.count >= 2 else { continue }
            let avg = grades.reduce(0) { $0 + $1.score } / Double(grades.count)
            if avg < lowestScore {
                lowestScore = avg
                lowestSubject = subject
            }
        }
        return lowestSubject
    }
    
    private func findStrongSubject() -> String? {
        let subjects = Set(dataManager.grades.map { $0.subject })
        guard !subjects.isEmpty else { return nil }
        
        var highestScore = -Double.infinity
        var highestSubject: String? = nil
        
        for subject in subjects {
            let grades = dataManager.grades.filter { $0.subject == subject }
            guard grades.count >= 2 else { continue }
            let avg = grades.reduce(0) { $0 + $1.score } / Double(grades.count)
            if avg > highestScore {
                highestScore = avg
                highestSubject = subject
            }
        }
        return highestSubject
    }
}

// MARK: - 学习建议模型
struct StudySuggestion: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let priority: Priority
    let color: Color
    
    enum Priority {
        case high, medium, low
    }
}

// MARK: - 建议行视图
struct SuggestionRowView: View {
    let suggestion: StudySuggestion
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                // 图标
                ZStack {
                    Circle()
                        .fill(suggestion.color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: suggestion.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(suggestion.color)
                }
                
                // 内容
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(suggestion.description)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(isExpanded ? nil : 2)
                }
                
                Spacer()
                
                // 优先级标记
                PriorityIndicator(priority: suggestion.priority)
            }
            
            if !isExpanded {
                Button(action: { isExpanded = true }) {
                    Text("Read more")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(14)
        .background(Color(.systemBackground).opacity(0.6))
        .cornerRadius(14)
    }
}

// MARK: - 优先级指示器
struct PriorityIndicator: View {
    let priority: StudySuggestion.Priority
    
    var body: some View {
        ZStack {
            Capsule()
                .fill(color.opacity(0.15))
            
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
        }
        .frame(height: 20)
    }
    
    private var label: String {
        switch priority {
        case .high: return "HIGH"
        case .medium: return "MED"
        case .low: return "LOW"
        }
    }
    
    private var color: Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .green
        }
    }
}

// MARK: - Previews
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
