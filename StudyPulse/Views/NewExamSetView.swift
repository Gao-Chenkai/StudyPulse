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
    @State private var examDate = Date()
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



//                    Picker("！Subject！", selection: $selectedSubject) {
//                        ForEach(availableSubjects, id: \.self) { subject in
//                            Text(subject).tag(subject)
//                        }
//                    }

                    DatePicker("Date".localized(), selection: $examDate, displayedComponents: .date)
                }

                Section(header: Text("Assessment".localized())) {
                    // 重要性
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

                    // 掌握程度
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
            }
            .adaptiveForm()
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
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .alert("Calendar".localized(), isPresented: $showingCalendarAlert) {
            Button("OK".localized()) { dismiss() }
        } message: {
            Text(calendarAlertMessage)
        }
    }
    
    
    private func saveExam() {
        guard !name.isEmpty, !name.isEmpty else { return }
        
        // 4.4新增：考试临近通知
        ExamPrepareNotifications.shared.scheduleNotifications(for: name, date: examDate)
        
        // 确定科目名称（用于日历）
        var calendarSubject = ""
        if isComprehensiveExam {
            calendarSubject = selectedMultipleSubjects.joined(separator: ", ")
        } else {
            calendarSubject = selectedSingleSubject
        }
        
        if isComprehensiveExam {
            // 综合考试 -> 存入综合数组并持久化
            let newCompExam = comprehensiveExam(
                name: name,
                date: examDate,
                importance: importance,
                subject: selectedMultipleSubjects,
                examName: name,
                masteryDegree: masteryDegree
            )
            dataManager.comprehensiveExamSets.append(newCompExam)
            dataManager.saveComprehensiveExams()
            
        } else {
            // 单科考试校验+保存
            guard !selectedSingleSubject.isEmpty else { return }
            let newExam = Exam(
                name: name,
                date: examDate,
                importance: importance,
                subject: selectedSingleSubject,
                examName: name,
                masteryDegree: masteryDegree
            )
            dataManager.examSets.append(newExam)
            dataManager.saveExamSets()
        }
        
        // 如果勾选了添加到日历
        if addToCalendarToggle {
            Task {
                do {
                    _ = try await CalendarManager.shared.addExamToCalendar(
                        examName: name,
                        subject: calendarSubject,
                        examDate: examDate,
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
