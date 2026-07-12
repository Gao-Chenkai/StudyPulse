//
//  MockSubjectRepository.swift
//  StudyPulseTests
//
//  SubjectRepository 的纯内存 Mock 测试替身。
//  In-memory mock implementation of SubjectRepository for unit tests.
//

import Foundation
import SwiftData
@testable import StudyPulse

@MainActor
final class MockSubjectRepository: SubjectRepository, @unchecked Sendable {
    var subjects: [Subject] = []

    // MARK: - 调用状态追踪

    var loadAllCalledCount = 0
    var saveSubjectsCalledCount = 0
    var initializeDefaultSubjectsCalledCount = 0
    var applySmartSubjectRecommendationCalledCount = 0

    init(subjects: [Subject] = [
        Subject(name: "Math", displayName: "数学", enabled: true, fullScore: 100),
        Subject(name: "English", displayName: "英语", enabled: true, fullScore: 100),
        Subject(name: "Physics", displayName: "物理", enabled: true, fullScore: 100)
    ]) {
        self.subjects = subjects
    }

    func loadAll(context: ModelContext) async {
        loadAllCalledCount += 1
    }

    func saveSubjects() {
        saveSubjectsCalledCount += 1
    }

    func initializeDefaultSubjects() {
        initializeDefaultSubjectsCalledCount += 1
        if subjects.isEmpty {
            subjects = [
                Subject(name: "Math", displayName: "Math", enabled: true, fullScore: 100),
                Subject(name: "English", displayName: "English", enabled: true, fullScore: 100)
            ]
        }
    }

    func applySmartSubjectRecommendation(stage: EducationStage, regionCode: String) {
        applySmartSubjectRecommendationCalledCount += 1
    }

    func fullScore(for subjectName: String) -> Double {
        if let sub = subjects.first(where: { $0.name.lowercased() == subjectName.lowercased() || $0.displayName.lowercased() == subjectName.lowercased() }) {
            return sub.fullScore
        }
        return 100.0
    }

    func displayName(for subjectName: String) -> String {
        if let sub = subjects.first(where: { $0.name.lowercased() == subjectName.lowercased() }) {
            return sub.displayName
        }
        return subjectName
    }
}
