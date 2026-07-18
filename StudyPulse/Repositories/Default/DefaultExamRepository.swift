//
//  DefaultExamRepository.swift
//  StudyPulse
//
//  考试 (单科 + 综合) Repository 默认实现。
//  Default ExamRepository implementation backed by SwiftData.
//

import Foundation
import SwiftData
import os

/// 考试 (单科 + 综合) Repository 默认实现。
/// Default ExamRepository implementation backed by SwiftData.
@Observable @MainActor
final class DefaultExamRepository: ExamRepository {
    /// 全部单科考试
    /// All single-subject exams.
    var examSets: [Exam] = []
    /// 全部综合考试
    /// All comprehensive exams.
    var comprehensiveExamSets: [comprehensiveExam] = []
    /// 按当前激活 phase 过滤后的单科考试
    /// Single-subject exams filtered by the active phase.
    var filteredExamSets: [Exam] = []
    /// 按当前激活 phase 过滤后的综合考试
    /// Comprehensive exams filtered by the active phase.
    var filteredComprehensiveExamSets: [comprehensiveExam] = []

    /// SwiftData ModelContext（容器在 init 时注入）
    /// SwiftData ModelContext (injected by the container on init).
    @ObservationIgnored
    private var modelContext: ModelContext?

    /// 用于 background fetch 的容器引用(Sendable)
    /// Container reference for background fetches (Sendable).
    @ObservationIgnored
    private var modelContainer: ModelContainer?

    /// AppEnvironmentManager(由容器注入,用于读 activePhaseId)
    /// AppEnvironmentManager (injected by the container; used to read `activePhaseId`).
    @ObservationIgnored
    private let envManager: AppEnvironmentManager

    init(envManager: AppEnvironmentManager) {
        self.envManager = envManager
    }

    // MARK: - Lifecycle
    // MARK: - 生命周期 / Lifecycle

    /// 加载所有考试到内存
    /// Load all exams into memory.
    func loadAll(context: ModelContext) async {
        self.modelContext = context
        self.modelContainer = context.container
        guard let container = modelContainer else { return }
        // detached Task 内创建独立 background ModelContext,两个 fetch 共用一个 ctx
        // Use one independent background ModelContext for both fetches.
        let snapshots: (exams: [Exam], comp: [comprehensiveExam]) = await Task.detached(priority: .utility) {
            let ctx = ModelContext(container)
            // fetchLimit=200 + sort by examDate desc:取最近 200 场考试(覆盖未来 + 近期已过)。
            // fetchLimit=200 + sort by examDate desc: take the most recent 200 exams
            // (covers upcoming + recently past).
            var examDescriptor = FetchDescriptor<ExamRecord>(
                sortBy: [SortDescriptor(\.examDate, order: .reverse)]
            )
            examDescriptor.fetchLimit = 200
            var compDescriptor = FetchDescriptor<ComprehensiveExamRecord>(
                sortBy: [SortDescriptor(\.examDate, order: .reverse)]
            )
            compDescriptor.fetchLimit = 200
            let examEntities = (try? ctx.fetch(examDescriptor)) ?? []
            let compEntities = (try? ctx.fetch(compDescriptor)) ?? []
            return (exams: examEntities.map { $0.toSnapshot() }, comp: compEntities.map { $0.toSnapshot() })
        }.value
        // 回到 MainActor 赋值
        self.examSets = snapshots.exams
        self.comprehensiveExamSets = snapshots.comp
        recomputeFiltered()
    }

    // MARK: - CRUD
    // MARK: - 增删改查 / CRUD

