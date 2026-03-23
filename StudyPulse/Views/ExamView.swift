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
    
    // ✅ 优化：简化分组逻辑，帮助编译器推断
    private var groupedExams: [(sectionTitle: String, exams: [Exam])] {
        let now = Date()
        guard let oneWeekLater = Calendar.current.date(byAdding: .day, value: 7, to: now),
              let oneMonthLater = Calendar.current.date(byAdding: .month, value: 1, to: now) else {
            return []
        }
        
        // 排序
        let sorted = dataManager.examSets.sorted { $0.examDate < $1.examDate }
        
        // 分组
        let week = sorted.filter { $0.examDate <= oneWeekLater }
        let month = sorted.filter { $0.examDate > oneWeekLater && $0.examDate <= oneMonthLater }
        let later = sorted.filter { $0.examDate > oneMonthLater }
        
        var result: [(String, [Exam])] = []
        if !week.isEmpty { result.append(("Within 1 Week", week)) }
        if !month.isEmpty { result.append(("Within 1 Month", month)) }
        if !later.isEmpty { result.append(("Later", later)) }
        
        return result
    }

    var body: some View {
        NavigationView {
            Group {
                if dataManager.examSets.isEmpty {
                    ContentUnavailableView(
                        "No Exams",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("Tap '+' to add a new exam.")
                    )
                } else {
                    List {
                        ForEach(groupedExams, id: \.0) { sectionTitle, exams in
                            Section(header: Text(sectionTitle)) {
                                ForEach(exams) { exam in
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
            // ✅ 确保这里调用的是接收 Exam 参数的 ExamDetailView
            .navigationDestination(item: $selectedExamForDetail) { exam in
                ExamDetailView(exam: exam)
            }
        }
    }
    
    private func deleteExam(_ exam: Exam) {
        if let index = dataManager.examSets.firstIndex(where: { $0.id == exam.id }) {
            dataManager.examSets.remove(at: index)
            dataManager.saveExamSets()
        }
    }
}

// --- 子视图：列表行 ---
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

#Preview {
    ExamView()
        .environmentObject(DataManager())
}
