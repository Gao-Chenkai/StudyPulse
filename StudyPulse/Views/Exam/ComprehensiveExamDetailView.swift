//
//  ComprehensiveExamDetailView.swift
//  StudyPulse
//
//  综合考试详情页(替换简陋的"Comprehensive Exam: 名称"占位)。
//  Sections: 概览 / 科目时间表 / 重要程度与掌握度 / 添加到日历 / 分享 / 预测 / 关联错题
//

import SwiftUI

struct ComprehensiveExamDetailView: View {
    let exam: comprehensiveExam

    @EnvironmentObject var dataManager: DataManager
    @State private var showingCalendarAlert = false
    @State private var calendarAlertMessage = ""
    /// 综合考试预测目标(非空时弹出 ComprehensiveScorePredictionSheet)
    @State private var comprehensivePredictionTarget: ComprehensivePredictionTarget? = nil

    // MARK: - 派生数据

    /// 始终从 dataManager 拿最新的 comprehensiveExam(确保状态实时同步)
    private var currentExam: comprehensiveExam {
        dataManager.comprehensiveExamSets.first(where: { $0.id == exam.id }) ?? exam
    }

    /// 各科目的错题(去重,按时间倒序)
    private var relatedMistakes: [MistakeNote] {
        let subjectSet = Set(currentExam.subject)
        return dataManager.mistakeSets
            .filter { subjectSet.contains($0.subject) }
            .sorted { $0.date > $1.date }
    }

    /// 综合掌握度颜色
    private var masteryColor: Color {
        switch currentExam.masteryDegree {
        case 0..<30: return .red
        case 30..<60: return .orange
        case 60..<80: return .blue
        default: return .green
        }
    }

    // MARK: - 主体

