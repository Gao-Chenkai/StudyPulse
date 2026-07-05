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
/// 负责 [StudyPhase] 增删改查、active phase 切换、跨域 phaseId 归类 / 清理。
@MainActor
protocol PhaseRepository: AnyObject, Sendable {
    var phases: [StudyPhase] { get }

    /// 当前激活的 phase(镜像 AppEnvironmentManager.preferences.activePhaseId)
    var activePhase: StudyPhase? { get }
    /// 是否启用 phase 过滤(activePhaseId 非空)
    var phaseFilterEnabled: Bool { get }

    /// 是否有未归类数据(任一域 phaseId == nil)
    var hasUnassignedData: Bool { get }
    /// 未归类(phaseId == nil)的总记录数
    var unassignedRecordCount: Int { get }

    // MARK: - Lifecycle
    func loadAll(context: ModelContext) async

    // MARK: - CRUD
    func add(_ phase: StudyPhase)
    func update(_ phase: StudyPhase)
    func delete(_ phase: StudyPhase)
    func setArchived(_ phase: StudyPhase, archived: Bool)
    func activate(_ phase: StudyPhase?)

    // MARK: - 跨域 phaseId 工具
    /// 把所有未归类(phaseId == nil)的数据归入指定 phase
    func assignUnassignedDataToPhase(_ phaseId: UUID) -> (grades: Int, mistakes: Int, exams: Int, comprehensiveExams: Int, tasks: Int)
    /// 把所有引用指定 phaseId 的数据置为 nil(删除 phase 时调用)
    func clearPhaseReferences(phaseId: UUID)
}
