//
//  ExamView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/23.
//

import SwiftUI

/// 考试列表主视图
struct ExamView: View {
    @Environment(RepositoryContainer.self) private var container
    @StateObject private var viewModel: ExamViewModel
    @State private var showingNewExamSet = false
    @State private var selectedExamForDetail: Exam? = nil
    @State private var selectedComprehensiveExam: comprehensiveExam? = nil
    @State private var showingPastExams = false
    @State private var viewMode: ExamViewMode = ExamViewMode.loadFromDefaults()
    /// 预测目标(单科)：非空时弹出 ScorePredictionSheet
    @State private var predictionTarget: PredictionTarget? = nil
    /// 预测目标(综合考试)：非空时弹出 ComprehensiveScorePredictionSheet
    @State private var comprehensivePredictionTarget: ComprehensivePredictionTarget? = nil

    init(container: RepositoryContainer) {
        _viewModel = StateObject(wrappedValue: ExamViewModel.makeDefault(container: container))
    }

    private var showsCalendar: Bool {
        viewMode == .calendar
    }

    // MARK: - 派生数据来源:全部从 ExamViewModel 取。View 内只做"Any" 适配
    // (下游 PastExamsSheet / listContent 接受 [Any])

    /// 合并所有类型的考试，按时间排序(保持原 [Any] 类型,兼容下游)
    private var allExamsSorted: [Any] {
        viewModel.allItems.map { (item: ExamItem) -> Any in
            switch item {
            case .single(let e): return e
            case .comprehensive(let e): return e
            }
        }
    }

    /// 未过期的考试(日期 >= 今天)
    private var upcomingExams: [Any] {
        viewModel.upcomingItems.map { (item: ExamItem) -> Any in
            switch item {
            case .single(let e): return e
            case .comprehensive(let e): return e
            }
        }
    }

    /// 已过期的考试(日期 < 今天)
    private var pastExams: [Any] {
        viewModel.pastItems.map { (item: ExamItem) -> Any in
            switch item {
            case .single(let e): return e
            case .comprehensive(let e): return e
            }
        }
    }

