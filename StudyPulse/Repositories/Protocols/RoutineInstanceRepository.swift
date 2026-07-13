//
//  RoutineInstanceRepository.swift
//  StudyPulse
//
//  例程实例 (RoutineInstance) 域 Repository 协议。
//  Routine instance (spawned concrete block for a specific day) repository.
//

import Foundation
import SwiftData

/// 例程实例 Repository 协议。
/// Routine instance repository protocol.
/// 负责 RoutineInstance 的增删改查、幂等 spawn、按日期查询。
/// Owns `RoutineInstance` CRUD, idempotent spawn, and date-based queries.
@MainActor
protocol RoutineInstanceRepository: AnyObject, Sendable {
    /// 所有实例(不限日期,按时间倒序)
    /// All instances (any date), sorted by time desc.
    var allInstances: [RoutineInstance] { get }
    /// 今日实例(本地时区当日)
    /// Today's instances (local time-zone same-day).
    var todayInstances: [RoutineInstance] { get }
    /// 正在进行的实例(当前时间在 [startTime, endTime) 窗口内)
    /// Currently active instances (now in [startTime, endTime) window).
    var activeInstances: [RoutineInstance] { get }

    // MARK: - Lifecycle
    // MARK: - 生命周期 / Lifecycle

    /// 加载全部实例
    /// Load all instances.
    func loadAll(context: ModelContext) async

    // MARK: - CRUD
    // MARK: - 增删改查 / CRUD

    /// 幂等:若已存在同 (routineId, dateKey) 的 instance 则不重复插入
    /// Idempotent: do not insert if an instance with the same (routineId, dateKey) exists.
    @discardableResult
    func spawnIfMissing(_ instance: RoutineInstance) -> Bool
    /// 更新
    /// Update an instance.
    func update(_ instance: RoutineInstance)
    /// 设置完成态
    /// Set completion state.
    func setCompletion(_ id: UUID, isCompleted: Bool)
    /// 按 id 删除
    /// Delete by id.
    func delete(_ id: UUID)
    /// 清理 30 天前的过期 instance
    /// Purge instances older than `days` days.
    @discardableResult
    func cleanupStale(olderThanDays days: Int) -> Int
}
