//
//  PhaseFilterRefresher.swift
//  StudyPulse
//
//  阶段过滤刷新:phase 切换时触发 5 个 filtered 缓存重算。
//  - 通过 NotificationCenter 监听 `activePhaseDidChange` 通知,事件驱动刷新
//  - 提供手动重算入口
//
//  从原 `RepositoryContainer.recomputeAllFiltered` + `observeActivePhaseChanges` 拆出
//  (Phase 3, 2026-07-14)。
//
//  2026-07-18:把 0.5s polling 改为 NotificationCenter 事件驱动(性能优化 P0-1)。
//

import Foundation
import os
import Combine

extension Notification.Name {
    /// 当前激活的 study phase 切换时 post(`AppEnvironmentManager.setActivePhaseId` 触发)。
    /// Posted when the active study phase changes (triggered by `AppEnvironmentManager.setActivePhaseId`).
    static let activePhaseDidChange = Notification.Name("activePhaseDidChange")

    /// AchievementManager 的 snapshot 被赋值时 post(`AchievementManager.snapshot didSet` 触发)。
    /// PlantManager 监听此通知以替代原 1.5s polling。
    /// Posted whenever `AchievementManager.snapshot` is assigned (via its `didSet`).
    /// PlantManager listens to this notification instead of the old 1.5s polling.
    static let achievementsSnapshotDidChange = Notification.Name("achievementsSnapshotDidChange")
}

/// 阶段过滤刷新器
/// Phase filter refresher.
///
/// `RepositoryContainer` 通过 `phaseRefresher` 字段持有实例,保持调用方式不变。
@MainActor
final class PhaseFilterRefresher {
    private static let signposter = OSSignposter(
        subsystem: Bundle.main.bundleIdentifier ?? "com.chenkai.gao.studypulse",
        category: "PhaseFiltering"
    )
    private let gradeRepo: any GradeRepository
    private let mistakeRepo: any MistakeRepository
    private let examRepo: any ExamRepository
    private let taskRepo: any TaskRepository
    private let routineRepo: any RoutineRepository
    private let routineInstanceRepo: any RoutineInstanceRepository
    private let envManager: AppEnvironmentManager

    @ObservationIgnored
    private var observer: AnyCancellable?

    init(
        gradeRepo: any GradeRepository,
        mistakeRepo: any MistakeRepository,
        examRepo: any ExamRepository,
        taskRepo: any TaskRepository,
        routineRepo: any RoutineRepository,
        routineInstanceRepo: any RoutineInstanceRepository,
        envManager: AppEnvironmentManager
    ) {
        self.gradeRepo = gradeRepo
        self.mistakeRepo = mistakeRepo
        self.examRepo = examRepo
        self.taskRepo = taskRepo
        self.routineRepo = routineRepo
        self.routineInstanceRepo = routineInstanceRepo
        self.envManager = envManager
    }

    /// 启动 active phase 变化监听(通常在 asyncInit 后调用一次)。
    /// Start active phase change observation (typically called once after asyncInit).
    ///
    /// 通过 NotificationCenter 监听 `activePhaseDidChange` 通知,替代原 0.5s polling。
    /// Phase 切换是用户主动操作(每天 < 5 次),事件驱动完全足够。
    func startObserving() {
        observer?.cancel()
        observer = NotificationCenter.default.publisher(for: .activePhaseDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.recomputeAll()
            }
    }

    /// 停止监听(container 销毁时调用)
    func stopObserving() {
        observer?.cancel()
        observer = nil
    }

    /// 5 个数据域的 filtered 缓存重算(phase 切换时用)
    /// Recompute the 5 filtered caches (called on phase switch).
    func recomputeAll() {
        let interval = Self.signposter.beginInterval("recomputeAll")
        defer { Self.signposter.endInterval("recomputeAll", interval) }
        if let g = gradeRepo as? DefaultGradeRepository { g.recomputeFiltered() }
        if let m = mistakeRepo as? DefaultMistakeRepository { m.recomputeFiltered() }
        if let e = examRepo as? DefaultExamRepository { e.recomputeFiltered() }
        if let t = taskRepo as? DefaultTaskRepository { t.recomputeFiltered() }
        if let r = routineRepo as? DefaultRoutineRepository { r.recomputeFiltered() }
        if let ri = routineInstanceRepo as? DefaultRoutineInstanceRepository { ri.recomputeDerived() }
        Log.data.debug("PhaseFilterRefresher recomputeAll")
    }
}
