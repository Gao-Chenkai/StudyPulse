//
//  AddGradeView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import SwiftUI

struct AddGradeView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.presentationMode) var presentationMode
    
    // 基础信息
    @State private var examName = ""
    @State private var selectedDate = Date()
    @State private var importance = 3
    
    // MARK: - 模式选择（与 NewExamSetView 一致）
    @State private var isComprehensiveExam = false
    @State private var selectedSingleSubject = ""
    @State private var selectedMultipleSubjects: [String] = []
    
    // MARK: - 核心修复：用结构体封装每科状态，避免手动 Binding 失效
    struct SubjectScore: Identifiable {
        let id = UUID()
        let subject: String
        var score: Double = 85.0
        var useRawScore: Bool = false
        var rawScore: Double?
        var ranking: Int?
    }
    @State private var subjectScores: [SubjectScore] = []
    
    @StateObject private var subjectInfo = SubjectInfo()
    
    // 可用科目（过滤分组）
    var availableSubjects: [String] {
        dataManager.subjects.filter {
            $0.enabled && !$0.name.starts(with: "GROUP:")
        }.map { $0.name }
    }
    
    // 动态列表高度
    var dynamicListHeight: CGFloat {
        CGFloat(availableSubjects.count * 60)
    }
    
    // 选中科目变化时，同步更新 subjectScores
    private func syncSubjectScores() {
        let selectedSubjects = isComprehensiveExam ? selectedMultipleSubjects : [selectedSingleSubject]
        let existingSubjects = subjectScores.map { $0.subject }
        
        // 新增科目
        for sub in selectedSubjects where !existingSubjects.contains(sub) {
            subjectScores.append(SubjectScore(subject: sub))
        }
        // 删除未选中科目
        subjectScores.removeAll { !selectedSubjects.contains($0.subject) }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Exam Details")) {
                    HStack {
                        Text("Exam Name")
                        TextField("Exam Name", text: $examName)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    DatePicker(
                        "Exam Date",
                        selection: $selectedDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    
                    // MARK: 🔥 Segmented Picker（与 NewExamSetView 一致）
                    VStack(spacing: 8) {
                        Picker("Exam Type", selection: $isComprehensiveExam) {
                            Text("Single Subject").tag(false)
                            Text("Comprehensive Exam").tag(true)
                        }
                        .pickerStyle(.segmented)
                        
                        if !isComprehensiveExam {
                            Picker("Select Subject", selection: $selectedSingleSubject) {
                                ForEach(availableSubjects, id: \.self) { subject in
                                    Text(subject).tag(subject)
                                }
                            }
                            .padding(.top, 10)
                            .padding(2)
                            .onChange(of: selectedSingleSubject) {
                                syncSubjectScores()
                            }
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
                                        syncSubjectScores()
                                    }
                                }
                            }
                            .frame(height: dynamicListHeight)
                            .listStyle(.plain)
                        }
                    }
                }
                
                // MARK: 成绩录入（修复版：用 $subjectScore 直接绑定）
                if !subjectScores.isEmpty {
                    ForEach($subjectScores) { $subjectScore in
                        Section(header: Text("Score: \(subjectScore.subject)")) {
                            let maxScore = subjectInfo.getMaxScore(
                                level: dataManager.profile.educationLevel,
                                subject: subjectScore.subject
                            )
                            
                            VStack {
                                Text("Score: \(String(format: "%.1f", subjectScore.score)) / \(maxScore)")
                                Slider(value: $subjectScore.score, in: 0...Double(maxScore), step: 0.5)
                            }
                            
                            // ✅ 修复：直接绑定 $subjectScore.useRawScore，不再用手动 Binding
                            Toggle("Use Raw Score", isOn: $subjectScore.useRawScore)
                            
                            if subjectScore.useRawScore {
                                VStack {
                                    Text("Raw Score: \(String(format: "%.1f", subjectScore.rawScore ?? 85.0))")
                                    Slider(
                                        value: Binding(
                                            get: { subjectScore.rawScore ?? 85.0 },
                                            set: { subjectScore.rawScore = $0 }
                                        ),
                                        in: 0...Double(maxScore),
                                        step: 0.5
                                    )
                                }
                            }
                            
                            HStack {
                                Text("Ranking")
                                Spacer()
                                TextField("Enter ranking", value: Binding(
                                    get: { subjectScore.ranking ?? 0 },
                                    set: { subjectScore.ranking = $0 == 0 ? nil : $0 }
                                ), formatter: NumberFormatter())
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                    }
                }
                
                // MARK: 重要性
                Section(header: Text("Importance")) {
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
                }
            }
            .navigationTitle("Add New Grade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveGrades()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(saveDisabled)
                }
            }
            .onAppear {
                syncSubjectScores()
            }
        }
    }
}

// MARK: - Save Logic
extension AddGradeView {
    private var saveDisabled: Bool {
        examName.isEmpty || subjectScores.isEmpty
    }
    
    private func saveGrades() {
        for subjectScore in subjectScores {
            let grade = Grade(
                subject: subjectScore.subject,
                score: subjectScore.score,
                rawScore: subjectScore.useRawScore ? subjectScore.rawScore : nil,
                ranking: subjectScore.ranking,
                importance: importance,
                date: selectedDate,
                examName: examName
            )
            dataManager.grades.append(grade)
        }
        dataManager.saveGrades()
    }
}

#Preview {
    AddGradeView()
        .environmentObject(DataManager())
}
