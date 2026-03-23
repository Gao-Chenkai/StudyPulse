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
    
    @State private var subject = ""
    @State private var score = 85.0
    @State private var rawScore: Double?
    @State private var useRawScore = false
    @State private var ranking: Int?
    @State private var importance = 3
    @State private var examName = ""
    
    // 1. 新增日期状态变量，默认为今天
    @State private var selectedDate = Date()
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Exam Details")) {
                    TextField("Exam Name", text: $examName)
                    
                    // 2. 新增日期选择器
                    DatePicker(
                        "Exam Date",
                        selection: $selectedDate,
                        displayedComponents: .date // 只显示日期，不显示时间
                    )
                    
                    Picker("Subject", selection: $subject) {
                        ForEach(dataManager.subjects.filter { $0.enabled }, id: \.name) { sub in
                            Text(sub.name).tag(sub.name)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section(header: Text("Scores")) {
                    VStack {
                        Text("Score: \(String(format: "%.1f", score))")
                        Slider(value: $score, in: 0...150, step: 0.5)
                    }
                    
                    Toggle("Use Raw Score", isOn: $useRawScore)
                    
                    
                    if useRawScore {
                        VStack {
                            Text("Raw Score: \(rawScore != nil ? String(format: "%.1f", rawScore!) : "Not set")")
                            Slider(value: Binding(
                                get: { rawScore ?? 85.0 },
                                set: { rawScore = $0 }
                            ), in: 0...150, step: 1)
                        }
                    }
                    
                    HStack {
                        Text("Ranking")
                        Spacer()
                        TextField("Enter ranking", value: Binding(
                            get: { ranking ?? 0 },
                            set: { ranking = $0 == 0 ? nil : $0 }
                        ), formatter: NumberFormatter())
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                    }
                }
                
                Section(header: Text("Importance")) {
                    HStack {
                        Text("How important was this exam?")
                        Spacer()
                        ForEach(1...5, id: \.self) { level in
                            Button(action: {
                                importance = level
                            }) {
                                Image(systemName: level <= importance ? "star.fill" : "star")
                                    .foregroundColor(level <= importance ? .yellow : .gray)
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
                        let newGrade = Grade(
                            subject: subject,
                            score: score,
                            rawScore: useRawScore ? rawScore : nil,
                            ranking: ranking,
                            importance: importance,
                            date: selectedDate, // 3. 使用选择的日期
                            examName: examName
                        )
                        
                        dataManager.grades.append(newGrade)
                        dataManager.saveGrades()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(subject.isEmpty)
                }
            }
        }
    }
}

#Preview {
    AddGradeView()
        .environmentObject(DataManager())
}
