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
/// 负责 Routine (周计划模板) 的增删改查、SwiftData 持久化。
@MainActor
protocol RoutineRepository: AnyObject, Sendable {
    /// 所有例程模板(包含禁用)
    var routines: [Routine] { get }
    /// 仅启用的例程
    var enabledRoutines: [Routine] { get }
    /// 按 active phase 过滤后的例程
    var filteredRoutines: [Routine] { get }

    // MARK: - Lifecycle
    func loadAll(context: ModelContext) async

    // MARK: - CRUD
    func add(_ routine: Routine)
    func add(_ routines: [Routine])
    func update(_ routine: Routine)
    func delete(_ id: UUID)
    func setEnabled(_ id: UUID, enabled: Bool)
    func clearAll() -> Int
}
