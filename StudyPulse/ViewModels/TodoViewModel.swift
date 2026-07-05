//
//  TodoViewModel.swift
//  StudyPulse
//
//  待办页 ViewModel。负责 type filter / past vs upcoming 拆分 / 时间分桶。
// 抽取自 TodoView.recomputeEntries() 78 行派生算法。
//
//  Created for MVVM refactor (2026-07-05).
//  Updated for Repository pattern (2026-07-05).
//

import Foundation
import Combine

@MainActor
final class TodoViewModel: ObservableObject {

    // MARK: - Dependencies

    private let container: RepositoryContainer

    // MARK: - Input State(View 写,VM 读)

    @Published var typeFilter: TodoTypeFilter = .all
    @Published var showCompleted: Bool = false

    // MARK: - Output State

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

    // MARK: - 业务方法

    /// 集中重算所有缓存
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

        // 单次遍历拆分 past / upcoming
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

        // 单次遍历分桶
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

    // MARK: - 业务方法:完成任务

    func toggleCompletion(for task: TaskItem) {
        var updated = task
        updated.isCompleted.toggle()
        container.taskRepo.update(updated, reminderResult: nil)
        recompute()
    }

    func toggleCompletion(for exam: Exam) {
        // Exam 当前没有 isCompleted 字段,留作 hook(后续若加字段再实现)
        _ = exam
    }
}
