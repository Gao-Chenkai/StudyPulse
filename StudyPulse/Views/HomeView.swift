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
    "Quote 1".localized(),
    "Quote 2".localized(),
    "Quote 3".localized(),
    "Quote 4".localized(),
    "Quote 5".localized(),
    "Quote 6".localized(),
    "Quote 7".localized(),
    "Quote 8".localized(),
    "Quote 9".localized(),
    "Quote 10".localized(),
    "Quote 11".localized(),
    "Quote 12".localized(),
    "Quote 13".localized(),
    "Quote 14".localized(),
]

var dailyQuote: String {
    let calendar = Calendar.current
    let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 0
    let index = dayOfYear % dailyQuotes.count
    return dailyQuotes[index]
}

// MARK: - 主视图
struct HomeView: View {
    @Binding var selectedTab: Int
    @Environment(\.horizontalSizeClass) private var sizeClass
    @EnvironmentObject var dataManager: DataManager

    private var isRegularWidth: Bool {
        sizeClass == .regular || isIPad
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // 顶部欢迎区域（全宽）
                    WelcomeHeaderView(selectedTab: $selectedTab)

                    // 主要统计卡片（全宽，4 个指标横排）
                    MainStatsCard()

                    // HRV 学习准备度卡片（HealthKit）
                    HRVStatusCard()

                    // 成绩登记提醒（全宽，条件显示）
                    if !unregisteredExams.isEmpty {
                        UnregisteredExamsReminderCard(unregisteredExams: unregisteredExams)
                    }

                    // iPad 两列网格 / iPhone 单列堆叠
                    if sizeClass == .regular || isIPad {
                        iPadGrid
                    } else {
                        iPhoneStack
                    }
                }
                .padding(.horizontal, sizeClass == .regular || isIPad ? 24 : 20)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Dashboard".localized())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // iPad 两列网格
    private var iPadGrid: some View {
        VStack(spacing: 16) {
            // 快捷操作 - 全宽（3 个按钮才能横排）
            QuickActionsCard()
                .frame(maxWidth: .infinity)

            // 学习建议 + 图表
            HStack(alignment: .top, spacing: 16) {
                StudySuggestionsCard()
                    .frame(maxWidth: .infinity)
                if !recentGrades.isEmpty {
                    ChartSectionView()
                        .frame(maxWidth: .infinity)
                }
            }

            // 即将考试 + 最近成绩
            HStack(alignment: .top, spacing: 16) {
                if !upcomingExams.isEmpty {
                    UpcomingExamsSection()
                        .frame(maxWidth: .infinity)
                }
                if !recentGrades.isEmpty {
                    RecentGradesSection()
                        .frame(maxWidth: .infinity)
                }
            }

            // 每日励志全宽
            DailyQuoteCard(quote: dailyQuote)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }

    // iPhone 单列堆叠
    private var iPhoneStack: some View {
        VStack(spacing: 20) {
            QuickActionsCard()
            StudySuggestionsCard()
            if !recentGrades.isEmpty {
                ChartSectionView()
            }
            if !upcomingExams.isEmpty {
                UpcomingExamsSection()
            }
            DailyQuoteCard(quote: dailyQuote)
            if !recentGrades.isEmpty {
                RecentGradesSection()
            }
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
    
    /// 已过 3-7 天但尚未登记成绩的考试（单科目 Exam）
    var unregisteredExams: [Exam] {
        let now = Date()
        let startOfToday = Calendar.current.startOfDay(for: now)
        guard let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: startOfToday),
              let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: startOfToday) else {
            return []
        }
        
        return dataManager.examSets.filter { exam in
            guard exam.examDate < threeDaysAgo && exam.examDate >= sevenDaysAgo else {
                return false
            }
            
            let hasGrade = dataManager.grades.contains { grade in
                grade.subject == exam.subject &&
                grade.examName == exam.examName &&
                grade.date >= exam.examDate
            }
            return !hasGrade
        }.sorted { $0.examDate < $1.examDate }
    }
}

// MARK: - 成绩登记提醒卡片

struct UnregisteredExamsReminderCard: View {
    let unregisteredExams: [Exam]
    @EnvironmentObject var dataManager: DataManager
    @State private var showingAddGrade = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "exclamationmark.bubble.fill")
                    .foregroundColor(.orange)
                Text("Register Exam Grades".localized())
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
            }
            
            ForEach(unregisteredExams) { exam in
                Button {
                    showingAddGrade = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(exam.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.primary)
                            HStack(spacing: 4) {
                                Text(exam.subject.localized())
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("·")
                                    .foregroundColor(.secondary)
                                Text("\(daysSince(exam.examDate)) " + "days ago".localized())
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                        Spacer()
                        Image(systemName: "plus.circle")
                            .font(.system(size: 20))
                            .foregroundColor(.orange)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground).opacity(0.6))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(
            color: Color.black.opacity(0.05),
            radius: 10,
            x: 0,
            y: 4
        )
        .sheet(isPresented: $showingAddGrade) {
            AddGradeView()
                .environmentObject(dataManager)
                .adaptiveSheet()
        }
    }
    
    private func daysSince(_ date: Date) -> Int {
        Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
    }
}

