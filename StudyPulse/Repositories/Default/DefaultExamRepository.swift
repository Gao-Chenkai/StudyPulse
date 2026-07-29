//
//  DefaultExamRepository.swift
//  StudyPulse
//

import Foundation
import SwiftData
import os

@Observable @MainActor
final class DefaultExamRepository: ExamRepository, PersistenceExecutorBacked {
    var examSets: [Exam] = []
    var comprehensiveExamSets: [comprehensiveExam] = []
    var filteredExamSets: [Exam] = []
    var filteredComprehensiveExamSets: [comprehensiveExam] = []

    @ObservationIgnored private let envManager: AppEnvironmentManager
    @ObservationIgnored private var executor: PersistenceExecutor?
    @ObservationIgnored private var persistenceTail: Task<Void, Never>?

    init(envManager: AppEnvironmentManager) {
        self.envManager = envManager
    }

    func attachPersistenceExecutor(_ executor: PersistenceExecutor) {
        self.executor = executor
    }

    func loadAll(context: ModelContext) async {
        if executor == nil {
            executor = PersistenceExecutor(modelContainer: context.container)
        }
        guard let executor else { return }
        await persistenceTail?.value
        do {
            async let single = executor.fetchExams()
            async let comprehensive = executor.fetchComprehensiveExams()
            async let filteredSingle = executor.fetchExams(activePhaseID: envManager.activePhaseId)
            async let filteredComprehensive = executor.fetchComprehensiveExams(activePhaseID: envManager.activePhaseId)
            publish(
                single: try await single,
                filteredSingle: try await filteredSingle,
                comprehensive: try await comprehensive,
                filteredComprehensive: try await filteredComprehensive
            )
        } catch is CancellationError {
            Log.data.debug("ExamRepository load cancelled")
        } catch {
            Log.data.error("ExamRepository load failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func publishStartupSnapshots(
        single: [Exam],
        comprehensive: [comprehensiveExam]
    ) {
        publish(
            single: single,
            filteredSingle: single,
            comprehensive: comprehensive,
            filteredComprehensive: comprehensive
        )
    }

    func publishStartupSnapshots(
        single: [Exam],
        filteredSingle: [Exam],
        comprehensive: [comprehensiveExam],
        filteredComprehensive: [comprehensiveExam]
    ) {
        publish(
            single: single,
            filteredSingle: filteredSingle,
            comprehensive: comprehensive,
            filteredComprehensive: filteredComprehensive
        )
    }

    func add(single: [Exam], comprehensive: [comprehensiveExam]) {
        guard !single.isEmpty || !comprehensive.isEmpty else { return }
        let activeID = envManager.activePhaseId
        let storedSingle = single.map { exam in
            var value = exam
            if value.phaseId == nil { value.phaseId = activeID }
            return value
        }
        let storedComprehensive = comprehensive.map { exam in
            var value = exam
            if value.phaseId == nil { value.phaseId = activeID }
            return value
        }
        enqueue { executor in
            try await executor.insertExams(
                single: storedSingle,
                comprehensive: storedComprehensive
            )
            await self.publishFromPersistence(
                single: (self.examSets + storedSingle).sorted { $0.examDate > $1.examDate },
                comprehensive: (self.comprehensiveExamSets + storedComprehensive)
                    .sorted { $0.examDate > $1.examDate },
                executor: executor
            )
            for exam in storedSingle {
                ExamReviewNotifications.shared.schedule(for: exam)
            }
        }
    }

    func updateExam(_ exam: Exam) {
        enqueue { executor in
            try await executor.upsertExam(exam)
            var next = self.examSets
            if let index = next.firstIndex(where: { $0.id == exam.id }) {
                next[index] = exam
            } else {
                next.append(exam)
            }
            await self.publishFromPersistence(
                single: next.sorted { $0.examDate > $1.examDate },
                comprehensive: self.comprehensiveExamSets,
                executor: executor
            )
            ExamReviewNotifications.shared.schedule(for: exam)
        }
    }

    func updateComprehensiveExam(_ exam: comprehensiveExam) {
        enqueue { executor in
            try await executor.upsertComprehensiveExam(exam)
            var next = self.comprehensiveExamSets
            if let index = next.firstIndex(where: { $0.id == exam.id }) {
                next[index] = exam
            } else {
                next.append(exam)
            }
            await self.publishFromPersistence(
                single: self.examSets,
                comprehensive: next.sorted { $0.examDate > $1.examDate },
                executor: executor
            )
        }
    }

    func deleteExam(_ exam: Exam) {
        enqueue { executor in
            try await executor.deleteExam(id: exam.id)
            ExamReviewNotifications.shared.cancel(for: exam.id)
            await self.publishFromPersistence(
                single: self.examSets.filter { $0.id != exam.id },
                comprehensive: self.comprehensiveExamSets,
                executor: executor
            )
        }
    }

    func deleteComprehensiveExam(_ exam: comprehensiveExam) {
        enqueue { executor in
            try await executor.deleteComprehensiveExam(id: exam.id)
            await self.publishFromPersistence(
                single: self.examSets,
                comprehensive: self.comprehensiveExamSets.filter { $0.id != exam.id },
                executor: executor
            )
        }
    }

    @discardableResult
    func clearAll() -> Int {
        let expectedCount = examSets.count + comprehensiveExamSets.count
        let ids = examSets.map(\.id)
        enqueue { executor in
            _ = try await executor.deleteAllExams()
            for id in ids {
                ExamReviewNotifications.shared.cancel(for: id)
            }
        self.publish(
            single: [],
            filteredSingle: [],
            comprehensive: [],
            filteredComprehensive: []
        )
        }
        return expectedCount
    }

    func updateExamReview(_ examId: UUID, review: ExamReview?) {
        guard var exam = examSets.first(where: { $0.id == examId }) else { return }
        exam.examReview = review
        updateExam(exam)
        if review != nil {
            ExamReviewNotifications.shared.cancel(for: examId)
        }
    }

    func toggleChecklistItem(_ examId: UUID, itemId: UUID) {
        guard var exam = examSets.first(where: { $0.id == examId }),
              let index = exam.checklist.firstIndex(where: { $0.id == itemId }) else { return }
        exam.checklist[index].isChecked.toggle()
        updateExam(exam)
    }

    func setChecklist(_ examId: UUID, items: [ExamChecklistItem]) {
        guard var exam = examSets.first(where: { $0.id == examId }) else { return }
        exam.checklist = items
        updateExam(exam)
    }

    func reloadFilteredFromSwiftData() async {
        guard let executor else { return }
        do {
            async let single = executor.fetchExams(activePhaseID: envManager.activePhaseId)
            async let comprehensive = executor.fetchComprehensiveExams(activePhaseID: envManager.activePhaseId)
            filteredExamSets = try await single
            filteredComprehensiveExamSets = try await comprehensive
        } catch is CancellationError {
            Log.data.debug("ExamRepository filtered load cancelled")
        } catch {
            Log.data.error("ExamRepository filtered load failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func flushPendingPersistence() async {
        await persistenceTail?.value
    }

    func cancelPendingPersistence() {
        persistenceTail?.cancel()
        persistenceTail = nil
    }

    private func publish(
        single: [Exam],
        filteredSingle: [Exam],
        comprehensive: [comprehensiveExam],
        filteredComprehensive: [comprehensiveExam]
    ) {
        examSets = single
        comprehensiveExamSets = comprehensive
        filteredExamSets = filteredSingle
        filteredComprehensiveExamSets = filteredComprehensive
    }

    private func publishFromPersistence(
        single: [Exam],
        comprehensive: [comprehensiveExam],
        executor: PersistenceExecutor
    ) async {
        do {
            async let filteredSingle = executor.fetchExams(activePhaseID: envManager.activePhaseId)
            async let filteredComprehensive = executor.fetchComprehensiveExams(activePhaseID: envManager.activePhaseId)
            publish(
                single: single,
                filteredSingle: try await filteredSingle,
                comprehensive: comprehensive,
                filteredComprehensive: try await filteredComprehensive
            )
        } catch is CancellationError {
            Log.data.debug("ExamRepository filtered refresh cancelled")
        } catch {
            Log.data.error("ExamRepository filtered refresh failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func enqueue(
        _ operation: @escaping @MainActor @Sendable (PersistenceExecutor) async throws -> Void
    ) {
        guard let executor else {
            Log.data.error("ExamRepository persistence executor is not attached")
            return
        }
        let predecessor = persistenceTail
        persistenceTail = Task {
            await predecessor?.value
            guard !Task.isCancelled else { return }
            do {
                try await operation(executor)
            } catch is CancellationError {
                Log.data.debug("ExamRepository mutation cancelled")
            } catch {
                Log.data.error("ExamRepository mutation failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
