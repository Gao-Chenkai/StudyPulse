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
/// Exam repository protocol.
/// 涵盖单科考试(Exam)和综合考试(comprehensiveExam)两类;都共享 phase 过滤 + 复盘 / 通知 hook。
/// Covers both `Exam` (single-subject) and `comprehensiveExam`; they share
/// phase filtering and review / notification hooks.
@MainActor
protocol ExamRepository: AnyObject, Sendable {
    /// 全部单科考试
    /// All single-subject exams.
    var examSets: [Exam] { get }
    /// 全部综合考试
    /// All comprehensive exams.
    var comprehensiveExamSets: [comprehensiveExam] { get }
    /// 按 active phase 过滤后的单科考试
    /// Single-subject exams filtered by the active phase.
    var filteredExamSets: [Exam] { get }
    /// 按 active phase 过滤后的综合考试
    /// Comprehensive exams filtered by the active phase.
    var filteredComprehensiveExamSets: [comprehensiveExam] { get }

    // MARK: - Lifecycle
    // MARK: - 生命周期 / Lifecycle

    /// 加载所有考试到内存
    /// Load all exams into memory.
    func loadAll(context: ModelContext) async

    // MARK: - CRUD
    // MARK: - 增删改查 / CRUD

    /// 批量新增(import 用);会按 active phase 补全 nil phaseId
    /// Batch add (import); fills `nil` phaseId with the active phase.
    func add(single: [Exam], comprehensive: [comprehensiveExam])
    /// 更新单科考试(按 id 匹配,未找到则插入)
    /// Update a single-subject exam (matched by id; insert if not found).
    func updateExam(_ exam: Exam)
    /// 更新综合考试(按 id 匹配,未找到则插入)
    /// Update a comprehensive exam (matched by id; insert if not found).
    func updateComprehensiveExam(_ exam: comprehensiveExam)
    /// 删除单科考试
    /// Delete a single-subject exam.
    func deleteExam(_ exam: Exam)
    /// 删除综合考试
    /// Delete a comprehensive exam.
    func deleteComprehensiveExam(_ exam: comprehensiveExam)
    /// 清空所有考试(单科 + 综合)
    /// Clear all exams (single + comprehensive).
    @discardableResult
    func clearAll() -> Int

    // MARK: - 复盘 & Checklist
    // MARK: - 复盘 & 清单 / Review & Checklist

    /// 更新或清除一场考试的复盘
    /// Update or clear the post-exam review for one exam.
    func updateExamReview(_ examId: UUID, review: ExamReview?)
    /// 勾选 / 取消某条 checklist
    /// Toggle one checklist item.
    func toggleChecklistItem(_ examId: UUID, itemId: UUID)
    /// 整盘替换 checklist
    /// Replace the whole checklist.
    func setChecklist(_ examId: UUID, items: [ExamChecklistItem])
}
