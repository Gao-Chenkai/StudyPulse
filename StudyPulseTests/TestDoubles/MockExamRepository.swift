//
//  MockExamRepository.swift
//  StudyPulseTests
//
//  ExamRepository 的纯内存 Mock 测试替身。
//  In-memory mock implementation of ExamRepository for unit tests.
//

import Foundation
import SwiftData
@testable import StudyPulse

@MainActor
final class MockExamRepository: ExamRepository, @unchecked Sendable {
    var examSets: [Exam] = []
    var comprehensiveExamSets: [comprehensiveExam] = []
    var filteredExamSets: [Exam] = []
    var filteredComprehensiveExamSets: [comprehensiveExam] = []

    // MARK: - 调用状态追踪

    var loadAllCalledCount = 0
    var addCalledCount = 0
    var updateExamCalledCount = 0
    var updateComprehensiveExamCalledCount = 0
    var deleteExamCalledCount = 0
    var deleteComprehensiveExamCalledCount = 0
    var clearAllCalledCount = 0
    var updateExamReviewCalledCount = 0
    var toggleChecklistItemCalledCount = 0
    var setChecklistCalledCount = 0

    init(
        exams: [Exam] = [],
        comprehensiveExams: [comprehensiveExam] = [],
        filteredExams: [Exam]? = nil,
        filteredComprehensiveExams: [comprehensiveExam]? = nil
    ) {
        self.examSets = exams
        self.comprehensiveExamSets = comprehensiveExams
        self.filteredExamSets = filteredExams ?? exams
        self.filteredComprehensiveExamSets = filteredComprehensiveExams ?? comprehensiveExams
    }

    func loadAll(context: ModelContext) async {
        loadAllCalledCount += 1
    }

    func add(single: [Exam], comprehensive: [comprehensiveExam]) {
        addCalledCount += 1
        examSets.append(contentsOf: single)
        filteredExamSets.append(contentsOf: single)
        comprehensiveExamSets.append(contentsOf: comprehensive)
        filteredComprehensiveExamSets.append(contentsOf: comprehensive)
    }

    func updateExam(_ exam: Exam) {
        updateExamCalledCount += 1
        if let idx = examSets.firstIndex(where: { $0.id == exam.id }) {
            examSets[idx] = exam
        } else {
            examSets.append(exam)
        }
        if let idx = filteredExamSets.firstIndex(where: { $0.id == exam.id }) {
            filteredExamSets[idx] = exam
        } else {
            filteredExamSets.append(exam)
        }
    }

    func updateComprehensiveExam(_ exam: comprehensiveExam) {
        updateComprehensiveExamCalledCount += 1
        if let idx = comprehensiveExamSets.firstIndex(where: { $0.id == exam.id }) {
            comprehensiveExamSets[idx] = exam
        } else {
            comprehensiveExamSets.append(exam)
        }
        if let idx = filteredComprehensiveExamSets.firstIndex(where: { $0.id == exam.id }) {
            filteredComprehensiveExamSets[idx] = exam
        } else {
            filteredComprehensiveExamSets.append(exam)
        }
    }

    func deleteExam(_ exam: Exam) {
        deleteExamCalledCount += 1
        examSets.removeAll { $0.id == exam.id }
        filteredExamSets.removeAll { $0.id == exam.id }
    }

    func deleteComprehensiveExam(_ exam: comprehensiveExam) {
        deleteComprehensiveExamCalledCount += 1
        comprehensiveExamSets.removeAll { $0.id == exam.id }
        filteredComprehensiveExamSets.removeAll { $0.id == exam.id }
    }

    func clearAll() -> Int {
        clearAllCalledCount += 1
        let count = examSets.count + comprehensiveExamSets.count
        examSets.removeAll()
        comprehensiveExamSets.removeAll()
        filteredExamSets.removeAll()
        filteredComprehensiveExamSets.removeAll()
        return count
    }

    func updateExamReview(_ examId: UUID, review: ExamReview?) {
        updateExamReviewCalledCount += 1
        if let idx = examSets.firstIndex(where: { $0.id == examId }) {
            examSets[idx].examReview = review
        }
        if let idx = filteredExamSets.firstIndex(where: { $0.id == examId }) {
            filteredExamSets[idx].examReview = review
        }
    }

    func toggleChecklistItem(_ examId: UUID, itemId: UUID) {
        toggleChecklistItemCalledCount += 1
        if let idx = examSets.firstIndex(where: { $0.id == examId }) {
            if let itemIdx = examSets[idx].checklist.firstIndex(where: { $0.id == itemId }) {
                examSets[idx].checklist[itemIdx].isChecked.toggle()
            }
        }
        if let idx = filteredExamSets.firstIndex(where: { $0.id == examId }) {
            if let itemIdx = filteredExamSets[idx].checklist.firstIndex(where: { $0.id == itemId }) {
                filteredExamSets[idx].checklist[itemIdx].isChecked.toggle()
            }
        }
    }

    func setChecklist(_ examId: UUID, items: [ExamChecklistItem]) {
        setChecklistCalledCount += 1
        if let idx = examSets.firstIndex(where: { $0.id == examId }) {
            examSets[idx].checklist = items
        }
        if let idx = filteredExamSets.firstIndex(where: { $0.id == examId }) {
            filteredExamSets[idx].checklist = items
        }
    }
}
