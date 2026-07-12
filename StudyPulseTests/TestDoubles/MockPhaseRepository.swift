//
//  MockPhaseRepository.swift
//  StudyPulseTests
//
//  PhaseRepository 的纯内存 Mock 测试替身。
//  In-memory mock implementation of PhaseRepository for unit tests.
//

import Foundation
import SwiftData
@testable import StudyPulse

@MainActor
final class MockPhaseRepository: PhaseRepository, @unchecked Sendable {
    var phases: [StudyPhase] = []
    var activePhase: StudyPhase?

    var stubHasUnassignedData = false
    var stubUnassignedRecordCount = 0

    var hasUnassignedData: Bool { stubHasUnassignedData }
    var unassignedRecordCount: Int { stubUnassignedRecordCount }
    var phaseFilterEnabled: Bool { activePhase != nil }

    // MARK: - 调用状态追踪

    var loadAllCalledCount = 0
    var addCalledCount = 0
    var updateCalledCount = 0
    var deleteCalledCount = 0
    var setArchivedCalledCount = 0
    var activateCalledCount = 0
    var assignUnassignedCalledCount = 0
    var clearPhaseReferencesCalledCount = 0

    var stubAssignResult = (grades: 0, mistakes: 0, exams: 0, comprehensiveExams: 0, tasks: 0)

    init(phases: [StudyPhase] = [], activePhase: StudyPhase? = nil) {
        self.phases = phases
        self.activePhase = activePhase
    }

    func loadAll(context: ModelContext) async {
        loadAllCalledCount += 1
    }

    func add(_ phase: StudyPhase) {
        addCalledCount += 1
        phases.append(phase)
    }

    func update(_ phase: StudyPhase) {
        updateCalledCount += 1
        if let idx = phases.firstIndex(where: { $0.id == phase.id }) {
            phases[idx] = phase
        }
        if activePhase?.id == phase.id {
            activePhase = phase
        }
    }

    func delete(_ phase: StudyPhase) {
        deleteCalledCount += 1
        phases.removeAll { $0.id == phase.id }
        if activePhase?.id == phase.id {
            activePhase = nil
        }
    }

    func setArchived(_ phase: StudyPhase, archived: Bool) {
        setArchivedCalledCount += 1
        if let idx = phases.firstIndex(where: { $0.id == phase.id }) {
            phases[idx].isArchived = archived
            phases[idx].archivedAt = archived ? Date() : nil
        }
    }

    func activate(_ phase: StudyPhase?) {
        activateCalledCount += 1
        activePhase = phase
    }

    func assignUnassignedDataToPhase(_ phaseId: UUID) -> (grades: Int, mistakes: Int, exams: Int, comprehensiveExams: Int, tasks: Int) {
        assignUnassignedCalledCount += 1
        return stubAssignResult
    }

    func clearPhaseReferences(phaseId: UUID) {
        clearPhaseReferencesCalledCount += 1
    }
}
