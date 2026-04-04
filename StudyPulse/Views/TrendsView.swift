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
    
    var activeSubjects: [String] {
        dataManager.subjects
            .filter { $0.enabled }
            .map { $0.name }
            .filter { hasGrades(for: $0) }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(activeSubjects, id: \.self) { subjectName in
                        NavigationLink(value: subjectName) {
                            SubjectCardView(
                                subject: subjectName,
                                latestGrade: getLatestGrade(for: subjectName)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Trends")
            .navigationDestination(for: String.self) { subjectName in
                SubjectDetailView(subject: subjectName)
                    .environmentObject(dataManager)
            }
        }
    }
    
    private func hasGrades(for subject: String) -> Bool {
        dataManager.grades.contains { $0.subject == subject }
    }
    
    private func getLatestGrade(for subject: String) -> Grade? {
        dataManager.grades
            .filter { $0.subject == subject }
            .sorted { $0.date < $1.date }
            .last
    }
}

// MARK: - 详情页（修复刷新+删除）
struct SubjectDetailView: View {
    let subject: String
    @EnvironmentObject var dataManager: DataManager
    
    @State private var selectedRange: TimeRange = .all
    enum TimeRange: String, CaseIterable {
        case all = "All"
        case last3Months = "3 Months"
        case last6Months = "6 Months"
        case lastYear = "1 Year"
    }
    
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
    
    var averageScore: Double {
        guard !filteredGrades.isEmpty else { return 0 }
        return filteredGrades.map{$0.score}.reduce(0,+)/Double(filteredGrades.count)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(subject).font(.title).fontWeight(.bold)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Average Score").font(.subheadline).foregroundColor(.secondary)
                            Text(String(format: "%.1f", averageScore))
                                .font(.title2).bold()
                                .foregroundColor(scoreColor(averageScore))
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Latest").font(.subheadline).foregroundColor(.secondary)
                            if let latest = filteredGrades.last {
                                Text(String(format: "%.1f", latest.score))
                                    .font(.title2).bold()
                                    .foregroundColor(scoreColor(latest.score))
                            } else {
                                Text("N/A").foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 5)
                
                // 时间分段选择器
                Picker("Time Range", selection: $selectedRange) {
                    ForEach(TimeRange.allCases, id:\.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // 固定高度图表
                if !filteredGrades.isEmpty {
                    Chart(filteredGrades) { grade in
                        LineMark(x: .value("Date", grade.date), y: .value("Score", grade.score))
                            .foregroundStyle(.blue)
                            .interpolationMethod(.catmullRom)
                        PointMark(x: .value("Date", grade.date), y: .value("Score", grade.score))
                            .foregroundStyle(.blue).symbolSize(60)
                    }
                    .frame(height:300)
                } else {
                    ContentUnavailableView("No Data", systemImage: "chart.line.xaxis.dashed")
                        .frame(height:300)
                }
                
                // 历史+侧滑删除
                VStack(alignment:.leading, spacing:12) {
                    Text("History").font(.title2).bold()
                    ForEach(filteredGrades.reversed()) { grade in
                        HStack {
                            VStack(alignment:.leading) {
                                Text(grade.examName.isEmpty ? "Unnamed Exam" : grade.examName)
                                Text(grade.date.formatted(date:.abbreviated, time:.omitted))
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(String(format:"%.1f",grade.score))
                                .bold().foregroundColor(scoreColor(grade.score))
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteGrade(grade)
                            } label: {
                                Label("Delete", systemImage:"trash.fill")
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.large)
        // 强制切换时间刷新UI
        .onChange(of: selectedRange) { oldValue, newValue in
                    // 这里不需要写代码，只要属性变化就会自动触发 View 重绘
                    // 如果以后需要处理逻辑，可以使用 print("范围从 \(oldValue) 变为 \(newValue)")
        }
    }
    
    // 删除核心：手动触发发布者刷新UI
    private func deleteGrade(_ grade:Grade) {
        if let idx = dataManager.grades.firstIndex(where:{$0.id == grade.id}) {
            dataManager.grades.remove(at: idx)
            dataManager.saveGrades()
            dataManager.objectWillChange.send()
        }
    }
    
    private func scoreColor(_ score:Double) -> Color {
        score>=90 ? .green : score>=60 ? .orange : .red
    }
}

struct SubjectCardView: View {
    let subject: String
    let latestGrade: Grade?
    
    var body: some View {
        VStack(alignment:.leading, spacing:10) {
            HStack {
                Text(subject).font(.headline).bold()
                Spacer()
                if let g = latestGrade {
                    Text(String(format:"%.1f",g.score))
                        .font(.title3).bold().foregroundColor(scoreColor(g.score))
                } else {
                    Text("--").foregroundColor(.secondary)
                }
            }
            Divider()
            if let g = latestGrade {
                HStack {
                    HStack(spacing:2) {
                        ForEach(0..<min(g.importance,5), id:\.self) { _ in
                            Image(systemName:"star.fill").foregroundColor(.yellow)
                        }
                    }
                    Spacer()
                    Text(g.date.formatted(date:.abbreviated, time:.omitted))
                        .font(.caption).foregroundColor(.secondary)
                }
            } else {
                Text("No data available").font(.caption).foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color:Color.black.opacity(0.05), radius:8)
    }
    
    private func scoreColor(_ score:Double) -> Color {
        score>=120 ? .blue : score>=90 ? .green : score>=60 ? .orange : .red
    }
}

#Preview {
    TrendsView().environmentObject(DataManager())
}
