//
//  TrendsView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import SwiftUI
import Charts
import Combine

struct TrendsView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingAddGrade = false
    
    // 显示模式：score = 分数模式，ranking = 排名模式
    @State var trendsShowingMode = "score"
    
    // 获取已启用且有成绩的科目
    var activeSubjects: [String] {
        dataManager.subjects
            .filter { $0.enabled }
            .map { $0.name }
            .filter { hasGrades(for: $0) }
    }
    
    // 需要引起重视的科目
    var subjectsNeedingAttention: [String] {
        activeSubjects.filter { subject in
            let grades = getGradeHistory(for: subject)
            guard grades.count >= 2 else { return false }
            
            let recentGrades = Array(grades.suffix(3))
            let avgScore = recentGrades.map { $0.score }.reduce(0, +) / Double(recentGrades.count)
            
            // 平均分低于70或最近成绩有下降趋势
            if avgScore < 70 {
                return true
            }
            
            if recentGrades.count >= 2 {
                let first = recentGrades.first!.score
                let last = recentGrades.last!.score
                if last < first - 15 {
                    return true
                }
            }
            
            return false
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 需要引起重视的科目提示
                    if !subjectsNeedingAttention.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Subjects Needing Attention")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(subjectsNeedingAttention, id: \.self) { subjectName in
                                        NavigationLink(value: subjectName) {
                                            AttentionSubjectCard(subjectName: subjectName, grades: getGradeHistory(for: subjectName))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    
                    LazyVStack(spacing: 20) {
                        ForEach(activeSubjects, id: \.self) { subjectName in
                            NavigationLink(value: subjectName) {
                                SubjectScoreCard(
                                    subject: subjectName,
                                    latestGrade: getLatestGrade(for: subjectName),
                                    history: getGradeHistory(for: subjectName),
                                    displayMode: trendsShowingMode
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Trends")
            
            // 跳转到科目详情页
            .navigationDestination(for: String.self) { subjectName in
                SubjectDetailView(
                    subject: subjectName,
                    displayMode: $trendsShowingMode
                )
                .environmentObject(dataManager)
            }
            .toolbar {
                // 分数 / 排名 切换菜单
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            trendsShowingMode = "score"
                        } label: {
                            Label("分数", systemImage: "chart.bar.fill")
                        }
                        
                        Button {
                            trendsShowingMode = "ranking"
                        } label: {
                            Label("排名", systemImage: "trophy.fill")
                        }
                    } label: {
                        if trendsShowingMode == "score" {
                            Image(systemName: "chart.bar.fill")
                                .symbolVariant(.circle.fill)
                        } else {
                            Image(systemName: "trophy.fill")
                                .symbolVariant(.circle.fill)
                        }
                    }
                }
                
                // 添加成绩按钮
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddGrade = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddGrade) {
                AddGradeView()
            }
        }
    }
    
    // 判断指定科目是否存在成绩
    private func hasGrades(for subject: String) -> Bool {
        dataManager.grades.contains { $0.subject == subject }
    }
    
    // 获取指定科目的最新一次成绩
    private func getLatestGrade(for subject: String) -> Grade? {
        dataManager.grades
            .filter { $0.subject == subject }
            .sorted { $0.date < $1.date }
            .last
    }
    
    // 获取指定科目的全部历史成绩（按时间排序）
    private func getGradeHistory(for subject: String) -> [Grade] {
        dataManager.grades
            .filter { $0.subject == subject }
            .sorted { $0.date < $1.date }
    }
}

// MARK: - 科目详情页
struct SubjectDetailView: View {
    let subject: String
    @EnvironmentObject var dataManager: DataManager
    @Binding var displayMode: String // 修复2：删除重复的 displayMode 声明
    
    @State private var selectedRange: TimeRange = .all
    @State private var showingAddGrade = false

    enum TimeRange: String, CaseIterable {
        case all = "All"
        case last3Months = "3 Months"
        case last6Months = "6 Months"
        case lastYear = "1 Year"
    }
    
    // 根据时间范围筛选成绩
    var filteredGrades: [Grade] {
        let base = dataManager.grades
            .filter { $0.subject == subject }
            .sorted { $0.date < $1.date }
        
        let now = Date()
        let calendar = Calendar.current
        
        switch selectedRange {
        case .all:
            return base
        case .last3Months:
            return base.filter { $0.date >= calendar.date(byAdding: .month, value: -3, to: now)! }
        case .last6Months:
            return base.filter { $0.date >= calendar.date(byAdding: .month, value: -6, to: now)! }
        case .lastYear:
            return base.filter { $0.date >= calendar.date(byAdding: .year, value: -1, to: now)! }
        }
    }
    
    // 平均分计算
    var averageScore: Double {
        guard !filteredGrades.isEmpty else { return 0 }
        return filteredGrades.map{$0.score}.reduce(0,+)/Double(filteredGrades.count)
    }
    
    // 平均排名计算（修复3：安全处理可选值）
    var averageRank: Int {
        let validGrades = filteredGrades.filter { ($0.ranking ?? 0) > 0 }
        guard !validGrades.isEmpty else { return 0 }
        let totalRank = validGrades.compactMap { $0.ranking }.reduce(0, +)
        return totalRank / validGrades.count
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    // 科目名称（本地化显示）
                    Text(subject.localized())
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(Color(.label))
                    
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            // 根据显示模式切换标题
                            if displayMode == "score" {
                                Text("Average Score")
                                    .font(.subheadline)
                                    .foregroundColor(Color(.secondaryLabel))
                                    .tracking(0.5)
                                Text(String(format: "%.1f", averageScore))
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundStyle(scoreColor(averageScore))
                            } else {
                                Text("Average Rank")
                                    .font(.subheadline)
                                    .foregroundColor(Color(.secondaryLabel))
                                    .tracking(0.5)
                                Text(averageRank == 0 ? "N/A" : "\(averageRank)")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.indigo, .purple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        VStack(alignment: .trailing, spacing: 8) {
                            Text("Latest")
                                .font(.subheadline)
                                .foregroundColor(Color(.secondaryLabel))
                                .tracking(0.5)
                            
                            if let latest = filteredGrades.last {
                                // 根据模式显示最新分数或排名（修复4：安全解包）
                                if displayMode == "score" {
                                    Text(String(format: "%.1f", latest.score))
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundStyle(scoreColor(latest.score))
                                } else {
                                    let rank = latest.ranking ?? 0
                                    Text(rank == 0 ? "N/A" : "\(rank)")
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.indigo, .purple],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                }
                            } else {
                                Text("N/A")
                                    .foregroundColor(Color(.secondaryLabel))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .padding(18)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.secondarySystemGroupedBackground))
                        
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(.systemBlue).opacity(0.3),
                                        Color(.systemBlue).opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.2
                            )
                    }
                )
                .shadow(
                    color: Color.black.opacity(0.06),
                    radius: 10,
                    x: 0,
                    y: 5
                )
                
                // 时间范围选择器
                Picker("Time Range", selection: $selectedRange) {
                    ForEach(TimeRange.allCases, id:\.self) {
                        Text($0.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // 核心图表：根据 displayMode 切换分数/排名
                if !filteredGrades.isEmpty {
                    Chart(filteredGrades) { grade in
                        // 分数图表
                        if displayMode == "score" {
                            LineMark(
                                x: .value("Date", grade.date),
                                y: .value("Score", grade.score)
                            )
                            .foregroundStyle(Color(.systemBlue))
                            
                            PointMark(
                                x: .value("Date", grade.date),
                                y: .value("Score", grade.score)
                            )
                            .symbol {
                                Circle()
                                    .fill(Color(.systemBackground))
                                    .frame(width: 10, height: 10)
                                    .overlay {
                                        Circle().stroke(scoreColor(grade.score), lineWidth: 2)
                                    }
                            }
                        }
                        // 排名图表（只绘制有效排名，修复5：安全解包）
                        else {
                            if let rank = grade.ranking, rank > 0 {
                                LineMark(
                                    x: .value("Date", grade.date),
                                    y: .value("Rank", rank)
                                )
                                .foregroundStyle(Color(.indigo))
                                
                                PointMark(
                                    x: .value("Date", grade.date),
                                    y: .value("Rank", rank)
                                )
                                .symbol {
                                    Circle()
                                        .fill(Color(.systemBackground))
                                        .frame(width: 10, height: 10)
                                        .overlay {
                                            Circle().stroke(scoreColor(grade.score), lineWidth: 2)
                                        }
                                }
                            }
                        }
                    }
                    .frame(height: 300)
                } else {
                    ContentUnavailableView("No Data", systemImage: "chart.line.xaxis.dashed")
                        .frame(height: 300)
                }
                
                // 历史记录列表
                VStack(alignment:.leading, spacing:12) {
                    Text("History")
                        .font(.title2)
                        .bold()
                        .foregroundColor(Color(.label))
                    
                    if filteredGrades.isEmpty {
                        Text("No grades available")
                            .foregroundColor(Color(.secondaryLabel))
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                    } else {
                        ForEach(filteredGrades.reversed()) { grade in
                            HStack {
                                VStack(alignment:.leading) {
                                    Text(grade.examName.isEmpty ? "Unnamed Exam" : grade.examName)
                                        .foregroundColor(Color(.label))
                                    Text(grade.date.formatted(date:.abbreviated, time:.omitted))
                                        .font(.caption)
                                        .foregroundColor(Color(.secondaryLabel))
                                }
                                
                                Spacer()
                                
                                // 根据显示模式展示分数或排名（修复6：安全解包）
                                if displayMode == "score" {
                                    Text(String(format: "%.1f", grade.score))
                                        .bold()
                                        .foregroundColor(scoreColor(grade.score))
                                } else {
                                    let rank = grade.ranking ?? 0
                                    Text(rank == 0 ? "N/A" : "\(rank)")
                                        .bold()
                                        .foregroundColor(.indigo)
                                }
                            }
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(10)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteGrade(grade)
                                } label: {
                                    Label("Delete", systemImage:"trash.fill")
                                }
                                .tint(Color(.systemRed))
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddGrade = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddGrade) {
            AddGradeView()
        }
    }
    
    // 删除成绩并保存
    private func deleteGrade(_ grade: Grade) {
        if let index = dataManager.grades.firstIndex(where: { $0.id == grade.id }) {
            dataManager.grades.remove(at: index)
            dataManager.saveGrades()
            dataManager.objectWillChange.send()
        }
    }
}

// MARK: - 需要引起重视的科目卡片
struct AttentionSubjectCard: View {
    let subjectName: String
    let grades: [Grade]
    @State private var animateIn = false
    
    var recentGrades: [Grade] {
        Array(grades.sorted { $0.date > $1.date }.prefix(3))
    }
    
    var averageScore: Double {
        guard !grades.isEmpty else { return 0 }
        return grades.map { $0.score }.reduce(0, +) / Double(grades.count)
    }
    
    var trend: String {
        guard grades.count >= 2 else { return "N/A" }
        let sorted = grades.sorted { $0.date < $1.date }
        let oldScore = sorted.first!.score
        let newScore = sorted.last!.score
        
        if newScore > oldScore + 5 {
            return "📈 Improving"
        } else if newScore < oldScore - 5 {
            return "📉 Declining"
        } else {
            return "➡️ Stable"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(subjectName.localized())
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Avg Score")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f", averageScore))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(scoreColor(averageScore))
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trend")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(trend)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            
            if !recentGrades.isEmpty {
                HStack(spacing: 8) {
                    ForEach(recentGrades) { grade in
                        Text(String(format: "%.0f", grade.score))
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(scoreColor(grade.score).opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 200)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(.systemOrange).opacity(0.3), lineWidth: 1.5)
        )
        .opacity(animateIn ? 1 : 0)
        .offset(x: animateIn ? 0 : -20)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.1)) {
                animateIn = true
            }
        }
    }
}

#Preview {
    TrendsView()
        .environmentObject(DataManager())
}

#Preview("Dark Mode") {
    TrendsView()
        .environmentObject(DataManager())
        .preferredColorScheme(.dark)
}
