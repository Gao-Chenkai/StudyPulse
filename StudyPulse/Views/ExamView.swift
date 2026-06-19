//
//  ExamView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/23.
//

import SwiftUI

/// 考试列表主视图
struct ExamView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingNewExamSet = false
    @State private var selectedExamForDetail: Exam? = nil
    @State private var selectedComprehensiveExam: comprehensiveExam? = nil

    /// 合并所有类型的考试，并按时间排序
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
    
    /// 将考试按时间范围分组
    private var groupedExams: [(sectionTitle: String, exams: [Any])] {
        let now = Date()
        guard let oneWeekLater = Calendar.current.date(byAdding: .day, value: 7, to: now),
              let oneMonthLater = Calendar.current.date(byAdding: .month, value: 1, to: now) else {
            return []
        }
        
        // 分别筛选不同时间段的考试
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
                // 当没有任何考试时显示占位视图
                if dataManager.examSets.isEmpty && dataManager.comprehensiveExamSets.isEmpty {
                    ContentUnavailableView(
                        "No Exams",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("Tap '+' to add a new exam.")
                    )
                    .background(Color(.systemGroupedBackground))
                } else {
                    // 渲染考试列表
                    List {
                        ForEach(groupedExams, id: \.0) { sectionTitle, exams in
                            Section(header: Text(sectionTitle)
                                .foregroundColor(Color(.secondaryLabel))
                                .font(.subheadline)
                                .textCase(.none)
                            ) {
                                ForEach(exams.indices, id: \.self) { index in
                                    let item = exams[index]
                                    
                                    // 渲染普通考试行
                                    if let exam = item as? Exam {
                                        ExamRowView(exam: exam)
                                            .listRowBackground(Color(.secondarySystemGroupedBackground))
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
                                                .tint(Color(.systemRed))
                                            }
                                    }
                                    // 渲染综合考试行
                                    else if let comprehensive = item as? comprehensiveExam {
                                        ComprehensiveExamRowView(exam: comprehensive)
                                            .listRowBackground(Color(.secondarySystemGroupedBackground))
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
                                                .tint(Color(.systemRed))
                                            }
                                    }
                                }
                            }
                        }
                    }
                    .background(Color(.systemGroupedBackground))
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Exams")
            .background(Color(.systemGroupedBackground))
            // iPad 上限制最大宽度并居中
            .adaptiveMaxWidth(800)
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
            // 普通考试详情导航
            .navigationDestination(item: $selectedExamForDetail) { exam in
                ExamDetailView(exam: exam)
                    .background(Color(.systemBackground))
            }
            // 综合考试详情导航
            .navigationDestination(item: $selectedComprehensiveExam) { exam in
                Text("Comprehensive Exam: \(exam.name)")
                    .background(Color(.systemBackground))
            }
        }
        .background(Color(.systemGroupedBackground))
    }
    
    /// 删除普通考试
    private func deleteExam(_ exam: Exam) {
        if let index = dataManager.examSets.firstIndex(where: { $0.id == exam.id }) {
            dataManager.examSets.remove(at: index)
            dataManager.saveExamSets()
        }
    }
    
    /// 删除综合考试
    private func deleteComprehensiveExam(_ exam: comprehensiveExam) {
        if let index = dataManager.comprehensiveExamSets.firstIndex(where: { $0.id == exam.id }) {
            dataManager.comprehensiveExamSets.remove(at: index)
            dataManager.saveComprehensiveExams()
        }
    }
}

// MARK: - 子视图：普通考试行

/// 普通考试列表项视图
struct ExamRowView: View {
    let exam: Exam
    @State private var animateIn = false
    
    /// 计算属性替代 @State + onAppear，避免副作用和不必要重绘
    private var daysRemaining: Int {
        let components = Calendar.current.dateComponents([.day], from: Date(), to: exam.examDate)
        return max(0, components.day ?? 0)
    }
    
