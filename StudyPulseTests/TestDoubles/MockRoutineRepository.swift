//
//  MockRoutineRepository.swift
//  StudyPulseTests
//
//  RoutineRepository 的纯内存 Mock 测试替身。
//  In-memory mock implementation of RoutineRepository for unit tests.
//

import Foundation
import SwiftData
@testable import StudyPulse

@MainActor
final class MockRoutineRepository: RoutineRepository, @unchecked Sendable {
    var routines: [Routine] = []
    var filteredRoutines: [Routine] = []

    var enabledRoutines: [Routine] {
        routines.filter { $0.enabled }
    }

    // MARK: - 调用状态追踪

    var loadAllCalledCount = 0
    var addCalledCount = 0
    var updateCalledCount = 0
    var deleteCalledCount = 0
    var setEnabledCalledCount = 0
    var clearAllCalledCount = 0

    init(routines: [Routine] = [], filteredRoutines: [Routine]? = nil) {
        self.routines = routines
        self.filteredRoutines = filteredRoutines ?? routines
    }

    func loadAll(context: ModelContext) async {
        loadAllCalledCount += 1
    }

    func add(_ routine: Routine) {
        addCalledCount += 1
        routines.append(routine)
        filteredRoutines.append(routine)
    }

    func add(_ newRoutines: [Routine]) {
        addCalledCount += 1
        routines.append(contentsOf: newRoutines)
        filteredRoutines.append(contentsOf: newRoutines)
    }

    func update(_ routine: Routine) {
        updateCalledCount += 1
        if let idx = routines.firstIndex(where: { $0.id == routine.id }) {
            routines[idx] = routine
        }
        if let idx = filteredRoutines.firstIndex(where: { $0.id == routine.id }) {
            filteredRoutines[idx] = routine
        }
    }

    func delete(_ id: UUID) {
        deleteCalledCount += 1
        routines.removeAll { $0.id == id }
        filteredRoutines.removeAll { $0.id == id }
    }

    func setEnabled(_ id: UUID, enabled: Bool) {
        setEnabledCalledCount += 1
        if let idx = routines.firstIndex(where: { $0.id == id }) {
            routines[idx].enabled = enabled
        }
        if let idx = filteredRoutines.firstIndex(where: { $0.id == id }) {
            filteredRoutines[idx].enabled = enabled
        }
    }

    func clearAll() -> Int {
        clearAllCalledCount += 1
        let count = routines.count
        routines.removeAll()
        filteredRoutines.removeAll()
        return count
    }
}
