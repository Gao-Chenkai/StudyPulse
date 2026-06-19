//
//  ExamDetailView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/23.
//

import SwiftUI
import EventKit

struct ExamDetailView: View {
    let exam: Exam
    @EnvironmentObject var dataManager: DataManager
    @State private var showingEditSheet = false
    @State private var showingCalendarAlert = false
    @State private var calendarAlertMessage = ""
    
    // 关联的错题
    var relatedMistakes: [MistakeNote] {
        dataManager.mistakeSets
            .filter { $0.subject == exam.subject }
            .sorted { $0.date > $1.date }
    }
    
    var body: some View {
        Form {
            Section(header: Text("Overview".localized())
                .foregroundColor(Color(.secondaryLabel))
            ) {
                LabeledContent("Exam Name".localized(), value: exam.name)
                    .foregroundColor(Color(.label))
                LabeledContent("Subject".localized(), value: exam.subject)
                    .foregroundColor(Color(.label))

                LabeledContent("Date".localized(), value: exam.examDate.formatted(date: .complete, time: .omitted))
                    .foregroundColor(Color(.label))

                if !exam.examName.isEmpty {
                    LabeledContent("Note/Title".localized(), value: exam.examName)
                        .foregroundColor(Color(.label))
                }
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            Section(header: Text("Metrics".localized())
                .foregroundColor(Color(.secondaryLabel))
            ) {
                HStack {
                    Text("Importance".localized())
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
                    Text("Mastery Degree".localized())
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

            Section(header: Text("Time Status".localized())
                .foregroundColor(Color(.secondaryLabel))
            ) {
                let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: exam.examDate).day ?? 0
                HStack {
                    Text("Days Remaining".localized())
                        .foregroundColor(Color(.label))
                    Spacer()
                    Text("\(max(0, daysLeft)) days")
                        .fontWeight(.semibold)
                        .foregroundColor(daysLeft <= 3 ? Color(.systemRed) : Color(.label))
                }
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
                Text("Will create an all-day event with a 1-day advance reminder in your system calendar.".localized())
                    .foregroundColor(.secondary)
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            // MARK: - 关联的错题
            Section(header: Text("Related Mistakes".localized())
                .foregroundColor(Color(.secondaryLabel))
            ) {
                if relatedMistakes.isEmpty {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.secondary)
                        Text("No related mistakes for this subject".localized())
                            .foregroundColor(.secondary)
                    }
                    .listRowBackground(Color(.secondarySystemGroupedBackground))
                } else {
                    ForEach(relatedMistakes.prefix(4)) { mistake in
                        NavigationLink(destination: MistakeSetDetailView(mistakeSet: mistake).environmentObject(dataManager)) {
                            RelatedMistakeCard(mistake: mistake)
                        }
                    }

                    if relatedMistakes.count > 4 {
                        HStack {
                            Spacer()
                            Text(String(format: "+ %d more mistakes".localized(), relatedMistakes.count - 4))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .listRowBackground(Color(.secondarySystemGroupedBackground))
                    }
                }
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(exam.name)
        .navigationBarTitleDisplayMode(.large)
        .adaptiveMaxWidth(720)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit".localized()) {
                    showingEditSheet = true
                }
                .foregroundColor(Color(.systemBlue))
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            ExamDetailEditView(exam: exam)
                .environmentObject(dataManager)
                .adaptiveSheet()
        }
        .alert("Calendar".localized(), isPresented: $showingCalendarAlert) {
            Button("OK".localized()) { }
        } message: {
            Text(calendarAlertMessage)
        }
    }
    
    private func addToCalendar() {
        Task {
            do {
                _ = try await CalendarManager.shared.addExamToCalendar(
                    examName: exam.name,
                    subject: exam.subject,
                    examDate: exam.examDate,
                    note: exam.examName.isEmpty ? nil : exam.examName
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

// MARK: - 关联的错题卡片
struct RelatedMistakeCard: View {
    let mistake: MistakeNote
    @State private var animateIn = false
    
    var totalImages: Int {
        mistake.questionImages.count + mistake.reasonImages.count +
        mistake.wrongSolutionImages.count + mistake.correctSolutionImages.count
    }
    
    var daysSinceAdded: String {
        let components = Calendar.current.dateComponents([.day], from: mistake.date, to: Date())
        let days = components.day ?? 0
        if days == 0 {
            return "Today".localized()
        } else if days == 1 {
            return "Yesterday".localized()
        } else if days < 7 {
            return "\(days) " + "days ago".localized()
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: mistake.date)
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(mistake.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if !mistake.originalQuestion.isEmpty {
                    Text(mistake.originalQuestion)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack(spacing: 8) {
                    if !mistake.subject.isEmpty {
                        Text(mistake.subject.localized())
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemPurple).opacity(0.15))
                            .foregroundColor(Color(.systemPurple))
                            .cornerRadius(4)
                    }
                    
                    Text(daysSinceAdded)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if totalImages > 0 {
                        Label("\(totalImages)", systemImage: "photo")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(.systemGroupedBackground))
        .cornerRadius(10)
        .opacity(animateIn ? 1 : 0)
        .offset(x: animateIn ? 0 : -15)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85).delay(0.05)) {
                animateIn = true
            }
        }
    }
}

#Preview("Dark Mode") {
    let dm = DataManager()
    let testExam = Exam(name: "Test", date: Date().addingTimeInterval(1000), importance: 3, subject: "Math", examName: "", masteryDegree: 50)
    dm.examSets = [testExam]
    return ExamDetailView(exam: testExam)
        .environmentObject(dm)
        .preferredColorScheme(.dark)
}
