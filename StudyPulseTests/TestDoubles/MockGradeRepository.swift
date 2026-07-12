//
//  MockGradeRepository.swift
//  StudyPulseTests
//
//  GradeRepository 的纯内存 Mock 测试替身。
//  In-memory mock implementation of GradeRepository for unit tests.
//

import Foundation
import SwiftData
@testable import StudyPulse

@MainActor
final class MockGradeRepository: GradeRepository, @unchecked Sendable {
    var grades: [Grade] = []
    var filteredGrades: [Grade] = []

    // MARK: - 调用状态追踪

    var loadAllCalledCount = 0
    var reloadFromSwiftDataCalledCount = 0
    var migrateInlineImagesCalledCount = 0
    var addCalledCount = 0
    var updateCalledCount = 0
    var deleteCalledCount = 0
    var clearAllCalledCount = 0

    var lastAddedGrade: Grade?
    var lastUpdatedGrade: Grade?
    var lastDeletedGrade: Grade?

    init(grades: [Grade] = [], filteredGrades: [Grade]? = nil) {
        self.grades = grades
        self.filteredGrades = filteredGrades ?? grades
    }

    func loadAll(context: ModelContext) async {
        loadAllCalledCount += 1
    }

    func reloadFromSwiftData() async {
        reloadFromSwiftDataCalledCount += 1
    }

    @discardableResult
    func migrateInlineImagesIfNeeded() -> Int {
        migrateInlineImagesCalledCount += 1
        return 0
    }

    func add(_ grade: Grade) {
        addCalledCount += 1
        lastAddedGrade = grade
        grades.insert(grade, at: 0)
        filteredGrades.insert(grade, at: 0)
    }

    func add(_ newGrades: [Grade]) {
        addCalledCount += 1
        if let first = newGrades.first {
            lastAddedGrade = first
        }
        grades.insert(contentsOf: newGrades, at: 0)
        filteredGrades.insert(contentsOf: newGrades, at: 0)
    }

    func update(_ grade: Grade) {
        updateCalledCount += 1
        lastUpdatedGrade = grade
        if let idx = grades.firstIndex(where: { $0.id == grade.id }) {
            grades[idx] = grade
        }
        if let idx = filteredGrades.firstIndex(where: { $0.id == grade.id }) {
            filteredGrades[idx] = grade
        }
    }

    func delete(_ grade: Grade) {
        deleteCalledCount += 1
        lastDeletedGrade = grade
        grades.removeAll { $0.id == grade.id }
        filteredGrades.removeAll { $0.id == grade.id }
    }

    func clearAll() -> Int {
        clearAllCalledCount += 1
        let count = grades.count
        grades.removeAll()
        filteredGrades.removeAll()
        return count
    }
}
