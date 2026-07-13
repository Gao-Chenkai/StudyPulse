//
//  PhaseRepository.swift
//  StudyPulse
//
//  学习阶段 (StudyPhase) 域 Repository 协议。
//  Study phase (semester / holiday) domain repository protocol.
//

import Foundation
import SwiftData

/// 学习阶段 Repository 协议。
/// Phase repository protocol.
/// 负责 [StudyPhase] 增删改查、active phase 切换、跨域 phaseId 归类 / 清理。
/// Owns [StudyPhase] CRUD, active-phase switching, and cross-domain
/// phaseId reassignment / clearing.
@MainActor
protocol PhaseRepository: AnyObject, Sendable {
    /// 全部阶段
    /// All phases.
    var phases: [StudyPhase] { get }

    /// 当前激活的 phase(镜像 AppEnvironmentManager.preferences.activePhaseId)
    /// Currently active phase (mirrors `AppEnvironmentManager.preferences.activePhaseId`).
    var activePhase: StudyPhase? { get }
    /// 是否启用 phase 过滤(activePhaseId 非空)
    /// Whether phase filtering is on (activePhaseId non-nil).
    var phaseFilterEnabled: Bool { get }

    /// 是否有未归类数据(任一域 phaseId == nil)
    /// Whether any domain has records with phaseId == nil.
    var hasUnassignedData: Bool { get }
    /// 未归类(phaseId == nil)的总记录数
    /// Total records across all domains with phaseId == nil.
    var unassignedRecordCount: Int { get }

    // MARK: - Lifecycle
    // MARK: - 生命周期 / Lifecycle

    /// 加载所有阶段
    /// Load all phases.
    func loadAll(context: ModelContext) async

    // MARK: - CRUD
    // MARK: - 增删改查 / CRUD

    /// 新增
    /// Add a phase.
    func add(_ phase: StudyPhase)
    /// 更新
    /// Update a phase.
    func update(_ phase: StudyPhase)
    /// 删除
    /// Delete a phase.
    func delete(_ phase: StudyPhase)
    /// 归档 / 取消归档
    /// Archive or un-archive a phase.
    func setArchived(_ phase: StudyPhase, archived: Bool)
    /// 设为当前激活 phase（nil = 关闭 phase 过滤）
    /// Set the active phase (nil = turn phase filtering off).
    func activate(_ phase: StudyPhase?)

    // MARK: - 跨域 phaseId 工具
    // MARK: - 跨域 phaseId 工具 / Cross-domain phaseId helpers

    /// 把所有未归类(phaseId == nil)的数据归入指定 phase
    /// Assign all unassigned (phaseId == nil) records to the given phase.
    func assignUnassignedDataToPhase(_ phaseId: UUID) -> (grades: Int, mistakes: Int, exams: Int, comprehensiveExams: Int, tasks: Int)
    /// 把所有引用指定 phaseId 的数据置为 nil(删除 phase 时调用)
    /// Set `phaseId` to `nil` for all records pointing to this phase
    /// (called when deleting a phase).
    func clearPhaseReferences(phaseId: UUID)
}
