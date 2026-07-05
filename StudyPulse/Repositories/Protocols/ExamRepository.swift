//
//  ExamRepository.swift
//  StudyPulse
//
//  考试 (单科 Exam + 综合 comprehensiveExam) 域 Repository 协议。
//  Exam (single-subject + comprehensive) domain repository protocol.
//

import Foundation
import SwiftData

/// 考试 Repository 协议。
/// 涵盖单科考试(Exam)和综合考试(comprehensiveExam)两类;都共享 phase 过滤 + 复盘 / 通知 hook。
@MainActor
protocol ExamRepository: AnyObject, Sendable {
    var examSets: [Exam] { get }
    var comprehensiveExamSets: [comprehensiveExam] { get }
    var filteredExamSets: [Exam] { get }
    var filteredComprehensiveExamSets: [comprehensiveExam] { get }

    // MARK: - Lifecycle
    func loadAll(context: ModelContext) async

    // MARK: - CRUD
    /// 批量新增(import 用);会按 active phase 补全 nil phaseId
    func add(single: [Exam], comprehensive: [comprehensiveExam])
    /// 更新单科考试(按 id 匹配,未找到则插入)
    func updateExam(_ exam: Exam)
    /// 更新综合考试(按 id 匹配,未找到则插入)
    func updateComprehensiveExam(_ exam: comprehensiveExam)
    /// 删除单科考试
    func deleteExam(_ exam: Exam)
    /// 删除综合考试
    func deleteComprehensiveExam(_ exam: comprehensiveExam)
    /// 清空所有考试(单科 + 综合)
    @discardableResult
    func clearAll() -> Int

    // MARK: - 复盘 & Checklist
    func updateExamReview(_ examId: UUID, review: ExamReview?)
    func toggleChecklistItem(_ examId: UUID, itemId: UUID)
    func setChecklist(_ examId: UUID, items: [ExamChecklistItem])
}
