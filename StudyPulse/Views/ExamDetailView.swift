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
    
    // ✅ 删除了 detailedFormatter，不再需要它

    var body: some View {
        Form {
            Section(header: Text("Overview")) {
                LabeledContent("Exam Name", value: exam.name)
                LabeledContent("Subject", value: exam.subject)
                
                // ✅ 修复：使用 .formatted() 方法直接格式化日期
                LabeledContent("Date", value: exam.examDate.formatted(date: .complete, time: .omitted))
                
                if !exam.examName.isEmpty {
                    LabeledContent("Note/Title", value: exam.examName)
                }
            }
            
            Section(header: Text("Metrics")) {
                HStack {
                    Text("Importance")
                    Spacer()
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { i in
                            Image(systemName: i <= exam.importance ? "star.fill" : "star")
                                .foregroundColor(i <= exam.importance ? .yellow : .gray)
                        }
                    }
                }
                
                HStack {
                    Text("Mastery Degree")
                    Spacer()
                    Text("\(exam.masteryDegree)%")
                        .fontWeight(.semibold)
                }
                ProgressView(value: Double(exam.masteryDegree), total: 100.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            }
            
            Section(header: Text("Time Status")) {
                let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: exam.examDate).day ?? 0
                HStack {
                    Text("Days Remaining")
                    Spacer()
                    Text("\(max(0, daysLeft)) days")
                        .fontWeight(.semibold)
                        .foregroundColor(daysLeft <= 3 ? .red : .primary)
                }
            }
        }
        .navigationTitle(exam.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            ExamDetailEditView(exam: exam)
                .environmentObject(dataManager)
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
