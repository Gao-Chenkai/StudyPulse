//
//  RoutineRepository.swift
//  StudyPulse
//
//  例程 (Routine) 域 Repository 协议。
//  Routine domain repository protocol.
//

import Foundation
import SwiftData

/// 例程模板 Repository 协议。
/// Routine template repository protocol.
/// 负责 Routine (周计划模板) 的增删改查、SwiftData 持久化。
/// Owns `Routine` (weekly template) CRUD and SwiftData persistence.
@MainActor
protocol RoutineRepository: AnyObject, Sendable {
    /// 所有例程模板(包含禁用)
    /// All routine templates (including disabled).
    var routines: [Routine] { get }
    /// 仅启用的例程
    /// Enabled routines only.
    var enabledRoutines: [Routine] { get }
    /// 按 active phase 过滤后的例程
    /// Routines filtered by the active phase.
    var filteredRoutines: [Routine] { get }

    // MARK: - Lifecycle
    // MARK: - 生命周期 / Lifecycle

    /// 加载全部例程
    /// Load all routines.
    func loadAll(context: ModelContext) async

    // MARK: - CRUD
    // MARK: - 增删改查 / CRUD

    /// 新增
    /// Add.
    func add(_ routine: Routine)
    /// 批量新增
    /// Batch add.
    func add(_ routines: [Routine])
    /// 更新
    /// Update.
    func update(_ routine: Routine)
    /// 按 id 删除
    /// Delete by id.
    func delete(_ id: UUID)
    /// 启用 / 禁用
    /// Enable or disable a routine.
    func setEnabled(_ id: UUID, enabled: Bool)
    /// 清空所有
    /// Clear all.
    func clearAll() -> Int
}
