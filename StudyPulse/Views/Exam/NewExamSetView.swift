//
//  NewExamSetView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/23.
//

import SwiftUI
import UserNotifications

struct NewExamSetView: View {
    // 从环境中自动获取 DataManager，不需要在 init 中传参
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.dismiss) private var dismiss
    
    // 表单状态
    @State private var name = ""
    @State private var selectedSubject = "Mathematics"
    @State private var isComprehensiveExam = false
    // 默认从明天开始，给用户合理的窗口选择未来具体时刻
    @State private var examDate: Date = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    @State private var examEndDate: Date = Calendar.current.date(byAdding: .day, value: 3, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    @State private var importance = 3
    @State private var masteryDegree = 50
    @State private var examNote = ""
    
    // 日历
    @State private var addToCalendarToggle = true
    @State private var showingCalendarAlert = false
    @State private var calendarAlertMessage = ""
    
    // 单科选择（String）
    @State private var selectedSingleSubject: String = ""
    // 多科目选择（[String]，用来存多选结果）
    @State private var selectedMultipleSubjects: [String] = []

	// 科目具体时间（仅在添加到日历时使用）

    // 科目时间段模型（仿 AddGradeView 的 SubjectScore 设计）
    struct SubjectTimeEntry: Identifiable {
        let id = UUID()
        let subject: String
        var startTime: Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
        var endTime: Date = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date()) ?? Date()
    }
    
    @State private var subjectTimeEntries: [SubjectTimeEntry] = []
    var enabledSubjects: [Subject] {
        dataManager.subjects.filter {
            $0.enabled && !$0.name.starts(with: "GROUP:")
        }
    }
    
    // 【动态高度】每个科目 80pt
    var dynamicListHeight: CGFloat {
        // 科目数量 × 80
        CGFloat(enabledSubjects.count * 80)
    }
    
    // 只拿科目名称
    var availableSubjectNames: [String] {
        enabledSubjects.map { $0.name }
    }
    
    // 获取可用科目
    private var availableSubjects: [String] {
        dataManager.subjects.filter { $0.enabled }.map { $0.name }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Basic Info".localized())) {
                    TextField("Exam Name (e.g., Midterm)".localized(), text: $name)

                    VStack {
                        Picker("Exam Numbers".localized(), selection: $isComprehensiveExam) {
                            Text("Single Subject".localized())
                                .tag(false)
                            Text("Comprehensive Exam".localized())
                                .tag(true)
                        }
                        .pickerStyle(.segmented)

                        if !isComprehensiveExam {
                            Picker("Select Subject".localized(), selection: $selectedSingleSubject) {
                                ForEach(availableSubjects, id: \.self) { subject in
                                    Text(subject.localized()).tag(subject)
                                }
                            }
                            .padding(.top, 8)
                        } else {
                            List {
                                Text("Select Multiple Subjects".localized())
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                ForEach(availableSubjects, id: \.self) { subject in
                                    HStack {
                                        Text(subject.localized())
                                        Spacer()
                                        if selectedMultipleSubjects.contains(subject) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if selectedMultipleSubjects.contains(subject) {
                                            selectedMultipleSubjects.removeAll { $0 == subject }
                                        } else {
                                            selectedMultipleSubjects.append(subject)
                                        }
                                    }
                                }
                            }
                            .frame(height: dynamicListHeight)
                            .listStyle(.plain)
                        }
                    }

                    if isComprehensiveExam {
                        DatePicker("Start Date".localized(), selection: $examDate, displayedComponents: .date)
                        DatePicker("End Date".localized(), selection: $examEndDate, in: examDate...Date.distantFuture, displayedComponents: .date)
                    } else {
                        DatePicker("Date".localized(), selection: $examDate, displayedComponents: .date)
                    }
                }

                Section(header: Text("Assessment".localized())) {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Importance".localized())
                            Spacer()
                            Text("\(importance) / 5".localized())
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            ForEach(1...5, id: \.self) { index in
                                Image(systemName: index <= importance ? "star.fill" : "star")
                                    .foregroundColor(index <= importance ? .yellow : .gray)
                                    .font(.title3)
                                    .onTapGesture {
                                        withAnimation { importance = index }
                                    }
                            }
                        }
                    }

                    VStack(alignment: .leading) {
                        HStack {
                            Text("Mastery Degree".localized())
                            Spacer()
                            Text("\(masteryDegree)%".localized())
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: Binding(
                            get: { Double(masteryDegree) },
                            set: { masteryDegree = Int($0) }
                        ), in: 0...100, step: 5)
                    }
                }

                Section(header: Text("Notes".localized()), footer: Text("Optional details.".localized())) {
                    TextField("Specific Exam Title or Notes".localized(), text: $examNote)
                }

                // 添加到日历选项
                Section(header: Text("Calendar".localized()), footer: Text("Add this exam to your system calendar with a 1-day advance reminder.".localized())) {
                    Toggle("Add to Calendar".localized(), isOn: $addToCalendarToggle)
                }

                if addToCalendarToggle {
                    if isComprehensiveExam {
                        ForEach($subjectTimeEntries) { $entry in
                            Section(header: Text(entry.subject.localized())) {
                                let now = Date()
                                let safeMin = max(examDate, now)
                                let endOfExam = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: examEndDate) ?? examEndDate
                                let safeMax = max(safeMin, endOfExam)
                                DatePicker("Start Time".localized(), selection: $entry.startTime, in: safeMin...safeMax, displayedComponents: [.date, .hourAndMinute])
                                DatePicker("End Time".localized(), selection: $entry.endTime, in: safeMin...safeMax, displayedComponents: [.date, .hourAndMinute])
                            }
                        }
                    } else {
                        ForEach($subjectTimeEntries) { $entry in
                            Section(header: Text(entry.subject.localized())) {
                                let now = Date()
                                let isToday = Calendar.current.isDate(examDate, inSameDayAs: now)
                                let timeMin = isToday ? now : Calendar.current.startOfDay(for: examDate)
                                let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: examDate) ?? examDate
                                let timeMax = max(timeMin, endOfDay)
                                DatePicker("Start Time".localized(), selection: $entry.startTime, in: timeMin...timeMax, displayedComponents: .hourAndMinute)
                                DatePicker("End Time".localized(), selection: $entry.endTime, in: timeMin...timeMax, displayedComponents: .hourAndMinute)
                            }
                        }
                    }
                }
            }
            .adaptiveForm()
            .onChange(of: isComprehensiveExam) { _, _ in syncSubjectTimeEntries() }
            .onChange(of: selectedSingleSubject) { _, _ in syncSubjectTimeEntries() }
            .onChange(of: selectedMultipleSubjects) { _, _ in syncSubjectTimeEntries() }
            .onChange(of: examDate) { _, _ in syncSubjectTimeEntries() }
            .onChange(of: examEndDate) { _, _ in syncSubjectTimeEntries() }
            .navigationTitle("New Exam".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel".localized()) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save".localized()) {
                        saveExam()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || (isComprehensiveExam && examDate > examEndDate) || (!isComprehensiveExam && selectedSingleSubject.isEmpty) || (isComprehensiveExam && selectedMultipleSubjects.isEmpty))
                }
            }
        }
        .alert("Calendar".localized(), isPresented: $showingCalendarAlert) {
            Button("OK".localized()) { dismiss() }
        } message: {
            Text(calendarAlertMessage)
        }
    }

    private func syncSubjectTimeEntries() {
        let selected = isComprehensiveExam ? selectedMultipleSubjects : [selectedSingleSubject].filter { !$0.isEmpty }

        // 1. 更新已有条目：保持时分不变，将日期部分更新为当前的 examDate
        for index in subjectTimeEntries.indices {
            guard selected.contains(subjectTimeEntries[index].subject) else { continue }
            let oldStart = subjectTimeEntries[index].startTime
            let oldEnd   = subjectTimeEntries[index].endTime

            // 提取原有的时分
            let compsStart = Calendar.current.dateComponents([.hour, .minute], from: oldStart)
            let compsEnd   = Calendar.current.dateComponents([.hour, .minute], from: oldEnd)

            // 在 examDate 上重新组合
            let newStart = Calendar.current.date(bySettingHour: compsStart.hour ?? 8,
                                                  minute: compsStart.minute ?? 0,
                                                  second: 0,
                                                  of: examDate) ?? examDate
            var newEnd   = Calendar.current.date(bySettingHour: compsEnd.hour ?? 10,
                                                  minute: compsEnd.minute ?? 0,
                                                  second: 0,
                                                  of: examDate) ?? examDate
            // 保证结束时间不早于开始时间
            if newEnd <= newStart {
                newEnd = Calendar.current.date(byAdding: .hour, value: 1, to: newStart) ?? newStart
            }
            subjectTimeEntries[index].startTime = newStart
            subjectTimeEntries[index].endTime   = newEnd
        }

        // 2. 移除不再选择的科目
        subjectTimeEntries.removeAll { !selected.contains($0.subject) }

        // 3. 为新增的科目添加默认时间段（基于 examDate）
        let existingSubjects = subjectTimeEntries.map { $0.subject }
        for sub in selected where !existingSubjects.contains(sub) {
            let defaultStart = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: examDate) ?? examDate
            let defaultEnd   = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: examDate) ?? examDate
            subjectTimeEntries.append(SubjectTimeEntry(subject: sub, startTime: defaultStart, endTime: defaultEnd))
        }
    }
    
    private func saveExam() {
        guard !name.isEmpty else { return }
        
        ExamPrepareNotifications.shared.scheduleNotifications(for: name, date: examDate)
        
        if isComprehensiveExam {
            var timeSlots: [String: ExamTimeSlot] = [:]
            for entry in subjectTimeEntries {
                timeSlots[entry.subject] = ExamTimeSlot(startTime: entry.startTime, endTime: entry.endTime)
            }
            
            let newCompExam = comprehensiveExam(
                name: name,
                date: examDate,
                importance: importance,
                subject: selectedMultipleSubjects,
                examName: name,
                masteryDegree: masteryDegree,
                examEndDate: examEndDate,
                subjectTimeSlots: addToCalendarToggle ? timeSlots : nil
            )
            dataManager.comprehensiveExamSets.append(newCompExam)
            dataManager.saveComprehensiveExams()
            
            if addToCalendarToggle {
                Task {
                    do {
                        for entry in subjectTimeEntries {
                            _ = try await CalendarManager.shared.addExamToCalendar(
                                examName: name,
                                subject: entry.subject,
                                examDate: examDate,
                                startTime: entry.startTime,
                                endTime: entry.endTime,
                                note: examNote.isEmpty ? nil : examNote
                            )
                        }
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
            } else {
                dismiss()
            }
            
        } else {
            guard !selectedSingleSubject.isEmpty else { return }
            
            var timeSlot: ExamTimeSlot? = nil
            if addToCalendarToggle, let entry = subjectTimeEntries.first {
                let combinedStart = Calendar.current.date(
                    bySettingHour: Calendar.current.component(.hour, from: entry.startTime),
                    minute: Calendar.current.component(.minute, from: entry.startTime),
                    second: 0,
                    of: examDate
                ) ?? examDate
                let combinedEnd = Calendar.current.date(
                    bySettingHour: Calendar.current.component(.hour, from: entry.endTime),
                    minute: Calendar.current.component(.minute, from: entry.endTime),
                    second: 0,
                    of: examDate
                ) ?? examDate
                timeSlot = ExamTimeSlot(startTime: combinedStart, endTime: combinedEnd)
            }
            
            let newExam = Exam(
                name: name,
                date: examDate,
                importance: importance,
                subject: selectedSingleSubject,
                examName: name,
                masteryDegree: masteryDegree,
                timeSlot: timeSlot
            )
            dataManager.examSets.append(newExam)
            dataManager.saveExamSets()
            
            if addToCalendarToggle, let slot = timeSlot {
                Task {
                    do {
                        _ = try await CalendarManager.shared.addExamToCalendar(
                            examName: name,
                            subject: selectedSingleSubject,
                            examDate: examDate,
                            startTime: slot.startTime,
                            endTime: slot.endTime,
                            note: examNote.isEmpty ? nil : examNote
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
            } else {
                dismiss()
            }
        }
    }
}

#Preview {
    let mockManager = DataManager()
    mockManager.subjects = [
        Subject(name: "Mathematics", enabled: true),
        Subject(name: "Physics", enabled: true),
        Subject(name: "Swift", enabled: true),

    ]
    
    return NewExamSetView()
        .environmentObject(mockManager)
}
