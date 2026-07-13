//
//  RoutineLiveActivityController.swift
//  StudyPulse
//
//  例程 Live Activity 控制器。负责 start / update / end。
//
//  Created for Plans & Routines spec (2026-07-09).
//

import Foundation
@preconcurrency import ActivityKit
import os
import SwiftUI

@MainActor
@Observable
final class RoutineLiveActivityController {
    static let shared = RoutineLiveActivityController()

    @ObservationIgnored
    private let log = Logger(subsystem: "app.StudyPulse", category: "RoutineLiveActivity")  // 专用 os.Logger
    @ObservationIgnored
    private var pollTimer: Timer?                            // 30s tick 定时器,更新 Live Activity
    @ObservationIgnored
    private var activeRoutineId: UUID?                      // 当前正在显示的 routine id
    @ObservationIgnored
    private var lastEndDate: Date?                          // 当前 instance 的结束时间

    private init() {}

    // MARK: - Public API

    /// 启动一个例程 Live Activity(若已存在同名 routine 的则不重复)
    func startIfNeeded(
        routine: Routine,
        instance: RoutineInstance,
        now: Date = Date()
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            log.info("Live Activities disabled by user")
            return
        }
        // 若已存在同 routineId 的活动,直接 attach
        if let existing = Activity<RoutineActivityAttributes>.activities
            .first(where: { $0.attributes.routineId == routine.id }) {
            activeRoutineId = routine.id
            lastEndDate = instance.endTime
            _ = existing
            log.info("RoutineLiveActivity already active: routineId=\(routine.id.uuidString, privacy: .public)")
            return
        }
        let attributes = RoutineActivityAttributes(
            routineId: routine.id,
            title: routine.title,
            subject: routine.subject,
            typeRaw: routine.type.rawValue,
            totalSeconds: instance.startTime.distance(to: instance.endTime) > 0
                ? Int(instance.endTime.timeIntervalSince(instance.startTime)) : 0,
            startISO: DateFormatters.iso8601.string(from: instance.startTime),
            endISO: DateFormatters.iso8601.string(from: instance.endTime),
            colorHex: routine.type.colorHex
        )
        let remaining = max(0, Int(instance.endTime.timeIntervalSince(now)))
        let state = RoutineContentState(
            remainingSeconds: remaining,
            currentItemTitle: instance.spawnedMistakeCount > 0
                ? String(format: "%d mistakes due".localized(), instance.spawnedMistakeCount)
                : nil,
            tier: tierFor(remaining: remaining),
            progress: progressOf(instance: instance, now: now)
        )
        do {
            let content = ActivityContent(state: state, staleDate: instance.endTime.addingTimeInterval(60 * 5))
            _ = try Activity<RoutineActivityAttributes>.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            activeRoutineId = routine.id
            lastEndDate = instance.endTime
            startPolling(instance: instance)
            log.info("RoutineLiveActivity started: routineId=\(routine.id.uuidString, privacy: .public)")
            Log.record(.info, category: "Plan", message: "RoutineLiveActivity started: \(routine.title)")
        } catch {
            log.error("RoutineLiveActivity start failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 主动结束(由 instance 标记完成触发)
    func end(dismissalPolicy: ActivityUIDismissalPolicy = .default) {
        let activities = Activity<RoutineActivityAttributes>.activities
        let policy = dismissalPolicy
        for activity in activities {
            nonisolated(unsafe) let safe = activity
            Task { @MainActor [weak self] in
                let final = RoutineContentState(
                    remainingSeconds: 0,
                    currentItemTitle: nil,
                    tier: .steady,
                    progress: 1.0
                )
                let content = ActivityContent(state: final, staleDate: nil)
                await safe.end(content, dismissalPolicy: policy)
                self?.pollTimer?.invalidate()
                self?.pollTimer = nil
                self?.activeRoutineId = nil
                self?.lastEndDate = nil
            }
        }
        // 兜底:若没有 active 活动,直接 reset 本地状态
        if activities.isEmpty {
            pollTimer?.invalidate()
            pollTimer = nil
            activeRoutineId = nil
            lastEndDate = nil
        }
    }

    /// App 启动时调用:若当前有进行中的 instance,恢复 Live Activity
    /// (系统在重启 / Activity 过期后可能不再保留,我们重建一条)
    func restoreIfNeeded(container: RepositoryContainer) {
        let active = container.routineInstanceRepo.activeInstances
        guard let inst = active.first else { return }
        guard let routine = container.routineRepo.routines
            .first(where: { $0.id == inst.routineId }) else { return }
        startIfNeeded(routine: routine, instance: inst)
    }

    // MARK: - Internals

    private func startPolling(instance: RoutineInstance) {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick(instance: instance)
            }
        }
        // 立即 tick 一次
        tick(instance: instance)
    }

    private func tick(instance: RoutineInstance) {
        let now = Date()
        let remaining = max(0, Int(instance.endTime.timeIntervalSince(now)))
        let state = RoutineContentState(
            remainingSeconds: remaining,
            currentItemTitle: instance.spawnedMistakeCount > 0
                ? String(format: "%d mistakes due".localized(), instance.spawnedMistakeCount)
                : nil,
            tier: tierFor(remaining: remaining),
            progress: progressOf(instance: instance, now: now)
        )
        for activity in Activity<RoutineActivityAttributes>.activities
            where activity.attributes.routineId == instance.routineId {
            nonisolated(unsafe) let act = activity
            let stateCopy = state
            let endDate = instance.endTime
            Task { @MainActor in
                let content = ActivityContent(state: stateCopy, staleDate: endDate.addingTimeInterval(60 * 5))
                await act.update(content)
            }
        }
        if now >= instance.endTime {
            end()
        }
    }

    private func tierFor(remaining: Int) -> RoutineContentState.Tier {
        // < 60s: critical(只剩最后 1 分钟)
        // < 5min: warning
        // else: steady
        if remaining < 60 { return .critical }
        if remaining < 5 * 60 { return .warning }
        return .steady
    }

    private func progressOf(instance: RoutineInstance, now: Date) -> Double {
        let total = instance.endTime.timeIntervalSince(instance.startTime)
        guard total > 0 else { return 0 }
        let elapsed = now.timeIntervalSince(instance.startTime)
        return max(0, min(1, elapsed / total))
    }
}
