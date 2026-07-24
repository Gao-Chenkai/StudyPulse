//
//  RoutineSpawner.swift
//  StudyPulse
//
//  例程物化器。监听 enabled routines,在每日 0:00 + App 启动 + routine 增删时
//  触发 `spawnForToday()`,产生 RoutineInstance。
//
//  幂等保证:instance id = routine.id + yyyyMMdd。
//
//  Created for Plans & Routines spec (2026-07-09).
//

import Foundation
import SwiftUI
import os

@MainActor
@Observable
final class RoutineSpawner {
    // MARK: - 依赖 / Dependencies
    // MARK: - Deps
    @ObservationIgnored private let container: RepositoryContainer
    @ObservationIgnored private let log = Logger(subsystem: "app.StudyPulse", category: "RoutineSpawner")

    // MARK: - 内部状态 / Internal state
    // MARK: - State
    @ObservationIgnored private var lastSpawnedDateKey: String?  // 上次 spawn 的 dateKey,跨日判定
    @ObservationIgnored private var pollTimer: Timer?             // 60s 兜底跨日检测
    @ObservationIgnored private var observationTask: Task<Void, Never>?

    // MARK: - Init

    init(container: RepositoryContainer) {
        self.container = container
        wireObservers()
        startPolling()
    }

    // MARK: - Public API

    /// 在调用时机立刻执行一次 spawn + cleanup
    func runOnce() {
        spawnForToday()
        _ = container.routineInstanceRepo.cleanupStale(olderThanDays: 30)
    }

    /// 同步 spawn 今日所有启用 + weekday 匹配的 routine。
    /// 幂等:同一天内重复调用无副作用。
    @discardableResult
    func spawnForToday(now: Date = Date()) -> Int {
        let todayKey = RoutineInstance.dateKeyString(for: now)
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: now)
        var spawnedCount = 0

        let routines = container.routineRepo.enabledRoutines.filter { r in
            r.enabled && r.weekdays.contains(weekday)
        }
        for routine in routines {
            let candidate = buildCandidate(
                routine: routine,
                date: now,
                calendar: cal
            )
            if container.routineInstanceRepo.spawnIfMissing(candidate) {
                spawnedCount += 1
            }
        }
        lastSpawnedDateKey = todayKey
        if spawnedCount > 0 {
            log.info("RoutineSpawner spawned \(spawnedCount) instances for \(todayKey, privacy: .public)")
            Log.record(.info, category: "Plan", message: "RoutineSpawner spawned \(spawnedCount) for \(todayKey)")
        }
        return spawnedCount
    }

    /// 当 routine 增删 / 启停 / weekdays 改变时,补齐今日缺失的 instance
    @discardableResult
    func reconcileToday() -> Int {
        return spawnForToday()
    }

    /// 跨日期检测:若已跨入新一天,清 lastSpawnedDateKey,重新 spawn
    func checkDateRollover(now: Date = Date()) {
        let key = RoutineInstance.dateKeyString(for: now)
        if let last = lastSpawnedDateKey, last != key {
            log.info("RoutineSpawner date rollover: \(last, privacy: .public) -> \(key, privacy: .public)")
            spawnForToday(now: now)
        }
    }

    // MARK: - Internals

    private func buildCandidate(
        routine: Routine,
        date: Date,
        calendar: Calendar
    ) -> RoutineInstance {
        let dayStart = calendar.startOfDay(for: date)
        // 把 routine.startTime / endTime 的时分部分应用回 today
        let startComps = calendar.dateComponents([.hour, .minute], from: routine.startTime)
        let endComps = calendar.dateComponents([.hour, .minute], from: routine.endTime)
        let start = calendar.date(
            bySettingHour: startComps.hour ?? 0,
            minute: startComps.minute ?? 0,
            second: 0,
            of: dayStart
        ) ?? dayStart
        let end = calendar.date(
            bySettingHour: endComps.hour ?? 0,
            minute: endComps.minute ?? 0,
            second: 0,
            of: dayStart
        ) ?? dayStart

        // 错题数量快照(仅 mistakeReview 类型)
        var spawnedMistakeCount = 0
        if routine.type == .mistakeReview {
            let allMistakes = container.mistakeRepo.filteredMistakeSets
            let dueMistakes = SRSAlgorithm.dueMistakes(from: allMistakes, now: Date())
            let matched = dueMistakes.filter { mistake in
                if let subject = routine.subject {
                    return mistake.subject == subject
                }
                return true
            }
            spawnedMistakeCount = matched.count
        }

        return RoutineInstance(
            routineId: routine.id,
            title: routine.title,
            type: routine.type,
            subject: routine.subject,
            startTime: start,
            endTime: end,
            date: dayStart,
            spawnedMistakeCount: spawnedMistakeCount
        )
    }

    private func wireObservers() {
        // 监听 routine 集合变化,触发 reconcile
        // 注意:@Observable 的 mutations 自动触发 View 重渲,我们这里再补一次 spawn
        // (在 RepositoryContainer.recomputeAllFiltered() / 增删 routine 时调用)
        observationTask?.cancel()
        observationTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .routineDataChanged) {
                guard !Task.isCancelled else { return }
                self?.reconcileToday()
            }
        }
    }

    private func startPolling() {
        // 简单兜底:每 60s 查一次日期翻转
        pollTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkDateRollover()
            }
        }
    }
}

// MARK: - Notification

extension Notification.Name {
    /// 例程数据(增删 / 启停 / weekdays 改变)变更通知
    static let routineDataChanged = Notification.Name("StudyPulse.routineDataChanged")
}
