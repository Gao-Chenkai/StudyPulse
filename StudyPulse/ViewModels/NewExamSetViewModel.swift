//
//  NewExamSetViewModel.swift
//  StudyPulse
//
//  Created by Antigravity on 2026/7/12.
//

import Foundation
import SwiftUI
import Combine

struct SubjectTimeEntry: Identifiable, Equatable {
    let id: UUID
    let subject: String
    var startTime: Date
    var endTime: Date

    init(id: UUID = UUID(), subject: String, startTime: Date? = nil, endTime: Date? = nil) {
        self.id = id
        self.subject = subject
        let defaultStart = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
        let defaultEnd = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date()) ?? Date()
        self.startTime = startTime ?? defaultStart
        self.endTime = endTime ?? defaultEnd
    }
}

@MainActor
final class NewExamSetViewModel: ObservableObject {
    // MARK: - Dependencies
    private let container: RepositoryContainer

    // MARK: - Form States
    @Published var name = ""
    @Published var selectedSubject = "Mathematics"
    @Published var isComprehensiveExam = false
    @Published var examDate: Date = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    @Published var examEndDate: Date = Calendar.current.date(byAdding: .day, value: 3, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    @Published var importance = 3
    @Published var masteryDegree = 50
    @Published var examNote = ""
    
    // Calendar & Alert states
    @Published var addToCalendarToggle = true
    @Published var showingCalendarAlert = false
    @Published var calendarAlertMessage = ""
    
    // Subject Selection states
    @Published var selectedSingleSubject = ""
    @Published var selectedMultipleSubjects: [String] = []
    @Published var subjectTimeEntries: [SubjectTimeEntry] = []

    // MARK: - Init
    init(container: RepositoryContainer) {
        self.container = container
        // Set default single subject
        if let first = availableSubjects.first {
            selectedSingleSubject = first
        }
    }

    // MARK: - Computed Properties
    var enabledSubjects: [Subject] {
        container.subjectRepo.subjects.filter {
            $0.enabled && !$0.name.starts(with: "GROUP:")
        }
    }
    
    var dynamicListHeight: CGFloat {
        CGFloat(enabledSubjects.count * 80)
    }
    
    var availableSubjectNames: [String] {
        enabledSubjects.map { $0.name }
    }
    
    var availableSubjects: [String] {
        container.subjectRepo.subjects.filter { $0.enabled }.map { $0.name }
    }

    var isSaveDisabled: Bool {
        name.trimmingCharacters(in: .whitespaces).isEmpty ||
        (isComprehensiveExam && examDate > examEndDate) ||
        (!isComprehensiveExam && selectedSingleSubject.isEmpty) ||
        (isComprehensiveExam && selectedMultipleSubjects.isEmpty)
    }

    // MARK: - Actions
    func syncSubjectTimeEntries() {
        let selected = isComprehensiveExam ? selectedMultipleSubjects : [selectedSingleSubject].filter { !$0.isEmpty }

        // 1. Update existing entries
        for index in subjectTimeEntries.indices {
            guard selected.contains(subjectTimeEntries[index].subject) else { continue }
            let oldStart = subjectTimeEntries[index].startTime
            let oldEnd   = subjectTimeEntries[index].endTime

            let compsStart = Calendar.current.dateComponents([.hour, .minute], from: oldStart)
            let compsEnd   = Calendar.current.dateComponents([.hour, .minute], from: oldEnd)

            let newStart = Calendar.current.date(bySettingHour: compsStart.hour ?? 8,
                                                  minute: compsStart.minute ?? 0,
                                                  second: 0,
                                                  of: examDate) ?? examDate
            var newEnd   = Calendar.current.date(bySettingHour: compsEnd.hour ?? 10,
                                                  minute: compsEnd.minute ?? 0,
                                                  second: 0,
                                                  of: examDate) ?? examDate
            if newEnd <= newStart {
                newEnd = Calendar.current.date(byAdding: .hour, value: 1, to: newStart) ?? newStart
            }
            subjectTimeEntries[index].startTime = newStart
            subjectTimeEntries[index].endTime   = newEnd
        }

        // 2. Remove entries no longer selected
        subjectTimeEntries.removeAll { !selected.contains($0.subject) }

        // 3. Add default time slots for newly selected subjects
        let existingSubjects = subjectTimeEntries.map { $0.subject }
        for sub in selected where !existingSubjects.contains(sub) {
            let defaultStart = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: examDate) ?? examDate
            let defaultEnd   = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: examDate) ?? examDate
            subjectTimeEntries.append(SubjectTimeEntry(subject: sub, startTime: defaultStart, endTime: defaultEnd))
        }
    }

    func saveExam(onSuccess: @escaping () -> Void) async {
        guard !name.isEmpty else { return }
        
        ExamPrepareNotifications.shared.scheduleNotifications(for: name, date: examDate)
        
        if isComprehensiveExam {
            var timeSlots: [String: ExamTimeSlot] = [:]
            for entry in subjectTimeEntries {
                timeSlots[entry.subject] = ExamTimeSlot(startTime: entry.startTime, endTime: entry.endTime)
            }
            
            let newCompExam = comprehensiveExam(
                name: name,
                date: examDate,
                importance: importance,
                subject: selectedMultipleSubjects,
                examName: name,
                masteryDegree: masteryDegree,
                examEndDate: examEndDate,
                subjectTimeSlots: addToCalendarToggle ? timeSlots : nil
            )
            container.addExams(single: [], comprehensive: [newCompExam])
            
            if addToCalendarToggle {
                do {
                    for entry in subjectTimeEntries {
                        _ = try await CalendarManager.shared.addExamToCalendar(
                            examName: name,
                            subject: entry.subject,
                            examDate: examDate,
                            startTime: entry.startTime,
                            endTime: entry.endTime,
                            note: examNote.isEmpty ? nil : examNote
                        )
                    }
                    calendarAlertMessage = "Successfully added to calendar!".localized()
                    showingCalendarAlert = true
                } catch {
                    calendarAlertMessage = error.localizedDescription
                    showingCalendarAlert = true
                }
            } else {
                onSuccess()
            }
            
        } else {
            guard !selectedSingleSubject.isEmpty else { return }
            
            var timeSlot: ExamTimeSlot? = nil
            if addToCalendarToggle, let entry = subjectTimeEntries.first {
                let combinedStart = Calendar.current.date(
                    bySettingHour: Calendar.current.component(.hour, from: entry.startTime),
                    minute: Calendar.current.component(.minute, from: entry.startTime),
                    second: 0,
                    of: examDate
                ) ?? examDate
                let combinedEnd = Calendar.current.date(
                    bySettingHour: Calendar.current.component(.hour, from: entry.endTime),
                    minute: Calendar.current.component(.minute, from: entry.endTime),
                    second: 0,
                    of: examDate
                ) ?? examDate
                timeSlot = ExamTimeSlot(startTime: combinedStart, endTime: combinedEnd)
            }
            
            let newExam = Exam(
                name: name,
                date: examDate,
                importance: importance,
                subject: selectedSingleSubject,
                examName: name,
                masteryDegree: masteryDegree,
                timeSlot: timeSlot
            )
            container.addExams(single: [newExam], comprehensive: [])
            
            if addToCalendarToggle, let slot = timeSlot {
                do {
                    _ = try await CalendarManager.shared.addExamToCalendar(
                        examName: name,
                        subject: selectedSingleSubject,
                        examDate: examDate,
                        startTime: slot.startTime,
                        endTime: slot.endTime,
                        note: examNote.isEmpty ? nil : examNote
                    )
                    calendarAlertMessage = "Successfully added to calendar!".localized()
                    showingCalendarAlert = true
                } catch {
                    calendarAlertMessage = error.localizedDescription
                    showingCalendarAlert = true
                }
            } else {
                onSuccess()
            }
        }
    }
}
