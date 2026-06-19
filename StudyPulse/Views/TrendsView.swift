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
    
    // score = ranking = 
    @State var trendsShowingMode = "score"
    
    // 
    var activeSubjects: [String] {
        dataManager.subjects
            .filter { $0.enabled }
            .map { $0.name }
            .filter { hasGrades(for: $0) }
    }
    
    // 
    var subjectsNeedingAttention: [String] {
        activeSubjects.filter { subject in
            let grades = getGradeHistory(for: subject)
            guard grades.count >= 2 else { return false }
            
            let recentGrades = Array(grades.suffix(3))
            let avgScore = recentGrades.map { $0.score }.reduce(0, +) / Double(recentGrades.count)
            
            // 70
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
                    if activeSubjects.isEmpty {
                        // 空状态
                        ContentUnavailableView(
                            "No Grades Yet".localized(),
                            systemImage: "chart.xyaxis.line",
                            description: Text("Add grades to see your trends here.".localized())
                        )
                        .padding(.top, 100)
                    } else {
                        if !subjectsNeedingAttention.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text("Subjects Needing Attention".localized())
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

                        LazyVGrid(columns: AdaptiveGridColumns().columns, spacing: 20) {
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
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Trends".localized())
            // iPad 上撑满 detail 区宽度
            .frame(maxWidth: .infinity)

            //
            .navigationDestination(for: String.self) { subjectName in
                SubjectDetailView(
                    subject: subjectName,
                    displayMode: $trendsShowingMode
                )
                .environmentObject(dataManager)
            }
            .toolbar {
                //  /  
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            trendsShowingMode = "score"
                        } label: {
                            Label("", systemImage: "chart.bar.fill")
                        }
                        
                        Button {
                            trendsShowingMode = "ranking"
                        } label: {
                            Label("", systemImage: "trophy.fill")
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
                
                // 
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddGrade = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddGrade) {
                AddGradeView()
                    .adaptiveSheet()
            }
        }
    }
    
    // 
    private func hasGrades(for subject: String) -> Bool {
        dataManager.grades.contains { $0.subject == subject }
    }
    
    // 
    private func getLatestGrade(for subject: String) -> Grade? {
        dataManager.grades
            .filter { $0.subject == subject }
            .sorted { $0.date < $1.date }
            .last
    }
    
    // 
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
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var selectedRange: TimeRange = .all
    @State private var showingAddGrade = false

    enum TimeRange: String, CaseIterable {
        case all = "All"
        case last3Months = "3 Months"
        case last6Months = "6 Months"
        case lastYear = "1 Year"
    }

    private var chartHeight: CGFloat {
        sizeClass == .regular ? 380 : 300
    }
    
    // 
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
    
    // 
    var averageScore: Double {
        guard !filteredGrades.isEmpty else { return 0 }
        return filteredGrades.map{$0.score}.reduce(0,+)/Double(filteredGrades.count)
    }
    
    // 3
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
                    // 
                    Text(subject.localized())
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(Color(.label))
                    
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            // 
                            if displayMode == "score" {
                                Text("Average Score".localized())
                                    .font(.subheadline)
                                    .foregroundColor(Color(.secondaryLabel))
                                    .tracking(0.5)
                                Text(String(format: "%.1f", averageScore))
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundStyle(scoreColor(averageScore))
                            } else {
                                Text("Average Rank".localized())
                                    .font(.subheadline)
                                    .foregroundColor(Color(.secondaryLabel))
                                    .tracking(0.5)
                                Text(averageRank == 0 ? "N/A".localized() : "\(averageRank)")
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
                            Text("Latest".localized())
                                .font(.subheadline)
                                .foregroundColor(Color(.secondaryLabel))
                                .tracking(0.5)
                            
                            if let latest = filteredGrades.last {
                                // 4
                                if displayMode == "score" {
                                    Text(String(format: "%.1f", latest.score))
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundStyle(scoreColor(latest.score))
                                } else {
                                    let rank = latest.ranking ?? 0
                                    Text(rank == 0 ? "N/A".localized() : "\(rank)")
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
                                Text("N/A".localized())
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
                
                // 
                Picker("Time Range".localized(), selection: $selectedRange) {
                    ForEach(TimeRange.allCases, id:\.self) {
                        Text($0.rawValue.localized())
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                //  displayMode /
                if !filteredGrades.isEmpty {
                    Chart(filteredGrades) { grade in
                        // 
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
                        // 5
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
                    .frame(height: chartHeight)
                } else {
                    ContentUnavailableView("No Data".localized(), systemImage: "chart.line.xaxis.dashed")
                        .frame(height: chartHeight)
                }
                
                // 
                VStack(alignment:.leading, spacing:12) {
                    Text("History".localized())
                        .font(.title2)
                        .bold()
                        .foregroundColor(Color(.label))
                    
                    if filteredGrades.isEmpty {
                        Text("No grades available".localized())
                            .foregroundColor(Color(.secondaryLabel))
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                    } else {
                        ForEach(filteredGrades.reversed()) { grade in
                            HStack {
                                VStack(alignment:.leading) {
                                    Text(grade.examName.isEmpty ? "Unnamed Exam".localized() : grade.examName)
                                        .foregroundColor(Color(.label))
                                    Text(grade.date.formatted(date:.abbreviated, time:.omitted))
                                        .font(.caption)
                                        .foregroundColor(Color(.secondaryLabel))
                                }
                                
                                Spacer()
                                
                                // 6
                                if displayMode == "score" {
                                    Text(String(format: "%.1f", grade.score))
                                        .bold()
                                        .foregroundColor(scoreColor(grade.score))
                                } else {
                                    let rank = grade.ranking ?? 0
                                    Text(rank == 0 ? "N/A".localized() : "\(rank)")
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
                                    Label("Delete".localized(), systemImage:"trash.fill")
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
        .adaptiveMaxWidth(960)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddGrade = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddGrade) {
            AddGradeView()
                .adaptiveSheet()
        }
    }
    
    // 
    private func deleteGrade(_ grade: Grade) {
        dataManager.deleteGrade(grade)
    }
}

// MARK: - 需要引起重视的科目卡片
struct AttentionSubjectCard: View {
    let subjectName: String
    let grades: [Grade]
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var animateIn = false

    var recentGrades: [Grade] {
        Array(grades.sorted { $0.date > $1.date }.prefix(3))
    }

    var averageScore: Double {
        guard !grades.isEmpty else { return 0 }
        return grades.map { $0.score }.reduce(0, +) / Double(grades.count)
    }

    var trend: String {
        guard grades.count >= 2 else { return "N/A".localized() }
        let sorted = grades.sorted { $0.date < $1.date }
        let oldScore = sorted.first!.score
        let newScore = sorted.last!.score

        if newScore > oldScore + 5 {
            return "Improving".localized()
        } else if newScore < oldScore - 5 {
            return "Declining".localized()
        } else {
            return "Stable".localized()
        }
    }

    private var cardWidth: CGFloat {
        sizeClass == .regular ? 240 : 200
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
                    Text("Avg Score".localized())
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f", averageScore))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(scoreColor(averageScore))
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trend".localized())
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
        .frame(width: cardWidth)
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
