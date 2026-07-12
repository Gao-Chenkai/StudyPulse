//
//  TodoViewModel.swift
//  StudyPulse
//
//  Created by Antigravity on 2026/7/12.
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class TodoViewModel: ObservableObject {
    // MARK: - Dependencies
    private let container: RepositoryContainer

    // MARK: - Input/UI States
    @Published var typeFilter: TodoTypeFilter = .all
    @Published var showCompleted: Bool = false
    @Published var showingNewExam: Bool = false
    @Published var showingNewTask: TaskType? = nil
    @Published var selectedExam: Exam? = nil
    @Published var selectedComprehensive: comprehensiveExam? = nil
    @Published var selectedTask: TaskItem? = nil
    @Published var showingPastSheet: Bool = false
    @Published var viewMode: ExamViewMode = ExamViewMode.loadFromDefaults()

    // MARK: - Output States
    @Published private(set) var allEntries: [TodoEntry] = []
    @Published private(set) var upcomingEntries: [TodoEntry] = []
    @Published private(set) var pastEntries: [TodoEntry] = []
    @Published private(set) var groupedUpcoming: [(sectionTitle: String, entries: [TodoEntry])] = []

    // MARK: - Init
    init(container: RepositoryContainer) {
        self.container = container
    }

    static func makeDefault(container: RepositoryContainer) -> TodoViewModel {
        TodoViewModel(container: container)
    }

    // MARK: - Actions
    func recompute() {
        let all = container.todoEntries(includeCompleted: showCompleted)
        let filtered: [TodoEntry]
        if typeFilter == .all {
            filtered = all
        } else {
            filtered = all.filter { entry in
                switch typeFilter {
                case .all:       return true
                case .exam:      return entry.kind == .exam || entry.kind == .comprehensiveExam
                case .homework:  return entry.kind == .homework
                case .reading:   return entry.kind == .reading
                }
            }
        }
        allEntries = filtered

        let todayStart = Calendar.current.startOfDay(for: Date())
        var upcoming: [TodoEntry] = []
        var past: [TodoEntry] = []
        upcoming.reserveCapacity(filtered.count)
        for entry in filtered {
            if entry.date >= todayStart {
                upcoming.append(entry)
            } else {
                past.append(entry)
            }
        }
        upcomingEntries = upcoming
        pastEntries = past

        let now = Date()
        guard let oneWeekLater = Calendar.current.date(byAdding: .day, value: 7, to: now),
              let oneMonthLater = Calendar.current.date(byAdding: .month, value: 1, to: now) else {
            groupedUpcoming = []
            return
        }
        var weekBucket: [TodoEntry] = []
        var monthBucket: [TodoEntry] = []
        var laterBucket: [TodoEntry] = []
        weekBucket.reserveCapacity(upcoming.count)
        for entry in upcoming {
            if entry.date <= oneWeekLater {
                weekBucket.append(entry)
            } else if entry.date <= oneMonthLater {
                monthBucket.append(entry)
            } else {
                laterBucket.append(entry)
            }
        }
        var result: [(String, [TodoEntry])] = []
        if !weekBucket.isEmpty { result.append(("Within 1 Week".localized(), weekBucket)) }
        if !monthBucket.isEmpty { result.append(("Within 1 Month".localized(), monthBucket)) }
        if !laterBucket.isEmpty { result.append(("Later".localized(), laterBucket)) }
        groupedUpcoming = result
    }

    func toggleCompletion(for task: TaskItem) {
        var updated = task
        updated.isCompleted.toggle()
        container.taskRepo.update(updated, reminderResult: nil)
        recompute()
    }

    func toggleCompletion(for exam: Exam) {
        _ = exam
    }

    func deleteTodoEntry(_ entry: TodoEntry) {
        switch entry.kind {
        case .homework, .reading:
            if let task = container.taskRepo.taskItems.first(where: { $0.id == entry.id }) {
                container.taskRepo.delete(task)
            }
        case .exam:
            if let exam = container.examRepo.examSets.first(where: { $0.id == entry.id }) {
                container.examRepo.deleteExam(exam)
            }
        case .comprehensiveExam:
            if let exam = container.examRepo.comprehensiveExamSets.first(where: { $0.id == entry.id }) {
                container.examRepo.deleteComprehensiveExam(exam)
            }
        }
        recompute()
    }
}
