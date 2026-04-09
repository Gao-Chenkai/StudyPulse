//
//  ExamDetailView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/23.
//

import SwiftUI

struct ExamDetailView: View {
    let exam: Exam
    @EnvironmentObject var dataManager: DataManager
    @State private var showingEditSheet = false
    
    var body: some View {
        Form {
            Section(header: Text("Overview")
                .foregroundColor(Color(.secondaryLabel))
            ) {
                LabeledContent("Exam Name", value: exam.name)
                    .foregroundColor(Color(.label))
                LabeledContent("Subject", value: exam.subject)
                    .foregroundColor(Color(.label))
                
                LabeledContent("Date", value: exam.examDate.formatted(date: .complete, time: .omitted))
                    .foregroundColor(Color(.label))
                
                if !exam.examName.isEmpty {
                    LabeledContent("Note/Title", value: exam.examName)
                        .foregroundColor(Color(.label))
                }
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))
            
            Section(header: Text("Metrics")
                .foregroundColor(Color(.secondaryLabel))
            ) {
                HStack {
                    Text("Importance")
                        .foregroundColor(Color(.label))
                    Spacer()
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { i in
                            Image(systemName: i <= exam.importance ? "star.fill" : "star")
                                .foregroundColor(i <= exam.importance ? .yellow : Color(.tertiaryLabel))
                        }
                    }
                }
                
                HStack {
                    Text("Mastery Degree")
                        .foregroundColor(Color(.label))
                    Spacer()
                    Text("\(exam.masteryDegree)%")
                        .fontWeight(.semibold)
                        .foregroundColor(masteryColor)
                }
                ProgressView(value: Double(exam.masteryDegree), total: 100.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: masteryProgressColor))
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))
            
            Section(header: Text("Time Status")
                .foregroundColor(Color(.secondaryLabel))
            ) {
                let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: exam.examDate).day ?? 0
                HStack {
                    Text("Days Remaining")
                        .foregroundColor(Color(.label))
                    Spacer()
                    Text("\(max(0, daysLeft)) days")
                        .fontWeight(.semibold)
                        .foregroundColor(daysLeft <= 3 ? Color(.systemRed) : Color(.label))
                }
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(exam.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showingEditSheet = true
                }
                .foregroundColor(Color(.systemBlue))
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            ExamDetailEditView(exam: exam)
                .environmentObject(dataManager)
        }
    }
    
    // 根据掌握程度确定颜色
    private var masteryColor: Color {
        if exam.masteryDegree <= 20 {
            return Color(.systemRed)
        } else if exam.masteryDegree <= 60 {
            return Color(.systemOrange)
        } else {
            return Color(.systemGreen)
        }
    }
    
    // 进度条颜色
    private var masteryProgressColor: Color {
        if exam.masteryDegree <= 20 {
            return Color(.systemRed)
        } else if exam.masteryDegree <= 60 {
            return Color(.systemOrange)
        } else {
            return Color(.systemBlue)
        }
    }
}

#Preview {
    let dm = DataManager()
    let testExam = Exam(name: "Test", date: Date().addingTimeInterval(1000), importance: 3, subject: "Math", examName: "", masteryDegree: 50)
    dm.examSets = [testExam]
    return ExamDetailView(exam: testExam)
        .environmentObject(dm)
}

#Preview("Dark Mode") {
    let dm = DataManager()
    let testExam = Exam(name: "Test", date: Date().addingTimeInterval(1000), importance: 3, subject: "Math", examName: "", masteryDegree: 50)
    dm.examSets = [testExam]
    return ExamDetailView(exam: testExam)
        .environmentObject(dm)
        .preferredColorScheme(.dark)
}