    /// 批量新增考试
    /// Batch add exams.
    func add(single: [Exam], comprehensive: [comprehensiveExam]) {
        let activeId = envManager.activePhaseId
        let storedSingle: [Exam] = single.map { e in
            var s = e
            if s.phaseId == nil { s.phaseId = activeId }
            return s
        }
        let storedComp: [comprehensiveExam] = comprehensive.map { e in
            var s = e
            if s.phaseId == nil { s.phaseId = activeId }
            return s
        }
        if let context = modelContext {
            for e in storedSingle { context.insert(ExamRecord(from: e)) }
            for e in storedComp { context.insert(ComprehensiveExamRecord(from: e)) }
            try? context.save()
        }
        examSets.append(contentsOf: storedSingle)
        comprehensiveExamSets.append(contentsOf: storedComp)
        for e in storedSingle {
            ExamReviewNotifications.shared.schedule(for: e)
        }
        Log.data.info("ExamRepository batch added: single=\(storedSingle.count, privacy: .public) comprehensive=\(storedComp.count, privacy: .public)")
        Log.record(.info, category: "Data", message: "ExamRepository batch added: single=\(storedSingle.count) comprehensive=\(storedComp.count)")
        recomputeFiltered()
    }

    func updateExam(_ exam: Exam) {
        if let index = examSets.firstIndex(where: { $0.id == exam.id }) {
            examSets[index] = exam
        }
        guard let context = modelContext else { return }
        do {
            if let entity = try context.fetch(
                FetchDescriptor<ExamRecord>(predicate: #Predicate { $0.id == exam.id })
            ).first {
                entity.name = exam.name
                entity.examDate = exam.examDate
                entity.examEndDate = exam.examEndDate
                entity.importance = exam.importance
                entity.subject = exam.subject
                entity.examName = exam.examName
                entity.masteryDegree = exam.masteryDegree
                entity.timeSlotStart = exam.timeSlot?.startTime
                entity.timeSlotEnd = exam.timeSlot?.endTime
                entity.phaseId = exam.phaseId
                entity.checklistData = exam.checklist.isEmpty ? nil : (try? JSONEncoder().encode(exam.checklist))
                entity.locationSchool = exam.locationSchool
                entity.locationClassroom = exam.locationClassroom
                entity.locationSeat = exam.locationSeat
                entity.countdownNotifyDaysData = {
                    if let days = exam.countdownNotifyDays {
                        return (try? JSONEncoder().encode(days)) ?? nil
                    }
                    return nil
                }()
                entity.reviewData = exam.examReview.flatMap { try? JSONEncoder().encode($0) }
                try context.save()
            } else {
                context.insert(ExamRecord(from: exam))
                try context.save()
            }
        } catch {
            Log.data.error("ExamRepository updateExam failed: \(error.localizedDescription, privacy: .public)")
        }
        Log.data.info("ExamRepository updated: name=\(exam.name, privacy: .public) id=\(exam.id.uuidString, privacy: .public)")
        Log.record(.info, category: "Data", message: "ExamRepository updated: \(exam.name) checklist=\(exam.checklist.count) location.school=\(exam.locationSchool)")
        ExamReviewNotifications.shared.schedule(for: exam)
        recomputeFiltered()
    }

    func updateComprehensiveExam(_ exam: comprehensiveExam) {
        if let index = comprehensiveExamSets.firstIndex(where: { $0.id == exam.id }) {
            comprehensiveExamSets[index] = exam
        }
        guard let context = modelContext else { return }
        do {
            if let entity = try context.fetch(
                FetchDescriptor<ComprehensiveExamRecord>(predicate: #Predicate { $0.id == exam.id })
            ).first {
                entity.name = exam.name
                entity.examDate = exam.examDate
                entity.importance = exam.importance
                entity.phaseId = exam.phaseId
                try context.save()
            } else {
                context.insert(ComprehensiveExamRecord(from: exam))
                try context.save()
            }
        } catch {
            Log.data.error("ExamRepository updateComprehensiveExam failed: \(error.localizedDescription, privacy: .public)")
        }
        recomputeFiltered()
    }

    func deleteExam(_ exam: Exam) {
        removeExamRecord(id: exam.id)
        examSets.removeAll { $0.id == exam.id }
        Log.data.info("ExamRepository deleted exam: id=\(exam.id.uuidString, privacy: .public)")
        recomputeFiltered()
    }

    func deleteComprehensiveExam(_ exam: comprehensiveExam) {
        removeCompExamRecord(id: exam.id)
        comprehensiveExamSets.removeAll { $0.id == exam.id }
        Log.data.info("ExamRepository deleted comprehensive exam: id=\(exam.id.uuidString, privacy: .public)")
        recomputeFiltered()
    }

    @discardableResult
    func clearAll() -> Int {
        guard let context = modelContext else { return 0 }
        let count = examSets.count + comprehensiveExamSets.count
        do {
            let singleEntities = try context.fetch(FetchDescriptor<ExamRecord>())
            for entity in singleEntities { context.delete(entity) }
            let compEntities = try context.fetch(FetchDescriptor<ComprehensiveExamRecord>())
            for entity in compEntities { context.delete(entity) }
            try context.save()
        } catch {
            Log.data.error("ExamRepository clearAll failed: \(error.localizedDescription, privacy: .public)")
            return 0
        }
        examSets.removeAll()
        comprehensiveExamSets.removeAll()
        Log.data.warning("ExamRepository clearAll: count=\(count, privacy: .public)")
        recomputeFiltered()
        return count
    }

    // MARK: - 复盘 & Checklist
    // MARK: - 复盘 & 清单 / Review & Checklist

    /// 更新或清除某场考试的复盘
    /// Update or clear a single exam's review.
    func updateExamReview(_ examId: UUID, review: ExamReview?) {
        guard let index = examSets.firstIndex(where: { $0.id == examId }) else {
            Log.data.warning("ExamRepository updateExamReview: not found id=\(examId.uuidString, privacy: .public)")
            return
        }
        examSets[index].examReview = review
        updateExam(examSets[index])
        if review != nil {
            ExamReviewNotifications.shared.cancel(for: examId)
        } else {
            ExamReviewNotifications.shared.schedule(for: examSets[index])
        }
        Log.data.info("ExamRepository updated review: id=\(examId.uuidString, privacy: .public) hasReview=\(review != nil, privacy: .public)")
    }

    func toggleChecklistItem(_ examId: UUID, itemId: UUID) {
        guard let index = examSets.firstIndex(where: { $0.id == examId }) else { return }
        var exam = examSets[index]
        guard let ci = exam.checklist.firstIndex(where: { $0.id == itemId }) else { return }
        exam.checklist[ci].isChecked.toggle()
        examSets[index] = exam
        updateExam(exam)
    }

    func setChecklist(_ examId: UUID, items: [ExamChecklistItem]) {
        guard let index = examSets.firstIndex(where: { $0.id == examId }) else { return }
        var exam = examSets[index]
        exam.checklist = items
        examSets[index] = exam
        updateExam(exam)
    }

    // MARK: - Internals
    // MARK: - 内部工具 / Internals

    /// 重新计算 filteredExamSets / filteredComprehensiveExamSets
    /// Recompute the filtered exam arrays from the active phase.
    func recomputeFiltered() {
        let activeId = envManager.activePhaseId
        if let id = activeId {
            filteredExamSets = examSets.filter { $0.phaseId == id }
            filteredComprehensiveExamSets = comprehensiveExamSets.filter { $0.phaseId == id }
        } else {
            filteredExamSets = examSets
            filteredComprehensiveExamSets = comprehensiveExamSets
        }
    }

    private func removeExamRecord(id: UUID) {
        guard let context = modelContext else { return }
        do {
            if let entity = try context.fetch(
                FetchDescriptor<ExamRecord>(predicate: #Predicate { $0.id == id })
            ).first {
                context.delete(entity)
                try context.save()
            }
        } catch {
            Log.data.error("ExamRepository removeExamRecord failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func removeCompExamRecord(id: UUID) {
        guard let context = modelContext else { return }
        do {
            if let entity = try context.fetch(
                FetchDescriptor<ComprehensiveExamRecord>(predicate: #Predicate { $0.id == id })
            ).first {
                context.delete(entity)
                try context.save()
            }
        } catch {
            Log.data.error("ExamRepository removeCompExamRecord failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
