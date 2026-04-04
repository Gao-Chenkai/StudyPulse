//
//  NewExamSetView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/23.
//

import SwiftUI
import UserNotifications

struct NewExamSetView: View {
    // ✅ 从环境中自动获取 DataManager，不需要在 init 中传参
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
    
    // 单科选择（String）
    @State private var selectedSingleSubject: String = ""
    // 多科目选择（[String]，用来存多选结果）
    @State private var selectedMultipleSubjects: [String] = []
    
    var enabledSubjects: [Subject] {
        dataManager.subjects.filter {
            $0.enabled && !$0.name.starts(with: "GROUP:")
        }
    }
    
    // 👇 【动态高度】每个科目 80pt
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
        NavigationView {
            Form {
                Section(header: Text("Basic Info")) {
                    TextField("Exam Name (e.g., Midterm)", text: $name)
                    
                    VStack {
                        Picker("Exam Numbers", selection: $isComprehensiveExam) {
                            Text("Single Subject")
                                .tag(false)
                            Text("Comprehensive Exam")
                                .tag(true)
                        }
                        .pickerStyle(.segmented)
                        

                        
                        if !isComprehensiveExam {
                            Picker("Select Subject", selection: $selectedSingleSubject) {
                                ForEach(availableSubjects, id: \.self) { subject in
                                    Text(subject).tag(subject)
                                }
                            }
                            .padding(.top, 8)
                        } else {
                            List {
                                Text("Select Multiple Subjects")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                ForEach(availableSubjects, id: \.self) { subject in
                                    HStack {
                                        Text(subject)
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
                    
                    DatePicker("Date", selection: $examDate, displayedComponents: .date)
                }
                
                Section(header: Text("Assessment")) {
                    // 重要性
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Importance")
                            Spacer()
                            Text("\(importance) / 5")
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
                            Text("Mastery Degree")
                            Spacer()
                            Text("\(masteryDegree)%")
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: Binding(
                            get: { Double(masteryDegree) },
                            set: { masteryDegree = Int($0) }
                        ), in: 0...100, step: 5)
                    }
                }
                
                Section(header: Text("Notes"), footer: Text("Optional details.")) {
                    TextField("Specific Exam Title or Notes", text: $examNote)
                }
            }
            .navigationTitle("New Exam")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveExam()
                        
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    
    private func saveExam() {
        guard !name.isEmpty, !name.isEmpty else { return }
        
        // 4.4新增：考试临近通知
        ExamPrepareNotifications.shared.scheduleNotifications(for: name, date: examDate)
        
        if isComprehensiveExam {
            // 综合考试 -> 存入综合数组并持久化
            let newCompExam = comprehensiveExam(
                name: name,
                date: examDate,
                importance: importance,
                subject: selectedMultipleSubjects,
                examName: name, // 这里也帮你修正为 examName（更合理）
                masteryDegree: masteryDegree
            )
            // ❌ 错误：$dataManager
            // ✅ 正确：dataManager
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
    }
}

#Preview {
    // ✅ 修复点：删除占位符，直接调用无参构造
    let mockManager = DataManager()
    mockManager.subjects = [
        Subject(name: "Mathematics", enabled: true),
        Subject(name: "Physics", enabled: true),
        Subject(name: "Swift", enabled: true),

    ]
    
    return NewExamSetView()
        .environmentObject(mockManager)
}
