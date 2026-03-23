//
//  NewExamSetView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/23.
//

import SwiftUI

struct NewExamSetView: View {
    // ✅ 从环境中自动获取 DataManager，不需要在 init 中传参
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.presentationMode) var presentationMode
    
    // 表单状态
    @State private var name = ""
    @State private var selectedSubject = "Mathematics"
    @State private var examDate = Date()
    @State private var importance = 3
    @State private var masteryDegree = 50
    @State private var examNote = ""
    
    // 获取可用科目
    private var availableSubjects: [String] {
        dataManager.subjects.filter { $0.enabled }.map { $0.name }
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Basic Info")) {
                    TextField("Exam Name (e.g., Midterm)", text: $name)
                    
                    Picker("Subject", selection: $selectedSubject) {
                        ForEach(availableSubjects, id: \.self) { subject in
                            Text(subject).tag(subject)
                        }
                    }
                    
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
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    private func saveExam() {
        let newExam = Exam(
            name: name.trimmingCharacters(in: .whitespaces),
            date: examDate,
            importance: importance,
            subject: selectedSubject,
            examName: examNote.trimmingCharacters(in: .whitespaces),
            masteryDegree: masteryDegree
        )
        
        dataManager.examSets.append(newExam)
        dataManager.saveExamSets() // 确保 DataManager 里有这个方法
        
        presentationMode.wrappedValue.dismiss()
    }
}

#Preview {
    // ✅ 修复点：删除了 <#Exam#> 占位符，直接调用无参构造
    let mockManager = DataManager()
    mockManager.subjects = [
        Subject(name: "Mathematics", enabled: true),
        Subject(name: "Physics", enabled: true)
    ]
    
    return NewExamSetView()
        .environmentObject(mockManager)
}