    private var timeProgress: Double {
        min(Double(daysRemaining) / 30.0, 1.0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(exam.name)
                    .font(.headline)
                    .foregroundColor(Color(.label))
                Spacer()
                Text(exam.subject.localized())
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(.systemBlue).opacity(0.15))
                    )
                    .foregroundColor(Color(.systemBlue))
            }
            
            Text("\(exam.examDate, style: .date)")
                .font(.caption)
                .foregroundColor(Color(.secondaryLabel))
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Time Left")
                        .font(.caption2)
                        .foregroundColor(Color(.secondaryLabel))
                    ProgressView(value: timeProgress, total: 1.0)
                        .tint(timeLeftColor)
                        .scaleEffect(x: 1, y: 1.2, anchor: .center)
                    Text(daysRemaining > 0 ? "\(daysRemaining) days" : "Today!")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(daysRemaining > 2 ? Color(.secondaryLabel) : Color(.systemRed))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mastery")
                        .font(.caption2)
                        .foregroundColor(Color(.secondaryLabel))
                    ProgressView(value: Double(exam.masteryDegree), total: 100.0)
                        .tint(masteryColor)
                        .scaleEffect(x: 1, y: 1.2, anchor: .center)

                    Text("\(exam.masteryDegree)%")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(exam.masteryDegree <= 5 ? Color(.systemRed) : Color(.secondaryLabel))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemGroupedBackground))
                
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(.systemBlue).opacity(0.25),
                                Color(.systemBlue).opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .shadow(
            color: Color.black.opacity(0.05),
            radius: 6,
            x: 0,
            y: 3
        )
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 15)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                animateIn = true
            }
        }
    }
    
    /// 根据剩余天数确定进度条颜色
    private var timeLeftColor: Color {
        if daysRemaining <= 3 {
            return Color(.systemRed)
        } else if daysRemaining <= 7 {
            return Color(.systemOrange)
        } else {
            return Color(.systemGreen)
        }
    }
    
    /// 根据掌握程度确定进度条颜色
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

// MARK: - 子视图：综合考试行

/// 综合考试列表项视图
struct ComprehensiveExamRowView: View {
    let exam: comprehensiveExam
    @State private var animateIn = false
    
    /// 计算属性替代 @State + onAppear，避免副作用和不必要重绘
    private var daysRemaining: Int {
        let components = Calendar.current.dateComponents([.day], from: Date(), to: exam.examDate)
        return max(0, components.day ?? 0)
    }
    
    private var timeProgress: Double {
        min(Double(daysRemaining) / 30.0, 1.0)
    }
    
    /// 将多个考试科目拼接成逗号分隔的字符串
    private var subjectText: String {
        exam.subject.joined(separator: ", ")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(exam.name.localized())
                    .font(.headline)
                    .foregroundColor(Color(.label))
                Spacer()
                Text(subjectText.localized())
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(.systemPurple).opacity(0.15))
                    )
                    .foregroundColor(Color(.systemPurple))
            }
            
            Text("\(exam.examDate, style: .date)")
                .font(.caption)
                .foregroundColor(Color(.secondaryLabel))
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Time Left")
                        .font(.caption2)
                        .foregroundColor(Color(.secondaryLabel))
                    ProgressView(value: timeProgress, total: 1.0)
                        .tint(timeLeftColor)
                        .scaleEffect(x: 1, y: 1.2, anchor: .center)
                    Text(daysRemaining > 0 ? "\(daysRemaining) days" : "Today!")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(daysRemaining > 2 ? Color(.secondaryLabel) : Color(.systemRed))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mastery")
                        .font(.caption2)
                        .foregroundColor(Color(.secondaryLabel))
                    ProgressView(value: Double(exam.masteryDegree), total: 100.0)
                        .tint(masteryColor)
                        .scaleEffect(x: 1, y: 1.2, anchor: .center)

                    Text("\(exam.masteryDegree)%")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(exam.masteryDegree <= 5 ? Color(.systemRed) : Color(.secondaryLabel))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemGroupedBackground))
                
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(.systemPurple).opacity(0.25),
                                Color(.systemPurple).opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .shadow(
            color: Color.black.opacity(0.05),
            radius: 6,
            x: 0,
            y: 3
        )
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 15)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                animateIn = true
            }
        }
    }
    
    /// 根据剩余天数确定进度条颜色
    private var timeLeftColor: Color {
        if daysRemaining <= 3 {
            return Color(.systemRed)
        } else if daysRemaining <= 7 {
            return Color(.systemOrange)
        } else {
            return Color(.systemGreen)
        }
    }
    
    /// 根据掌握程度确定进度条颜色
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

#Preview {
    ExamView()
        .environmentObject(DataManager())
        .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    ExamView()
        .environmentObject(DataManager())
        .preferredColorScheme(.dark)
}
