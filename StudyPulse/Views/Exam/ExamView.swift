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
    @State private var showingPastExams = false

    /// 合并所有类型的考试，按时间排序
    private var allExamsSorted: [Any] {
        var exams: [Any] = []
        exams.append(contentsOf: dataManager.examSets)
        exams.append(contentsOf: dataManager.comprehensiveExamSets)
        
        return exams.sorted { a, b in
            let dateA: Date = (a as? Exam)?.examDate ?? (a as? comprehensiveExam)?.examDate ?? .distantFuture
            let dateB: Date = (b as? Exam)?.examDate ?? (b as? comprehensiveExam)?.examDate ?? .distantFuture
            return dateA < dateB
        }
    }
    
    /// 未过期的考试（日期 >= 今天）
    private var upcomingExams: [Any] {
        let todayStart = Calendar.current.startOfDay(for: Date())
        return allExamsSorted.filter { item in
            let date = (item as? Exam)?.examDate ?? (item as? comprehensiveExam)?.examDate ?? .distantFuture
            return date >= todayStart
        }
    }
    
    /// 已过期的考试（日期 < 今天）
    private var pastExams: [Any] {
        let todayStart = Calendar.current.startOfDay(for: Date())
        return allExamsSorted.filter { item in
            let date = (item as? Exam)?.examDate ?? (item as? comprehensiveExam)?.examDate ?? .distantFuture
            return date < todayStart
        }
    }
    
    /// 将未来考试按时间范围分组
    private var groupedExams: [(sectionTitle: String, exams: [Any])] {
        let now = Date()
        guard let oneWeekLater = Calendar.current.date(byAdding: .day, value: 7, to: now),
              let oneMonthLater = Calendar.current.date(byAdding: .month, value: 1, to: now) else {
            return []
        }
        
        let week = upcomingExams.filter { item in
            let date = (item as? Exam)?.examDate ?? (item as? comprehensiveExam)?.examDate ?? .distantFuture
            return date <= oneWeekLater
        }
        let month = upcomingExams.filter { item in
            let date = (item as? Exam)?.examDate ?? (item as? comprehensiveExam)?.examDate ?? .distantFuture
            return date > oneWeekLater && date <= oneMonthLater
        }
        let later = upcomingExams.filter { item in
            let date = (item as? Exam)?.examDate ?? (item as? comprehensiveExam)?.examDate ?? .distantFuture
            return date > oneMonthLater
        }
        
        var result: [(String, [Any])] = []
        if !week.isEmpty { result.append(("Within 1 Week".localized(), week)) }
        if !month.isEmpty { result.append(("Within 1 Month".localized(), month)) }
        if !later.isEmpty { result.append(("Later".localized(), later)) }

        return result
    }

    var body: some View {
        NavigationStack {
            Group {
                if upcomingExams.isEmpty && pastExams.isEmpty {
                    ContentUnavailableView(
                        "No Exams".localized(),
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("Tap '+' to add a new exam.".localized())
                    )
                    .background(Color(.systemGroupedBackground))
                } else {
                    List {
                        if upcomingExams.isEmpty {
                            Section {
                                HStack {
                                    Spacer()
                                    VStack(spacing: 6) {
                                        Image(systemName: "calendar.badge.plus")
                                            .font(.title2)
                                            .foregroundColor(Color(.secondaryLabel))
                                        Text("No upcoming exams".localized())
                                            .font(.subheadline)
                                            .foregroundColor(Color(.secondaryLabel))
                                    }
                                    .padding(.vertical, 20)
                                    Spacer()
                                }
                                .listRowBackground(Color(.secondarySystemGroupedBackground))
                            }
                        } else {
                            ForEach(groupedExams, id: \.0) { sectionTitle, exams in
                                Section(header: Text(sectionTitle)
                                    .foregroundColor(Color(.secondaryLabel))
                                    .font(.subheadline)
                                    .textCase(.none)
                                ) {
                                    ForEach(exams.indices, id: \.self) { index in
                                        let item = exams[index]
                                        
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
                    }
                    .background(Color(.systemGroupedBackground))
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Exams".localized())
            .background(Color(.systemGroupedBackground))
            // iPad 上撑满 detail 区宽度
            .frame(maxWidth: .infinity)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !pastExams.isEmpty {
                        Button {
                            showingPastExams = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.arrow.circlepath")
                                Text("\(pastExams.count)")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewExamSet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewExamSet) {
                NewExamSetView()
                    .adaptiveSheet()
            }
            .sheet(isPresented: $showingPastExams) {
                PastExamsSheet(
                    pastExams: pastExams,
                    onSelectExam: { exam in
                        showingPastExams = false
                        // 延迟导航，等 sheet 关闭
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            selectedExamForDetail = exam
                        }
                    },
                    onSelectComprehensive: { exam in
                        showingPastExams = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            selectedComprehensiveExam = exam
                        }
                    },
                    onDeleteExam: { exam in deleteExam(exam) },
                    onDeleteComprehensive: { exam in deleteComprehensiveExam(exam) }
                )
                    .adaptiveSheet(detents: [.medium, .large])
            }
            .navigationDestination(item: $selectedExamForDetail) { exam in
                ExamDetailView(exam: exam)
                    .background(Color(.systemBackground))
            }
            .navigationDestination(item: $selectedComprehensiveExam) { exam in
                Text("Comprehensive Exam: ".localized() + exam.name)
                    .background(Color(.systemBackground))
            }
        }
    }
    
    private func deleteExam(_ exam: Exam) {
        if let index = dataManager.examSets.firstIndex(where: { $0.id == exam.id }) {
            dataManager.examSets.remove(at: index)
            dataManager.saveExamSets()
        }
    }
    
    private func deleteComprehensiveExam(_ exam: comprehensiveExam) {
        if let index = dataManager.comprehensiveExamSets.firstIndex(where: { $0.id == exam.id }) {
            dataManager.comprehensiveExamSets.remove(at: index)
            dataManager.saveComprehensiveExams()
        }
    }
}

// MARK: - 过去考试 Sheet

/// 过去考试列表 Sheet
struct PastExamsSheet: View {
    let pastExams: [Any]
    let onSelectExam: (Exam) -> Void
    let onSelectComprehensive: (comprehensiveExam) -> Void
    let onDeleteExam: (Exam) -> Void
    let onDeleteComprehensive: (comprehensiveExam) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(pastExams.indices, id: \.self) { index in
                    let item = pastExams[index]
                    
                    if let exam = item as? Exam {
                        Button {
                            dismiss()
                            onSelectExam(exam)
                        } label: {
                            pastExamLabel(
                                name: exam.name,
                                subject: exam.subject,
                                date: exam.examDate,
                                mastery: exam.masteryDegree
                            )
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                onDeleteExam(exam)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(Color(.systemRed))
                        }
                    } else if let comp = item as? comprehensiveExam {
                        Button {
                            dismiss()
                            onSelectComprehensive(comp)
                        } label: {
                            pastExamLabel(
                                name: comp.name,
                                subject: comp.subject.joined(separator: ", "),
                                date: comp.examDate,
                                mastery: comp.masteryDegree
                            )
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                onDeleteComprehensive(comp)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(Color(.systemRed))
                        }
                    }
                }
            }
            .navigationTitle("Past Exams".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done".localized()) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    /// 过去考试行通用标签
    private func pastExamLabel(name: String, subject: String, date: Date, mastery: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline)
                    .foregroundColor(Color(.label))
                Text(subject)
                    .font(.caption)
                    .foregroundColor(Color(.secondaryLabel))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(date, style: .date)
                    .font(.caption)
                    .foregroundColor(Color(.secondaryLabel))
                Text("\(mastery)%")
                    .font(.caption2)
                    .foregroundColor(mastery >= 60 ? Color(.systemGreen) : Color(.systemOrange))
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

// MARK: - 子视图：普通考试行

struct ExamRowView: View {
    let exam: Exam
    @State private var animateIn = false
    
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
            
            Group {
                if let endDate = exam.examEndDate, !Calendar.current.isDate(exam.examDate, inSameDayAs: endDate) {
                    Text("\(exam.examDate.formatted(date: .abbreviated, time: .omitted)) - \(endDate.formatted(date: .abbreviated, time: .omitted))")
                } else {
                    Text("\(exam.examDate, style: .date)")
                }
            }
            .font(.caption)
                .foregroundColor(Color(.secondaryLabel))
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Time Left".localized())
                        .font(.caption2)
                        .foregroundColor(Color(.secondaryLabel))
                    ProgressView(value: timeProgress, total: 1.0)
                        .tint(timeLeftColor)
                        .scaleEffect(x: 1, y: 1.2, anchor: .center)
                    Text(daysRemaining > 0 ? "\(daysRemaining) " + "days".localized() : "Today!".localized())
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(daysRemaining > 2 ? Color(.secondaryLabel) : Color(.systemRed))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mastery".localized())
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
        .hoverHighlight()
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 15)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                animateIn = true
            }
        }
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

// MARK: - 子视图：综合考试行

struct ComprehensiveExamRowView: View {
    let exam: comprehensiveExam
    @State private var animateIn = false
    
    private var daysRemaining: Int {
        let components = Calendar.current.dateComponents([.day], from: Date(), to: exam.examDate)
        return max(0, components.day ?? 0)
    }
    
    private var timeProgress: Double {
        min(Double(daysRemaining) / 30.0, 1.0)
    }
    
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
            
            Group {
                if let endDate = exam.examEndDate, !Calendar.current.isDate(exam.examDate, inSameDayAs: endDate) {
                    Text("\(exam.examDate.formatted(date: .abbreviated, time: .omitted)) - \(endDate.formatted(date: .abbreviated, time: .omitted))")
                } else {
                    Text("\(exam.examDate, style: .date)")
                }
            }
            .font(.caption)
                .foregroundColor(Color(.secondaryLabel))
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Time Left".localized())
                        .font(.caption2)
                        .foregroundColor(Color(.secondaryLabel))
                    ProgressView(value: timeProgress, total: 1.0)
                        .tint(timeLeftColor)
                        .scaleEffect(x: 1, y: 1.2, anchor: .center)
                    Text(daysRemaining > 0 ? "\(daysRemaining) " + "days".localized() : "Today!".localized())
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(daysRemaining > 2 ? Color(.secondaryLabel) : Color(.systemRed))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mastery".localized())
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
        .hoverHighlight()
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 15)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                animateIn = true
            }
        }
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