// MARK: - 顶部欢迎区域
struct WelcomeHeaderView: View {
    @Binding var selectedTab: Int
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var dataManager: DataManager
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(greetingText())
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text("Ready to study!".localized())
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(currentDateText())
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                selectedTab = 4
            } label: {
                AvatarView(
                    username: dataManager.profile.username,
                    avatarData: dataManager.loadAvatar(),
                    size: 50,
                    showBorder: true
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    private func greetingText() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "Good Morning".localized()
        } else if hour < 18 {
            return "Good Afternoon".localized()
        } else {
            return "Good Evening".localized()
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
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var animateGradient = false

    private var isWide: Bool { sizeClass == .regular || isIPad }

    var body: some View {
        VStack(spacing: 20) {
            // iPad 一行 4 个，iPhone 仍是 2x2
            if isWide {
                HStack(spacing: 12) {
                    StatItemView(
                        title: "Average".localized(),
                        value: averageScoreText(),
                        icon: "chart.line.uptrend.xyaxis",
                        color: .cyan
                    )
                    StatItemView(
                        title: "Total Grades".localized(),
                        value: "\(dataManager.grades.count)",
                        icon: "doc.text.fill",
                        color: .purple
                    )
                    StatItemView(
                        title: "Upcoming".localized(),
                        value: "\(upcomingExamsCount)",
                        icon: "calendar.badge.exclamationmark",
                        color: .orange
                    )
                    StatItemView(
                        title: "Mistakes".localized(),
                        value: "\(dataManager.mistakeSets.count)",
                        icon: "exclamationmark.triangle.fill",
                        color: .red
                    )
                }
            } else {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        StatItemView(
                            title: "Average".localized(),
                            value: averageScoreText(),
                            icon: "chart.line.uptrend.xyaxis",
                            color: .cyan
                        )
                        StatItemView(
                            title: "Total Grades".localized(),
                            value: "\(dataManager.grades.count)",
                            icon: "doc.text.fill",
                            color: .purple
                        )
                    }
                    HStack(spacing: 12) {
                        StatItemView(
                            title: "Upcoming".localized(),
                            value: "\(upcomingExamsCount)",
                            icon: "calendar.badge.exclamationmark",
                            color: .orange
                        )
                        StatItemView(
                            title: "Mistakes".localized(),
                            value: "\(dataManager.mistakeSets.count)",
                            icon: "exclamationmark.triangle.fill",
                            color: .red
                        )
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
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
            Text("Quick Actions".localized())
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            HStack(spacing: 12) {
                QuickActionButton(
                    title: "Add Grade".localized(),
                    icon: "plus.circle.fill",
                    color: .cyan,
                    action: { showingAddGrade = true }
                )
                
                QuickActionButton(
                    title: "New Exam".localized(),
                    icon: "calendar.badge.plus",
                    color: .purple,
                    action: { showingNewExam = true }
                )
                
                QuickActionButton(
                    title: "New Mistake".localized(),
                    icon: "pencil.tip.crop.circle.badge.plus",
                    color: .orange,
                    action: { showingNewMistake = true }
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(
            color: Color.black.opacity(0.05),
            radius: 10,
            x: 0,
            y: 4
        )
        .sheet(isPresented: $showingAddGrade) {
            AddGradeView()
                .environmentObject(dataManager)
                .adaptiveSheet()
        }
        .sheet(isPresented: $showingNewExam) {
            NewExamSetView()
                .adaptiveSheet()
        }
        .sheet(isPresented: $showingNewMistake) {
            NewMistakeSetView()
                .environmentObject(dataManager)
                .adaptiveSheet()
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
                Text("Upcoming Exams".localized())
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(
            color: Color.black.opacity(0.05),
            radius: 10,
            x: 0,
            y: 4
        )
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
        .cornerRadius(14)
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 12)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                animateIn = true
            }
        }
    }
    
    private var daysRemainingText: String {
        if daysRemaining == 0 {
            return "Today!".localized()
        } else if daysRemaining == 1 {
            return "Tomorrow".localized()
        } else {
            return "\(daysRemaining) " + "days".localized()
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

// MARK: - 每日励志卡片
struct DailyQuoteCard: View {
    let quote: String
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "quote.bubble.fill")
                    .font(.system(size: 28))
                    .foregroundColor(Color(.systemIndigo).opacity(0.6))
                
                Text(quote)
                    .font(.system(size: 15, weight: .medium, design: .serif))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 16)
            }
            Spacer()
        }
        .frame(minHeight: 140)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.secondarySystemGroupedBackground))
                
                RadialGradient(
                    colors: [
                        Color(.systemIndigo).opacity(0.06),
                        Color.clear
                    ],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 200
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
        )
        .shadow(
            color: Color.black.opacity(0.05),
            radius: 10,
            x: 0,
            y: 4
        )
    }
}

