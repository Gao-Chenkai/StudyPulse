//
//  PhaseFilterRefresher.swift
//  StudyPulse
//
//  阶段过滤刷新:phase 切换时触发 5 个 filtered 缓存重算。
//  - 启动 polling(每 0.5s 检查 active phase 变化),触发 filtered 缓存重算
//  - 提供手动重算入口
//
//  从原 `RepositoryContainer.recomputeAllFiltered` + `observeActivePhaseChanges` 拆出
//  (Phase 3, 2026-07-14)。
//

import Foundation
import os

/// 阶段过滤刷新器
/// Phase filter refresher.
///
/// `RepositoryContainer` 通过 `phaseRefresher` 字段持有实例,保持调用方式不变。
@MainActor
final class PhaseFilterRefresher {
    private let gradeRepo: any GradeRepository
    private let mistakeRepo: any MistakeRepository
    private let examRepo: any ExamRepository
    private let taskRepo: any TaskRepository
    private let routineRepo: any RoutineRepository
    private let routineInstanceRepo: any RoutineInstanceRepository

    @ObservationIgnored
    private var observerTask: Task<Void, Never>?

    init(
        gradeRepo: any GradeRepository,
        mistakeRepo: any MistakeRepository,
        examRepo: any ExamRepository,
        taskRepo: any TaskRepository,
        routineRepo: any RoutineRepository,
        routineInstanceRepo: any RoutineInstanceRepository
    ) {
        self.gradeRepo = gradeRepo
        self.mistakeRepo = mistakeRepo
        self.examRepo = examRepo
        self.taskRepo = taskRepo
        self.routineRepo = routineRepo
        self.routineInstanceRepo = routineInstanceRepo
    }

    /// 启动 active phase 变化监听(通常在 asyncInit 后调用一次)
    /// Start active phase change observation (typically called once after asyncInit).
    ///
    /// 用 polling(每 0.5s 检查)而非 Combine 桥接,避免引入 Combine 依赖。
    func startObserving() {
        observerTask?.cancel()
        observerTask = Task { @MainActor [weak self] in
            var lastId: UUID? = AppEnvironmentManager.shared.activePhaseId
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                let currentId = AppEnvironmentManager.shared.activePhaseId
                if currentId != lastId {
                    lastId = currentId
                    self?.recomputeAll()
                }
            }
        }
    }

    /// 停止监听(container 销毁时调用)
    func stopObserving() {
        observerTask?.cancel()
        observerTask = nil
    }

    /// 5 个数据域的 filtered 缓存重算(phase 切换时用)
    /// Recompute the 5 filtered caches (called on phase switch).
    func recomputeAll() {
        if let g = gradeRepo as? DefaultGradeRepository { g.recomputeFiltered() }
        if let m = mistakeRepo as? DefaultMistakeRepository { m.recomputeFiltered() }
        if let e = examRepo as? DefaultExamRepository { e.recomputeFiltered() }
        if let t = taskRepo as? DefaultTaskRepository { t.recomputeFiltered() }
        if let r = routineRepo as? DefaultRoutineRepository { r.recomputeFiltered() }
        if let ri = routineInstanceRepo as? DefaultRoutineInstanceRepository { ri.recomputeDerived() }
        Log.data.debug("PhaseFilterRefresher recomputeAll")
    }
}