    var body: some View {
        Form {
            // MARK: - 概览
            Section {
                LabeledContent("Exam Name".localized(), value: currentExam.name)
                    .foregroundColor(Color(.label))
                LabeledContent {
                    Text(currentExam.examDate, format: .dateTime.year().month().day())
                } label: {
                    Text("Date".localized())
                }
                .foregroundColor(Color(.label))
                if let endDate = currentExam.examEndDate,
                   !Calendar.current.isDate(currentExam.examDate, inSameDayAs: endDate) {
                    LabeledContent {
                        Text(endDate, format: .dateTime.year().month().day())
                    } label: {
                        Text("End Date".localized())
                    }
                    .foregroundColor(Color(.label))
                }
                if !currentExam.examName.isEmpty {
                    LabeledContent("Note/Title".localized(), value: currentExam.examName)
                        .foregroundColor(Color(.label))
                }
            } header: {
                Text("Overview".localized())
                    .foregroundColor(Color(.secondaryLabel))
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            // MARK: - 科目时间表
            Section {
                ForEach(currentExam.subject, id: \.self) { subject in
                    HStack {
                        Image(systemName: "book.fill")
                            .foregroundColor(Color(.systemPurple))
                            .font(.caption)
                        Text(subject)
                            .foregroundColor(Color(.label))
                        Spacer()
                        if let slot = currentExam.subjectTimeSlots?[subject] {
                            Text(slot.formattedRange)
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                        } else {
                            Text("All Day".localized())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                Text("Subjects".localized())
                    .foregroundColor(Color(.secondaryLabel))
            } footer: {
                Text("All-day subjects use one calendar event; subjects with time slots use individual events.".localized())
                    .foregroundColor(.secondary)
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            // MARK: - 重要程度 & 掌握度
            Section {
                HStack {
                    Text("Importance".localized())
                        .foregroundColor(Color(.label))
                    Spacer()
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { i in
                            Image(systemName: i <= currentExam.importance ? "star.fill" : "star")
                                .foregroundColor(i <= currentExam.importance ? .yellow : Color(.tertiaryLabel))
                        }
                    }
                }
                HStack {
                    Text("Mastery Degree".localized())
                        .foregroundColor(Color(.label))
                    Spacer()
                    Text("\(currentExam.masteryDegree)%")
                        .fontWeight(.semibold)
                        .foregroundColor(masteryColor)
                }
                ProgressView(value: Double(currentExam.masteryDegree), total: 100.0)
                    .tint(masteryColor)
            } header: {
                Text("Metrics".localized())
                    .foregroundColor(Color(.secondaryLabel))
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            // MARK: - 添加到日历
            Section {
                Button(action: { addToCalendar() }) {
                    HStack {
                        Image(systemName: "calendar.badge.plus")
                            .foregroundColor(.accentColor)
                            .font(.title3)
                        Text("Add to Calendar".localized())
                            .foregroundColor(.accentColor)
                    }
                }
            } footer: {
                Text("Will add an all-day event to your system calendar with a 1-day advance reminder.".localized())
                    .foregroundColor(.secondary)
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            // MARK: - 预测
            Section {
                Button {
                    openPrediction()
                } label: {
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundColor(.accentColor)
                            .font(.title3)
                        Text("Predict Total Score".localized())
                            .foregroundColor(.accentColor)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Score Prediction".localized())
                    .foregroundColor(Color(.secondaryLabel))
            } footer: {
                Text("Predicts each subject separately (95% confidence interval), then sums the totals.".localized())
                    .foregroundColor(.secondary)
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            // MARK: - 分享
            Section {
                ShareLink(
                    item: shareText,
                    subject: Text(currentExam.name),
                    message: Text("Exam Details".localized())
                ) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.accentColor)
                            .font(.title3)
                        Text("Share with Family".localized())
                            .foregroundColor(.accentColor)
                    }
                }
            } footer: {
                Text("Generate a summary of the exam (date, subjects) and share it via WeChat, Mail, Messages, etc.".localized())
                    .foregroundColor(.secondary)
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            // MARK: - 关联错题
            Section {
                if relatedMistakes.isEmpty {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.secondary)
                        Text("No related mistakes across these subjects".localized())
                            .foregroundColor(.secondary)
                    }
                    .listRowBackground(Color(.secondarySystemGroupedBackground))
                } else {
                    ForEach(relatedMistakes.prefix(6)) { mistake in
                        NavigationLink(destination: MistakeSetDetailView(mistakeSet: mistake).environmentObject(dataManager)) {
                            HStack(spacing: 10) {
                                Image(systemName: "exclamationmark.bubble.fill")
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mistake.title)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    HStack(spacing: 6) {
                                        Text(mistake.subject)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text(mistake.date, format: .dateTime.month().day())
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                            }
                        }
                        .listRowBackground(Color(.secondarySystemGroupedBackground))
                    }
                    if relatedMistakes.count > 6 {
                        HStack {
                            Spacer()
                            Text(String(format: "+ %d more mistakes".localized(), relatedMistakes.count - 6))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .listRowBackground(Color(.secondarySystemGroupedBackground))
                    }
                }
            } header: {
                Text("Related Mistakes".localized())
                    .foregroundColor(Color(.secondaryLabel))
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(currentExam.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    openPrediction()
                } label: {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                }
                .accessibilityLabel("Predict".localized())
            }
        }
        .sheet(item: $comprehensivePredictionTarget) { target in
            ComprehensiveScorePredictionSheet(
                target: target,
                onDismiss: { comprehensivePredictionTarget = nil }
            )
            .adaptiveSheet(detents: [.medium, .large])
        }
        .alert("Calendar".localized(), isPresented: $showingCalendarAlert) {
            Button("OK".localized()) { }
        } message: {
            Text(calendarAlertMessage)
        }
    }

    // MARK: - 行为

    private func addToCalendar() {
        Task {
            do {
                _ = try await CalendarManager.shared.addExamToCalendar(
                    examName: currentExam.name + " - " + "Comprehensive".localized(),
                    subject: currentExam.subject.joined(separator: ", "),
                    examDate: currentExam.examDate,
                    startTime: nil,
                    endTime: nil,
                    note: currentExam.examName.isEmpty ? nil : currentExam.examName
                )
                await MainActor.run {
                    calendarAlertMessage = "Successfully added to calendar!".localized()
                    showingCalendarAlert = true
                }
            } catch {
                await MainActor.run {
                    calendarAlertMessage = error.localizedDescription
                    showingCalendarAlert = true
                }
            }
        }
    }

    private func openPrediction() {
        let predictor = ScorePredictorFactory.active
        let allSubjects = currentExam.subject
        var perSubject: [PerSubjectPrediction] = []
        var totalFull: Double = 0
        var totalPredicted: Double = 0
        var totalLower: Double = 0
        var totalUpper: Double = 0

        for subject in allSubjects {
            let grades = dataManager.filteredGrades.filter { $0.subject == subject }
            let fullScore = dataManager.subjects.first(where: { $0.name == subject })?.fullScore ?? 100
            if let r = predictor.predict(history: grades, examDate: currentExam.examDate, fullScore: fullScore) {
                perSubject.append(PerSubjectPrediction(subject: subject, result: r))
                totalFull += fullScore
                totalPredicted += r.predicted
                totalLower += r.lowerBound
                totalUpper += r.upperBound
            }
        }
        guard !perSubject.isEmpty else {
            calendarAlertMessage = "Not Enough Data".localized() + ": " + "Add at least 2 grades for this subject to enable prediction.".localized()
            showingCalendarAlert = true
            return
        }
        comprehensivePredictionTarget = ComprehensivePredictionTarget(
            exam: currentExam,
            perSubject: perSubject,
            totalFull: totalFull,
            totalPredicted: totalPredicted,
            totalLower: totalLower,
            totalUpper: totalUpper
        )
    }

    // MARK: - 分享文本

    private var shareText: String {
        var lines: [String] = []
        lines.append("📚 " + currentExam.name + " (" + "Comprehensive".localized() + ")")
        lines.append("📅 " + currentExam.examDate.formatted(date: .complete, time: .omitted))
        if let endDate = currentExam.examEndDate,
           !Calendar.current.isDate(currentExam.examDate, inSameDayAs: endDate) {
            lines.append("→ " + endDate.formatted(date: .complete, time: .omitted))
        }
        lines.append("📝 " + "Subjects".localized() + ": " + currentExam.subject.joined(separator: ", "))
        if !currentExam.examName.isEmpty {
            lines.append("🏷  " + currentExam.examName)
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - ExamTimeSlot 的格式化便捷方法

extension ExamTimeSlot {
    /// 形如 "09:00 - 11:00" 的本地化范围字符串
    var formattedRange: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return "\(fmt.string(from: startTime)) - \(fmt.string(from: endTime))"
    }
}