    /// 未来考试分桶(转回 [Any] 兼容旧 listContent)
    private var groupedExams: [(sectionTitle: String, exams: [Any])] {
        viewModel.groupedUpcoming.map { bucket in
            (bucket.title, bucket.items.map { (item: ExamItem) -> Any in
                switch item {
                case .single(let e): return e
                case .comprehensive(let e): return e
                }
            })
        }
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
                } else if showsCalendar {
                    calendarContent
                } else {
                    listContent
                }
            }
            .containerBackground(.clear, for: .navigation)
            .debugModeContainer()
            .debugLayoutBoundsAuto()
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
                    viewModeMenu
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewExamSet = true }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .principal) {
                    PhaseSelectorView()
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
                ComprehensiveExamDetailView(exam: exam)
                    .background(Color(.systemBackground))
            }
            .sheet(item: $predictionTarget) { target in
                ScorePredictionSheet(
                    exam: target.exam,
                    history: target.history,
                    fullScore: target.fullScore,
                    onDismiss: { predictionTarget = nil }
                )
                .adaptiveSheet(detents: [.medium, .large])
            }
            .sheet(item: $comprehensivePredictionTarget) { target in
                ComprehensiveScorePredictionSheet(
                    target: target,
                    onDismiss: { comprehensivePredictionTarget = nil }
                )
                .adaptiveSheet(detents: [.medium, .large])
            }
            // 派生数据重算
            .onAppear { viewModel.recompute() }
            .onChange(of: container.examRepo.filteredExamSets) { _, _ in viewModel.recompute() }
            .onChange(of: container.examRepo.filteredComprehensiveExamSets) { _, _ in viewModel.recompute() }
        }
    }

    // MARK: - 内容

    @ViewBuilder
    private var listContent: some View {
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
                                ExamRowView(
                                    exam: exam,
                                    onPredict: { openPrediction(for: exam) }
                                )
                                    .listRowBackground(Color(.secondarySystemGroupedBackground))
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedExamForDetail = exam
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        Button {
                                            openPrediction(for: exam)
                                        } label: {
                                            Label("Predict".localized(), systemImage: "chart.line.uptrend.xyaxis")
                                        }
                                        .tint(Color(.systemBlue))

                                        Button(role: .destructive) {
                                            deleteExam(exam)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        .tint(Color(.systemRed))
                                    }
                            }
                            else if let comprehensive = item as? comprehensiveExam {
                                ComprehensiveExamRowView(
                                    exam: comprehensive,
                                    onPredict: { openPrediction(for: comprehensive) }
                                )
                                    .listRowBackground(Color(.secondarySystemGroupedBackground))
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedComprehensiveExam = comprehensive
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        Button {
                                            openPrediction(for: comprehensive)
                                        } label: {
                                            Label("Predict".localized(), systemImage: "chart.line.uptrend.xyaxis")
                                        }
                                        .tint(Color(.systemPurple))

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

    @ViewBuilder
    private var calendarContent: some View {
        ExamCalendarView(
            onSelectExam: { exam in selectedExamForDetail = exam },
            onSelectComprehensive: { exam in selectedComprehensiveExam = exam }
        )
    }

    // MARK: - 视图模式切换

    private var viewModeMenu: some View {
        Menu {
            Picker("View Mode".localized(), selection: $viewMode) {
                ForEach(ExamViewMode.allCases) { mode in
                    Label(mode.displayName, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Image(systemName: showsCalendar ? "calendar" : "list.bullet")
        }
        .onChange(of: viewMode) { _, newValue in
            newValue.saveToDefaults()
        }
    }
    
    private func deleteExam(_ exam: Exam) {
        container.deleteExam(exam)
    }

    private func deleteComprehensiveExam(_ exam: comprehensiveExam) {
        container.deleteComprehensiveExam(exam)
    }

    /// 触发预测 Sheet：按考试科目取历史成绩 + 满分。
    /// Open the prediction sheet for a given exam, using same-subject history
    /// and the subject's full score.
    private func openPrediction(for exam: Exam) {
        let subjectGrades = container.gradeRepo.filteredGrades
            .filter { $0.subject == exam.subject }
        let fullScore = container.subjectRepo.subjects.first(where: { $0.name == exam.subject })?.fullScore ?? 100
        predictionTarget = PredictionTarget(
            exam: exam,
            history: subjectGrades,
            fullScore: fullScore
        )
    }

    /// 触发预测 Sheet(综合考试):逐科预测,再汇总总分。
    /// Open the prediction sheet for a comprehensive exam, predicting each
    /// subject separately and aggregating the total.
    private func openPrediction(for exam: comprehensiveExam) {
        let predictor = ScorePredictorFactory.active
        let allSubjects = exam.subject
        var perSubject: [PerSubjectPrediction] = []
        var totalFull: Double = 0
        var totalPredicted: Double = 0
        var totalLower: Double = 0
        var totalUpper: Double = 0

        for subject in allSubjects {
            let grades = container.gradeRepo.filteredGrades.filter { $0.subject == subject }
            let mistakes = container.mistakeRepo.filteredMistakeSets.filter { $0.subject == subject }
            let context = MistakeContext.build(from: mistakes)
            let fullScore = container.subjectRepo.subjects.first(where: { $0.name == subject })?.fullScore ?? 100
            if let r = predictor.predict(history: grades, mistakeContext: context, examDate: exam.examDate, fullScore: fullScore) {
                perSubject.append(PerSubjectPrediction(subject: subject, result: r))
                totalFull += fullScore
                totalPredicted += r.predicted
                totalLower += r.lowerBound
                totalUpper += r.upperBound
            }
        }
        guard !perSubject.isEmpty else { return }
        comprehensivePredictionTarget = ComprehensivePredictionTarget(
            exam: exam,
            perSubject: perSubject,
            totalFull: totalFull,
            totalPredicted: totalPredicted,
            totalLower: totalLower,
            totalUpper: totalUpper
        )
    }
}

// MARK: - 预测目标

/// 触发 ScorePredictionSheet 的目标（Identifiable 用于 sheet(item:) 绑定）
struct PredictionTarget: Identifiable {
    let id = UUID()
    let exam: Exam
    let history: [Grade]
    let fullScore: Double
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
    /// 点击"预测"按钮的回调
    var onPredict: (() -> Void)? = nil
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
            HStack(spacing: 8) {
                Text(exam.name)
                    .font(.headline)
                    .foregroundColor(Color(.label))
                    .debugInspectAuto(exam.name, label: "exam name")
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

            // 预测按钮：放在进度条下方,显眼易找
            if let onPredict = onPredict {
                Button {
                    onPredict()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.caption.weight(.bold))
                        Text("Predict".localized())
                            .font(.caption.weight(.semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(
                        Capsule()
                            .fill(Color(.systemBlue).opacity(0.12))
                    )
                    .foregroundColor(Color(.systemBlue))
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
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
        .debugLayoutBoundsAuto()
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
    /// 点击"预测"按钮的回调
    var onPredict: (() -> Void)? = nil
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
                    .debugInspectAuto(exam.name, label: "comprehensive exam name")
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

            // 预测按钮(综合考试,预测总分)
            if let onPredict = onPredict {
                Button {
                    onPredict()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.caption.weight(.bold))
                        Text("Predict".localized())
                            .font(.caption.weight(.semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(
                        Capsule()
                            .fill(Color(.systemPurple).opacity(0.12))
                    )
                    .foregroundColor(Color(.systemPurple))
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
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
        .debugLayoutBoundsAuto()
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
    ExamView(container: RepositoryContainer())
        .environment(RepositoryContainer())
        .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    ExamView(container: RepositoryContainer())
        .environment(RepositoryContainer())
        .preferredColorScheme(.dark)
}

// MARK: - 视图模式

/// 考试页面视图模式：列表 / 月历
enum ExamViewMode: String, CaseIterable, Identifiable, Codable {
    case list
    case calendar

    var id: String { rawValue }

    /// 显示名称
    @MainActor var displayName: String {
        switch self {
        case .list: return "List".localized()
        case .calendar: return "Calendar".localized()
        }
    }

    /// 工具栏图标
    var icon: String {
        switch self {
        case .list: return "list.bullet"
        case .calendar: return "calendar"
        }
    }

    private static let userDefaultsKey = "examViewMode"

    /// 从 UserDefaults 加载，缺失或非法值时默认 list
    static func loadFromDefaults() -> ExamViewMode {
        guard let raw = UserDefaults.standard.string(forKey: userDefaultsKey),
              let mode = ExamViewMode(rawValue: raw) else {
            return .list
        }
        return mode
    }

    /// 持久化到 UserDefaults
    func saveToDefaults() {
        UserDefaults.standard.set(rawValue, forKey: Self.userDefaultsKey)
    }
}
