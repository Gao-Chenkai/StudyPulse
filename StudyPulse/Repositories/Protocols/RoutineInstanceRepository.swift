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
/// 负责 RoutineInstance 的增删改查、幂等 spawn、按日期查询。
@MainActor
protocol RoutineInstanceRepository: AnyObject, Sendable {
    /// 所有实例(不限日期,按时间倒序)
    var allInstances: [RoutineInstance] { get }
    /// 今日实例(本地时区当日)
    var todayInstances: [RoutineInstance] { get }
    /// 正在进行的实例(当前时间在 [startTime, endTime) 窗口内)
    var activeInstances: [RoutineInstance] { get }

    // MARK: - Lifecycle
    func loadAll(context: ModelContext) async

    // MARK: - CRUD
    /// 幂等:若已存在同 (routineId, dateKey) 的 instance 则不重复插入
    @discardableResult
    func spawnIfMissing(_ instance: RoutineInstance) -> Bool
    func update(_ instance: RoutineInstance)
    func setCompletion(_ id: UUID, isCompleted: Bool)
    func delete(_ id: UUID)
    /// 清理 30 天前的过期 instance
    @discardableResult
    func cleanupStale(olderThanDays days: Int) -> Int
}
