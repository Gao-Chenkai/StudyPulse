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
            .background(Color(.systemGroupedBackground))
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
                    Text(subject.localized()).font(.title).fontWeight(.bold)
                        .foregroundColor(Color(.label))
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Average Score").font(.subheadline).foregroundColor(Color(.secondaryLabel))
                            Text(String(format: "%.1f", averageScore))
                                .font(.title2).bold()
                                .foregroundColor(scoreColor(averageScore))
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Latest").font(.subheadline).foregroundColor(Color(.secondaryLabel))
                            if let latest = filteredGrades.last {
                                Text(String(format: "%.1f", latest.score))
                                    .font(.title2).bold()
                                    .foregroundColor(scoreColor(latest.score))
                            } else {
                                Text("N/A").foregroundColor(Color(.secondaryLabel))
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
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
                            .foregroundStyle(Color(.systemBlue))
                            .interpolationMethod(.catmullRom)
                        PointMark(x: .value("Date", grade.date), y: .value("Score", grade.score))
                            .foregroundStyle(Color(.systemBlue)).symbolSize(60)
                    }
                    .frame(height:300)
                } else {
                    ContentUnavailableView("No Data", systemImage: "chart.line.xaxis.dashed")
                        .frame(height:300)
                }
                
                // 历史+侧滑删除
                VStack(alignment:.leading, spacing:12) {
                    Text("History").font(.title2).bold()
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
                                        .font(.caption).foregroundColor(Color(.secondaryLabel))
                                }
                                Spacer()
                                Text(String(format:"%.1f",grade.score))
                                    .bold().foregroundColor(scoreColor(grade.score))
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
        score>=90 ? Color(.systemGreen) : score>=60 ? Color(.systemOrange) : Color(.systemRed)
    }
}

struct SubjectCardView: View {
    let subject: String
    let latestGrade: Grade?
    
    var body: some View {
        VStack(alignment:.leading, spacing:10) {
            HStack {
                Text(subject).font(.headline).bold()
                    .foregroundColor(Color(.label))
                Spacer()
                if let g = latestGrade {
                    Text(String(format:"%.1f",g.score))
                        .font(.title3).bold().foregroundColor(scoreColor(g.score))
                } else {
                    Text("--").foregroundColor(Color(.secondaryLabel))
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
                        .font(.caption).foregroundColor(Color(.secondaryLabel))
                }
            } else {
                Text("No data available").font(.caption).foregroundColor(Color(.secondaryLabel))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color:Color.black.opacity(0.05), radius:8)
    }
    
    private func scoreColor(_ score:Double) -> Color {
        score>=120 ? Color(.systemBlue) : score>=90 ? Color(.systemGreen) : score>=60 ? Color(.systemOrange) : Color(.systemRed)
    }
}

#Preview {
    TrendsView().environmentObject(DataManager())
}

#Preview("Dark Mode") {
    TrendsView()
        .environmentObject(DataManager())
        .preferredColorScheme(.dark)
}
