//
//  ExamView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/23.
//

import SwiftUI

struct ExamView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingNewExamSet = false
    @State private var selectedExamForDetail: Exam? = nil
    @State private var selectedComprehensiveExam: comprehensiveExam? = nil

    // 合并两种考试，并按时间排序
    private var allExams: [Any] {
        var exams: [Any] = []
        exams.append(contentsOf: dataManager.examSets)
        exams.append(contentsOf: dataManager.comprehensiveExamSets)
        
        return exams.sorted { a, b in
            let dateA: Date = (a as? Exam)?.examDate ?? (a as? comprehensiveExam)?.examDate ?? .distantFuture
            let dateB: Date = (b as? Exam)?.examDate ?? (b as? comprehensiveExam)?.examDate ?? .distantFuture
            return dateA < dateB
        }
    }
    
    // 优化：简化分组逻辑，帮助编译器推断
    private var groupedExams: [(sectionTitle: String, exams: [Any])] {
        let now = Date()
        guard let oneWeekLater = Calendar.current.date(byAdding: .day, value: 7, to: now),
              let oneMonthLater = Calendar.current.date(byAdding: .month, value: 1, to: now) else {
            return []
        }
        
        // 分组
        let week = allExams.filter { item in
            let date = (item as? Exam)?.examDate ?? (item as? comprehensiveExam)?.examDate ?? .distantFuture
            return date <= oneWeekLater
        }
        let month = allExams.filter { item in
            let date = (item as? Exam)?.examDate ?? (item as? comprehensiveExam)?.examDate ?? .distantFuture
            return date > oneWeekLater && date <= oneMonthLater
        }
        let later = allExams.filter { item in
            let date = (item as? Exam)?.examDate ?? (item as? comprehensiveExam)?.examDate ?? .distantFuture
            return date > oneMonthLater
        }
        
        var result: [(String, [Any])] = []
        if !week.isEmpty { result.append(("Within 1 Week", week)) }
        if !month.isEmpty { result.append(("Within 1 Month", month)) }
        if !later.isEmpty { result.append(("Later", later)) }
        
        return result
    }

    var body: some View {
        NavigationView {
            Group {
                if dataManager.examSets.isEmpty && dataManager.comprehensiveExamSets.isEmpty {
                    ContentUnavailableView(
                        "No Exams",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("Tap '+' to add a new exam.")
                    )
                } else {
                    List {
                        ForEach(groupedExams, id: \.0) { sectionTitle, exams in
                            Section(header: Text(sectionTitle)) {
                                ForEach(exams.indices, id: \.self) { index in
                                    let item = exams[index]
                                    
                                    if let exam = item as? Exam {
                                        ExamRowView(exam: exam)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                selectedExamForDetail = exam
                                            }
                                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                                Button(role: .destructive) {
                                                    deleteExam(exam)
                                                } label: {
                                                    Label("Delete", systemImage: "trash")
                                                }
                                            }
                                    } else if let comprehensive = item as? comprehensiveExam {
                                        // 综合考试行（多科目逗号分隔）
                                        ComprehensiveExamRowView(exam: comprehensive)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                selectedComprehensiveExam = comprehensive
                                            }
                                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                                Button(role: .destructive) {
                                                    deleteComprehensiveExam(comprehensive)
                                                } label: {
                                                    Label("Delete", systemImage: "trash")
                                                }
                                            }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Exams")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewExamSet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewExamSet) {
                NewExamSetView()
            }
            // 普通考试详情
            .navigationDestination(item: $selectedExamForDetail) { exam in
                ExamDetailView(exam: exam)
            }
            // 综合考试详情（你可以自己做页面，我先占位）
            .navigationDestination(item: $selectedComprehensiveExam) { exam in
                Text("Comprehensive Exam: \(exam.name)")
            }
        }
    }
    
    // 删除普通考试
    private func deleteExam(_ exam: Exam) {
        if let index = dataManager.examSets.firstIndex(where: { $0.id == exam.id }) {
            dataManager.examSets.remove(at: index)
            dataManager.saveExamSets()
        }
    }
    
    // 删除综合考试
    private func deleteComprehensiveExam(_ exam: comprehensiveExam) {
        if let index = dataManager.comprehensiveExamSets.firstIndex(where: { $0.id == exam.id }) {
            dataManager.comprehensiveExamSets.remove(at: index)
            dataManager.saveComprehensiveExams()
        }
    }
}

// --- 子视图：普通考试行 ---
struct ExamRowView: View {
    let exam: Exam
    @State private var daysRemaining: Int = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(exam.name)
                    .font(.headline)
                Spacer()
                Text(exam.subject)
                    .font(.caption)
                    .padding(4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
            }
            
            Text("\(exam.examDate, style: .date)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 15) {
                VStack(alignment: .leading) {
                    Text("Time Left")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    ProgressView(value: calculateTimeProgress(), total: 1.0)
                        .tint(daysRemaining <= 3 ? .red : (daysRemaining <= 7 ? .orange : .green))
                    Text(daysRemaining > 0 ? "\(daysRemaining) days" : "Today!")
                        .font(.caption2)
                        .foregroundColor(daysRemaining > 2 ? .secondary : .red)
                }
                
                VStack(alignment: .leading) {
                    Text("Mastery")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    ProgressView(value: Double(exam.masteryDegree), total: 100.0)
                        .tint(exam.masteryDegree <= 20 ? .red : (exam.masteryDegree <= 60 ? .orange : .green))

                    Text("\(exam.masteryDegree)%")
                        .font(.caption2)
                        .foregroundColor(exam.masteryDegree <= 5 ? .red : .secondary)
                }
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 4)
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
}

// --- 子视图：综合考试行（多科目逗号分隔）---
struct ComprehensiveExamRowView: View {
    let exam: comprehensiveExam
    @State private var daysRemaining: Int = 0
    
    // 多科目拼接成逗号分隔
    private var subjectText: String {
        exam.subject.joined(separator: ", ")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(exam.name)
                    .font(.headline)
                Spacer()
                Text(subjectText)
                    .font(.caption)
                    .padding(4)
                    .background(Color.purple.opacity(0.1))
                    .foregroundColor(.purple)
                    .cornerRadius(4)
            }
            
            Text("\(exam.examDate, style: .date)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 15) {
                VStack(alignment: .leading) {
                    Text("Time Left")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    ProgressView(value: calculateTimeProgress(), total: 1.0)
                        .tint(daysRemaining <= 3 ? .red : (daysRemaining <= 7 ? .orange : .green))
                    Text(daysRemaining > 0 ? "\(daysRemaining) days" : "Today!")
                        .font(.caption2)
                        .foregroundColor(daysRemaining > 2 ? .secondary : .red)
                }
                
                VStack(alignment: .leading) {
                    Text("Mastery")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    ProgressView(value: Double(exam.masteryDegree), total: 100.0)
                        .tint(exam.masteryDegree <= 20 ? .red : (exam.masteryDegree <= 60 ? .orange : .green))

                    Text("\(exam.masteryDegree)%")
                        .font(.caption2)
                        .foregroundColor(exam.masteryDegree <= 5 ? .red : .secondary)
                }
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 4)
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
}

#Preview {
    ExamView()
        .environmentObject(DataManager())
}