// MARK: - 最近成绩区域
struct RecentGradesSection: View {
    @EnvironmentObject var dataManager: DataManager
    
    var recentGrades: [Grade] {
        Array(dataManager.grades.sorted { $0.date > $1.date }.prefix(5))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Grades".localized())
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            VStack(spacing: 10) {
                ForEach(recentGrades) { grade in
                    CompactGradeRow(grade: grade)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(
            color: Color.black.opacity(0.05),
            radius: 10,
            x: 0,
            y: 4
        )
    }
}

// MARK: - 紧凑成绩行
struct CompactGradeRow: View {
    let grade: Grade
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(scoreColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Text("\(Int(grade.score))")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(scoreColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(grade.subject.localized())
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(grade.date, style: .date)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let ranking = grade.ranking {
                Text("#\(ranking)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(.systemBackground).opacity(0.6))
        .cornerRadius(12)
    }
    
    private var scoreColor: Color {
        let rate = grade.scoreRate()
        if rate >= 0.85 { return .green }
        if rate >= 0.6 { return .orange }
        return .red
    }
}

// MARK: - 图表区域

/// 科目选择规则
enum SubjectSelectionRule {
    case lowestScore
    case mostGrades
    case recentMost
    case mostImprovement
    case random
}

/// 单科目趋势图表，用户通过 Menu 选择聚焦规则
struct ChartSectionView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var currentRule: SubjectSelectionRule = .lowestScore
    @State private var selectedSubject: String? = nil
    @State private var animateChart = false

    private var chartHeight: CGFloat {
        isIPad || sizeClass == .regular ? 260 : 180
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Subject Trend".localized())
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Menu {
                    Button(action: { selectSubject(rule: .lowestScore) }) {
                        Label("Focus: Lowest Score".localized(), systemImage: "chart.line.downtrend.xyaxis")
                    }
                    Button(action: { selectSubject(rule: .mostGrades) }) {
                        Label("Focus: Most Data".localized(), systemImage: "doc.text.fill")
                    }
                    Button(action: { selectSubject(rule: .recentMost) }) {
                        Label("Focus: Recent Activity".localized(), systemImage: "clock")
                    }
                    Button(action: { selectSubject(rule: .mostImprovement) }) {
                        Label("Focus: Improvement".localized(), systemImage: "chart.line.uptrend.xyaxis")
                    }
                    Button(action: { selectSubject(rule: .random) }) {
                        Label("Random Subject".localized(), systemImage: "shuffle")
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
            
            if let subject = selectedSubject, let grades = gradesForSubject(subject) {
                VStack(spacing: 12) {
                    HStack {
                        Text(subject.localized())
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(String(format: "%d records".localized(), grades.count))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
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
                    .frame(height: chartHeight)
                    .opacity(animateChart ? 1 : 0)
                    .offset(y: animateChart ? 0 : 20)
                    
                    HStack(spacing: 20) {
                        StatisticItem(title: "Average".localized(), value: String(format: "%.1f", averageScore(for: grades)), color: .cyan)
                        StatisticItem(title: "Highest".localized(), value: String(format: "%.1f", highestScore(for: grades)), color: .green)
                        StatisticItem(title: "Lowest".localized(), value: String(format: "%.1f", lowestScore(for: grades)), color: .orange)
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
                    Text("Select a subject to view trends".localized())
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(
            color: Color.black.opacity(0.05),
            radius: 10,
            x: 0,
            y: 4
        )
        .onAppear {
            selectSubject(rule: currentRule)
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                animateChart = true
            }
        }
    }

    private var ruleDescription: String {
        switch currentRule {
        case .lowestScore: return "Focus: Weakest".localized()
        case .mostGrades: return "Focus: Most Data".localized()
        case .recentMost: return "Focus: Recent".localized()
        case .mostImprovement: return "Focus: Improving".localized()
        case .random: return "Random".localized()
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
                Text("Study Suggestions".localized())
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
                    Text("Start adding grades to get suggestions!".localized())
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(
            color: Color.black.opacity(0.05),
            radius: 10,
            x: 0,
            y: 4
        )
        .onAppear {
            generateSuggestions()
        }
    }
    
    private func generateSuggestions() {
        var newSuggestions: [StudySuggestion] = []
        
        if let weakSubject = findWeakSubject() {
            newSuggestions.append(
                StudySuggestion(
                    icon: "exclamationmark.triangle.fill",
                    title: String(format: "Focus on %@".localized(), weakSubject.localized()),
                    description: "Your scores in this subject are lower than average. Spend more time reviewing key concepts.".localized(),
                    priority: .high,
                    color: .yellow
                )
            )
        }
        
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let urgentExams = dataManager.examSets.filter {
            Calendar.current.isDate($0.examDate, inSameDayAs: Date()) ||
            Calendar.current.isDate($0.examDate, inSameDayAs: tomorrow)
        }
        if !urgentExams.isEmpty {
            newSuggestions.append(
                StudySuggestion(
                    icon: "timer",
                    title: "Exam is almost here!".localized(),
                    description: String(format: "You have %d exam(s) today or tomorrow. Review your notes now!".localized(), urgentExams.count),
                    priority: .high,
                    color: .red
                )
            )
        }
        
        if let declining = findDecliningTrend() {
            newSuggestions.append(
                StudySuggestion(
                    icon: "chart.line.downtrend.xyaxis",
                    title: String(format: "%@ scores are slipping".localized(), declining.localized()),
                    description: "Your recent scores in this subject show a downward trend. Identify what's causing the gap.".localized(),
                    priority: .high,
                    color: .orange
                )
            )
        }
        
        let unreviewedMistakes = findUnreviewedMistakeSubjects()
        if !unreviewedMistakes.isEmpty {
            newSuggestions.append(
                StudySuggestion(
                    icon: "doc.text.magnifyingglass",
                    title: "Unreviewed Mistakes".localized(),
                    description: String(format: "You have mistakes in %@ that haven't been reviewed. Go through them before the next exam.".localized(), unreviewedMistakes.joined(separator: ", ").localized()),
                    priority: .high,
                    color: .purple
                )
            )
        } else if dataManager.mistakeSets.count >= 5 {
            newSuggestions.append(
                StudySuggestion(
                    icon: "book.fill",
                    title: "Review Mistakes".localized(),
                    description: String(format: "You have %d mistake note(s). Regular review helps prevent similar errors.".localized(), dataManager.mistakeSets.count),
                    priority: .medium,
                    color: .purple
                )
            )
        }
        
        let upcomingExams = dataManager.examSets.filter { 
            $0.examDate > Date() && 
            $0.examDate <= Calendar.current.date(byAdding: .day, value: 14, to: Date())!
        }
        if !upcomingExams.isEmpty {
            newSuggestions.append(
                StudySuggestion(
                    icon: "calendar",
                    title: "Upcoming Exams".localized(),
                    description: String(format: "%d exam(s) in the next 2 weeks. Organize your review by subject priority.".localized(), upcomingExams.count),
                    priority: .medium,
                    color: .blue
                )
            )
        }
        
        if let improving = findImprovingTrend() {
            newSuggestions.append(
                StudySuggestion(
                    icon: "chart.line.uptrend.xyaxis",
                    title: String(format: "%@ is improving!".localized(), improving.localized()),
                    description: "Your scores are trending upward. Keep the momentum!".localized(),
                    priority: .medium,
                    color: .green
                )
            )
        }
        
        if let mistakeHeavy = findMistakeHeavySubject() {
            newSuggestions.append(
                StudySuggestion(
                    icon: "text.badge.checkmark",
                    title: String(format: "Deep dive into %@".localized(), mistakeHeavy.localized()),
                    description: "You have many mistakes in this subject. Categorize your errors to find the root pattern.".localized(),
                    priority: .medium,
                    color: .orange
                )
            )
        }
        
        if let lastGradeDate = dataManager.grades.map({ $0.date }).max(),
           Calendar.current.dateComponents([.day], from: lastGradeDate, to: Date()).day ?? 0 >= 7 {
            newSuggestions.append(
                StudySuggestion(
                    icon: "clock.arrow.circlepath",
                    title: "Keep the streak going!".localized(),
                    description: "No new grades in the past week. Regular tracking helps you spot trends early.".localized(),
                    priority: .low,
                    color: .cyan
                )
            )
        }
        
        if let strongSubject = findStrongSubject() {
            newSuggestions.append(
                StudySuggestion(
                    icon: "hand.thumbsup.fill",
                    title: String(format: "Great at %@!".localized(), strongSubject.localized()),
                    description: "Keep up the good work! You're performing really well in this subject.".localized(),
                    priority: .low,
                    color: .green
                )
            )
        }
        
        if dataManager.grades.count < 5 {
            newSuggestions.append(
                StudySuggestion(
                    icon: "plus.circle.fill",
                    title: "Add More Grades".localized(),
                    description: "Tracking more grades will help you get better insights into your learning progress.".localized(),
                    priority: .low,
                    color: .cyan
                )
            )
        }
        
        if let imbalanced = findImbalancedStudy() {
            newSuggestions.append(
                StudySuggestion(
                    icon: "scalemass",
                    title: "Balance your subjects".localized(),
                    description: String(format: "You have significantly more grades in %@ than other subjects. Don't neglect the rest.".localized(), imbalanced.localized()),
                    priority: .low,
                    color: .teal
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
    
    private func findDecliningTrend() -> String? {
        let subjects = Set(dataManager.grades.map { $0.subject })
        for subject in subjects {
            let grades = dataManager.grades
                .filter { $0.subject == subject }
                .sorted { $0.date > $1.date }
            guard grades.count >= 3 else { continue }
            let recent = Array(grades.prefix(3))
            let scores = recent.map { $0.score }
            guard scores[0] < scores[1], scores[1] < scores[2],
                  scores[2] - scores[0] >= 5 else { continue }
            return subject
        }
        return nil
    }
    
    private func findImprovingTrend() -> String? {
        let subjects = Set(dataManager.grades.map { $0.subject })
        for subject in subjects {
            let grades = dataManager.grades
                .filter { $0.subject == subject }
                .sorted { $0.date > $1.date }
            guard grades.count >= 3 else { continue }
            let recent = Array(grades.prefix(3))
            let scores = recent.map { $0.score }
            guard scores[0] > scores[1], scores[1] > scores[2],
                  scores[0] - scores[2] >= 5 else { continue }
            return subject
        }
        return nil
    }
    
    private func findUnreviewedMistakeSubjects() -> [String] {
        let mistakeSubjects = Set(dataManager.mistakeSets.map { $0.subject })
        var unreviewed: [String] = []
        for subject in mistakeSubjects {
            let mistakesInSubject = dataManager.mistakeSets
                .filter { $0.subject == subject }
                .count
            let gradesInSubject = dataManager.grades
                .filter { $0.subject == subject }
                .count
            if mistakesInSubject >= 3 && gradesInSubject == 0 {
                unreviewed.append(subject)
            }
        }
        return Array(unreviewed.prefix(2))
    }
    
    private func findMistakeHeavySubject() -> String? {
        let subjects = Set(dataManager.grades.map { $0.subject })
            .union(dataManager.mistakeSets.map { $0.subject })
        for subject in subjects {
            let mistakeCount = dataManager.mistakeSets
                .filter { $0.subject == subject }.count
            let gradeCount = dataManager.grades
                .filter { $0.subject == subject }.count
            if mistakeCount >= 5 && mistakeCount > gradeCount * 2 {
                return subject
            }
        }
        return nil
    }
    
    private func findImbalancedStudy() -> String? {
        let subjects = Set(dataManager.grades.map { $0.subject })
        guard subjects.count >= 3 else { return nil }
        var counts: [(String, Int)] = []
        for subject in subjects {
            let count = dataManager.grades.filter { $0.subject == subject }.count
            counts.append((subject, count))
        }
        counts.sort { a, b in a.1 > b.1 }
        guard let max = counts.first else { return nil }
        let others = counts.dropFirst()
        var total = 0
        for entry in others { total += entry.1 }
        let avgOthers = others.isEmpty ? 0 : total / others.count
        guard max.1 > avgOthers * 3 else { return nil }
        return max.0
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
                ZStack {
                    Circle()
                        .fill(suggestion.color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: suggestion.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(suggestion.color)
                }
                
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
                
                PriorityIndicator(priority: suggestion.priority)
            }
            
            if !isExpanded {
                Button(action: { isExpanded = true }) {
                    Text("Read more".localized())
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
        case .high: return "HIGH".localized()
        case .medium: return "MED".localized()
        case .low: return "LOW".localized()
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
    HomeView(selectedTab: .constant(0))
        .environmentObject(DataManager())
        .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    HomeView(selectedTab: .constant(0))
        .environmentObject(DataManager())
        .preferredColorScheme(.dark)
}
