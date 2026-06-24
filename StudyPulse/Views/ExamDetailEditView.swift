//
//  ExamDetailEditView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/23.
//

import SwiftUI
import os

struct ExamDetailEditView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.presentationMode) var presentationMode
    
    // 接收要编辑的原始对象
    let originalExam: Exam
    
    // 绑定到表单的状态变量 (初始化为原始值)
    @State private var name: String
    @State private var selectedSubject: String
    @State private var examDate: Date
    @State private var importance: Int
    @State private var masteryDegree: Int
    @State private var examNote: String
    @State private var subjectStartTime: Date
    @State private var subjectEndTime: Date
    
    init(exam: Exam) {
        self.originalExam = exam
        // 初始化状态
        _name = State(initialValue: exam.name)
        _selectedSubject = State(initialValue: exam.subject)
        _examDate = State(initialValue: exam.examDate)
        _importance = State(initialValue: exam.importance)
        _masteryDegree = State(initialValue: exam.masteryDegree)
        _examNote = State(initialValue: exam.examName)
        let slot = exam.timeSlot
        _subjectStartTime = State(initialValue: slot?.startTime ?? exam.examDate)
        _subjectEndTime = State(initialValue: slot?.endTime ?? Calendar.current.date(byAdding: .hour, value: 2, to: slot?.startTime ?? exam.examDate) ?? exam.examDate)
    }
    
    private var availableSubjects: [String] {
        dataManager.subjects.filter { $0.enabled }.map { $0.name }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Basic Info".localized())) {
                    TextField("Exam Name".localized(), text: $name)

                    Picker("Subject".localized(), selection: $selectedSubject) {
                        ForEach(availableSubjects, id: \.self) { subject in
                            Text(subject).tag(subject)
                        }
                    }

                    DatePicker("Date".localized(), selection: $examDate, displayedComponents: .date)

                    DatePicker("Start Time".localized(), selection: $subjectStartTime, displayedComponents: .hourAndMinute)
                    DatePicker("End Time".localized(), selection: $subjectEndTime, displayedComponents: .hourAndMinute)
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

                Section(header: Text("Notes".localized())) {
                    TextField("Specific Exam Title or Notes".localized(), text: $examNote)
                }
            }
            .adaptiveForm()
            .navigationTitle("Edit Exam".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel".localized()) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save".localized()) {
                        updateExam()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    private func updateExam() {
        // 创建一个新的 Exam 对象，但保留原始的 ID
        let updatedExam = Exam(
            name: name.trimmingCharacters(in: .whitespaces),
            date: examDate,
            importance: importance,
            subject: selectedSubject,
            examName: examNote.trimmingCharacters(in: .whitespaces),
            masteryDegree: masteryDegree,
            timeSlot: ExamTimeSlot(startTime: subjectStartTime, endTime: subjectEndTime)
        )
        
        // 关键：保留原始 ID，这样才能在数组中找到它
        // 由于 Exam 是 struct，我们需要手动替换数组中的元素
        if let index = dataManager.examSets.firstIndex(where: { $0.id == originalExam.id }) {
            var examToUpdate = updatedExam
            examToUpdate.id = originalExam.id // 强制保持 ID 不变 / Force keep the same ID

            dataManager.examSets[index] = examToUpdate
            dataManager.saveExamSets()
            Log.data.info("考试编辑成功 / Exam updated: name=\(examToUpdate.name, privacy: .public) id=\(originalExam.id.uuidString, privacy: .public)")
            presentationMode.wrappedValue.dismiss()
        } else {
            Log.data.error("考试编辑失败：未找到要更新的考试 / Exam update failed: could not find exam id=\(originalExam.id.uuidString, privacy: .public)")
        }
    }
}

#Preview {
    let dm = DataManager()
    let testExam = Exam(name: "Final Physics", date: Date().addingTimeInterval(86400*20), importance: 5, subject: "Physics", examName: "Mechanics", masteryDegree: 40)
    dm.examSets = [testExam]
    
    return ExamDetailEditView(exam: testExam)
        .environmentObject(dm)
}
