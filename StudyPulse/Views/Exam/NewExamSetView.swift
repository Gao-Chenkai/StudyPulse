//
//  NewExamSetView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/23.
//
//  新建考试表单:单科 / 综合二选一,可设多科目时间槽并写入系统日历
//  New-exam form: single-subject or comprehensive; supports per-subject time slots and calendar write.
//

import SwiftUI
import UserNotifications

/// 新建考试表单
/// New-exam form.
struct NewExamSetView: View {
    @Environment(RepositoryContainer.self) private var container
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel: NewExamSetViewModel

    init(container: RepositoryContainer) {
        _viewModel = StateObject(wrappedValue: NewExamSetViewModel(container: container))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Basic Info".localized())) {
                    TextField("Exam Name (e.g., Midterm)".localized(), text: $viewModel.name)

                    VStack {
                        Picker("Exam Numbers".localized(), selection: $viewModel.isComprehensiveExam) {
                            Text("Single Subject".localized())
                                .tag(false)
                            Text("Comprehensive Exam".localized())
                                .tag(true)
                        }
                        .pickerStyle(.segmented)

                        if !viewModel.isComprehensiveExam {
                            Picker("Select Subject".localized(), selection: $viewModel.selectedSingleSubject) {
                                ForEach(viewModel.availableSubjects, id: \.self) { subject in
                                    Text(subject.localized()).tag(subject)
                                }
                            }
                            .padding(.top, 8)
                        } else {
                            List {
                                Text("Select Multiple Subjects".localized())
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                ForEach(viewModel.availableSubjects, id: \.self) { subject in
                                    HStack {
                                        Text(subject.localized())
                                        Spacer()
                                        if viewModel.selectedMultipleSubjects.contains(subject) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if viewModel.selectedMultipleSubjects.contains(subject) {
                                            viewModel.selectedMultipleSubjects.removeAll { $0 == subject }
                                        } else {
                                            viewModel.selectedMultipleSubjects.append(subject)
                                        }
                                    }
                                }
                            }
                            .frame(height: viewModel.dynamicListHeight)
                            .listStyle(.plain)
                        }
                    }

                    if viewModel.isComprehensiveExam {
                        DatePicker("Start Date".localized(), selection: $viewModel.examDate, displayedComponents: .date)
                        DatePicker("End Date".localized(), selection: $viewModel.examEndDate, in: viewModel.examDate...Date.distantFuture, displayedComponents: .date)
                    } else {
                        DatePicker("Date".localized(), selection: $viewModel.examDate, displayedComponents: .date)
                    }
                }

                Section(header: Text("Assessment".localized())) {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Importance".localized())
                            Spacer()
                            Text("\(viewModel.importance) / 5".localized())
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            ForEach(1...5, id: \.self) { index in
                                Image(systemName: index <= viewModel.importance ? "star.fill" : "star")
                                    .foregroundColor(index <= viewModel.importance ? .yellow : .gray)
                                    .font(.title3)
                                    .onTapGesture {
                                        withAnimation { viewModel.importance = index }
                                    }
                            }
                        }
                    }

                    VStack(alignment: .leading) {
                        HStack {
                            Text("Mastery Degree".localized())
                            Spacer()
                            Text("\(viewModel.masteryDegree)%".localized())
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: Binding(
                            get: { Double(viewModel.masteryDegree) },
                            set: { viewModel.masteryDegree = Int($0) }
                        ), in: 0...100, step: 5)
                    }
                }

                Section(header: Text("Notes".localized()), footer: Text("Optional details.".localized())) {
                    TextField("Specific Exam Title or Notes".localized(), text: $viewModel.examNote)
                }

                Section(header: Text("Calendar".localized()), footer: Text("Add this exam to your system calendar with a 1-day advance reminder.".localized())) {
                    Toggle("Add to Calendar".localized(), isOn: $viewModel.addToCalendarToggle)
                }

                if viewModel.addToCalendarToggle {
                    if viewModel.isComprehensiveExam {
                        ForEach($viewModel.subjectTimeEntries) { $entry in
                            Section(header: Text(entry.subject.localized())) {
                                let now = Date()
                                let safeMin = max(viewModel.examDate, now)
                                let endOfExam = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: viewModel.examEndDate) ?? viewModel.examEndDate
                                let safeMax = max(safeMin, endOfExam)
                                DatePicker("Start Time".localized(), selection: $entry.startTime, in: safeMin...safeMax, displayedComponents: [.date, .hourAndMinute])
                                DatePicker("End Time".localized(), selection: $entry.endTime, in: safeMin...safeMax, displayedComponents: [.date, .hourAndMinute])
                            }
                        }
                    } else {
                        ForEach($viewModel.subjectTimeEntries) { $entry in
                            Section(header: Text(entry.subject.localized())) {
                                let now = Date()
                                let isToday = Calendar.current.isDate(viewModel.examDate, inSameDayAs: now)
                                let timeMin = isToday ? now : Calendar.current.startOfDay(for: viewModel.examDate)
                                let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: viewModel.examDate) ?? viewModel.examDate
                                let timeMax = max(timeMin, endOfDay)
                                DatePicker("Start Time".localized(), selection: $entry.startTime, in: timeMin...timeMax, displayedComponents: .hourAndMinute)
                                DatePicker("End Time".localized(), selection: $entry.endTime, in: timeMin...timeMax, displayedComponents: .hourAndMinute)
                            }
                        }
                    }
                }
            }
            .adaptiveForm()
            .onChange(of: viewModel.isComprehensiveExam) { _, _ in viewModel.syncSubjectTimeEntries() }
            .onChange(of: viewModel.selectedSingleSubject) { _, _ in viewModel.syncSubjectTimeEntries() }
            .onChange(of: viewModel.selectedMultipleSubjects) { _, _ in viewModel.syncSubjectTimeEntries() }
            .onChange(of: viewModel.examDate) { _, _ in viewModel.syncSubjectTimeEntries() }
            .onChange(of: viewModel.examEndDate) { _, _ in viewModel.syncSubjectTimeEntries() }
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
                        Task {
                            await viewModel.saveExam {
                                dismiss()
                            }
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(viewModel.isSaveDisabled)
                }
            }
        }
        .alert("Calendar".localized(), isPresented: $viewModel.showingCalendarAlert) {
            Button("OK".localized()) { dismiss() }
        } message: {
            Text(viewModel.calendarAlertMessage)
        }
        .containerBackground(.clear, for: .navigation)
        .debugModeContainer()
    }
}

#Preview {
    let mockContainer = RepositoryContainer()
    mockContainer.subjectRepo.subjects = [
        Subject(name: "Mathematics", enabled: true),
        Subject(name: "Physics", enabled: true),
        Subject(name: "Swift", enabled: true),
    ]

    return NewExamSetView(container: mockContainer)
        .environment(mockContainer)
}
