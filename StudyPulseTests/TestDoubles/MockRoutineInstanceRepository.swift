//
//  MockRoutineInstanceRepository.swift
//  StudyPulseTests
//
//  RoutineInstanceRepository 的纯内存 Mock 测试替身。
//  In-memory mock implementation of RoutineInstanceRepository for unit tests.
//

import Foundation
import SwiftData
@testable import StudyPulse

@MainActor
final class MockRoutineInstanceRepository: RoutineInstanceRepository, @unchecked Sendable {
    var allInstances: [RoutineInstance] = []

    var todayInstances: [RoutineInstance] {
        let cal = Calendar.current
        return allInstances.filter { cal.isDateInToday($0.date) }
    }

    var activeInstances: [RoutineInstance] {
        let now = Date()
        return allInstances.filter { now >= $0.startTime && now < $0.endTime && !$0.isCompleted }
    }

    // MARK: - 调用状态追踪

    var loadAllCalledCount = 0
    var spawnIfMissingCalledCount = 0
    var updateCalledCount = 0
    var setCompletionCalledCount = 0
    var deleteCalledCount = 0
    var cleanupStaleCalledCount = 0

    init(instances: [RoutineInstance] = []) {
        self.allInstances = instances
    }

    func loadAll(context: ModelContext) async {
        loadAllCalledCount += 1
    }

    @discardableResult
    func spawnIfMissing(_ instance: RoutineInstance) -> Bool {
        spawnIfMissingCalledCount += 1
        if allInstances.contains(where: { $0.routineId == instance.routineId && $0.dateKey == instance.dateKey }) {
            return false
        }
        allInstances.insert(instance, at: 0)
        return true
    }

    func update(_ instance: RoutineInstance) {
        updateCalledCount += 1
        if let idx = allInstances.firstIndex(where: { $0.id == instance.id }) {
            allInstances[idx] = instance
        }
    }

    func setCompletion(_ id: UUID, isCompleted: Bool) {
        setCompletionCalledCount += 1
        if let idx = allInstances.firstIndex(where: { $0.id == id }) {
            allInstances[idx].isCompleted = isCompleted
            allInstances[idx].completedAt = isCompleted ? Date() : nil
        }
    }

    func delete(_ id: UUID) {
        deleteCalledCount += 1
        allInstances.removeAll { $0.id == id }
    }

    @discardableResult
    func cleanupStale(olderThanDays days: Int) -> Int {
        cleanupStaleCalledCount += 1
        let threshold = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let countBefore = allInstances.count
        allInstances.removeAll { $0.date < threshold }
        return countBefore - allInstances.count
    }
}
