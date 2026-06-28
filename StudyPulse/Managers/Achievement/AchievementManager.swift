//
//  AchievementManager.swift
//  StudyPulse
//
//  学习连续剧 & 成就系统的中央协调器。
//  Central coordinator for the streak & achievement system.
//
//  - @MainActor ObservableObject 单例
//  - 三个事件入口：recordGradeRecorded / recordMistakeReviewed / recordFocusMinutes
//  - updateConfig：用户在 Settings 里改每日目标时调
//  - handleDayRolloverIfNeeded：scenePhase == .active 时调，跨日滚动
//  - bootstrap()：StudyPulseApp .task 中，dataManager.isReady 后调一次
//
//  所有事件 → 修改 todayLog / cumulative / streak → 检查成就 → 写盘 + 解锁队列
//

import Foundation
import Combine
import os

@MainActor
final class AchievementManager: ObservableObject {
    static let shared = AchievementManager()

    // MARK: - Published state

    /// 完整快照（外部 view 不直接改）。
    @Published private(set) var snapshot: AchievementsSnapshot

    /// 今日活动日志（date == startOfDay(today) 的副本，便于 view 直接订阅）。
    @Published private(set) var todayLog: DailyActivityLog

    /// 当前连续天数（快照副本，避免 view 算）。
    @Published private(set) var currentStreak: Int

    /// 历史最长连续天数。
    @Published private(set) var longestStreak: Int

    /// 累计活跃天数。
    @Published private(set) var totalActiveDays: Int

    /// 最近一次"刚刚解锁"的成就（用于 toast 队列）。
    @Published var newlyUnlocked: [AchievementProgress] = []

    // MARK: - Lifecycle

    private init() {
        let today = Calendar.current.startOfDay(for: Date())
        let initial = AchievementStore.load()
        // 首次启动：把 catalog 投影成 achievements 数组（保持 catalog 顺序）
        let normalized = Self.normalizeAchievements(initial)
        self.snapshot = normalized
        self.todayLog = normalized.logs.first(where: {
            Calendar.current.startOfDay(for: $0.date) == today
        }) ?? DailyActivityLog(date: today)
        self.currentStreak = normalized.streak.current
        self.longestStreak = normalized.streak.longest
        self.totalActiveDays = normalized.streak.totalActiveDays
    }

    // MARK: - Bootstrap

    /// 由 StudyPulseApp 在 dataManager.isReady == true 之后调用一次。
    /// 负责：回填历史 + 处理日期滚动 + 写入 todayLog 初始值。
    func bootstrap() {
        var snap = snapshot
        let isFresh = snap.logs.isEmpty && snap.streak.totalActiveDays == 0
        if isFresh {
            backfillFromHistory(into: &snap)
            Log.achievement.info("成就系统回填完成 / Achievements backfilled: totalActive=\(snap.streak.totalActiveDays, privacy: .public) streak=\(snap.streak.current, privacy: .public)")
        }
        handleDayRolloverIfNeeded(into: &snap)
        snap = Self.normalizeAchievements(snap)
        snapshot = snap
        todayLog = snap.logs.first(where: {
            Calendar.current.startOfDay(for: $0.date) == Calendar.current.startOfDay(for: Date())
        }) ?? DailyActivityLog(date: Calendar.current.startOfDay(for: Date()))
        currentStreak = snap.streak.current
        longestStreak = snap.streak.longest
        totalActiveDays = snap.streak.totalActiveDays
        AchievementStore.save(snap)
    }

    /// scenePhase == .active 时调一次；处理跨日 + 同步今日 log。
    func handleDayRolloverIfNeeded() {
        var snap = snapshot
        handleDayRolloverIfNeeded(into: &snap)
        snap = Self.normalizeAchievements(snap)
        snapshot = snap
        todayLog = snap.logs.first(where: {
            Calendar.current.startOfDay(for: $0.date) == Calendar.current.startOfDay(for: Date())
        }) ?? DailyActivityLog(date: Calendar.current.startOfDay(for: Date()))
        currentStreak = snap.streak.current
        longestStreak = snap.streak.longest
        totalActiveDays = snap.streak.totalActiveDays
        AchievementStore.save(snap)
    }

    // MARK: - Event sinks

    /// DataManager.addGrade / addGrades 在写入 @Published grades 后调用。
    func recordGradeRecorded(count: Int = 1) {
        var snap = snapshot
        snap.cumulative.gradesRecorded += count
        applyActivityToday(mistakeReviews: 0, grades: count, focusMinutes: 0, into: &snap)
        finalize(&snap, trigger: "grade_recorded:\(count)")
    }

    /// FlashcardSessionSummaryView 在 onAppear 时调（一次会话算一次 review）。
    func recordMistakeReviewed(count: Int = 1) {
        guard count > 0 else { return }
        var snap = snapshot
        snap.cumulative.mistakeReviews += count
        applyActivityToday(mistakeReviews: count, grades: 0, focusMinutes: 0, into: &snap)
        finalize(&snap, trigger: "mistake_reviewed:\(count)")
    }

    /// StudyTimerManager.complete() 在写完 StudySessionStore 后调用。
    func recordFocusMinutes(_ minutes: Int) {
        guard minutes > 0 else { return }
        var snap = snapshot
        snap.cumulative.focusMinutes += minutes
        applyActivityToday(mistakeReviews: 0, grades: 0, focusMinutes: minutes, into: &snap)
        finalize(&snap, trigger: "focus_minutes:\(minutes)")
    }

    /// DailyGoalsConfigView 保存时调用。
    func updateConfig(_ config: DailyGoalConfig, markCustomized: Bool = true) {
        var snap = snapshot
        snap.config = config
        if markCustomized {
            snap.hasConfiguredGoals = true
        }
        // 配置变化后重算今日是否达标 + 重算 streak
        if let todayLog = snap.logs.first(where: {
            Calendar.current.startOfDay(for: $0.date) == Calendar.current.startOfDay(for: Date())
        }) {
            recomputeStreak(snap: &snap, todayLog: todayLog)
        }
        finalize(&snap, trigger: "config_updated")
    }

    /// 用户在 toast 队列里主动 dismiss 后调，清除该项。
    func dismissNewlyUnlocked(_ progress: AchievementProgress) {
        newlyUnlocked.removeAll { $0.definitionId == progress.definitionId }
        if let idx = snapshot.achievements.firstIndex(where: { $0.definitionId == progress.definitionId }) {
            snapshot.achievements[idx].isNewlyUnlocked = false
        }
    }

    /// 调试用：清空全部状态（DataAdminView 可触发）。
    func resetAll() {
        AchievementStore.reset()
        let today = Calendar.current.startOfDay(for: Date())
        snapshot = Self.normalizeAchievements(.empty)
        todayLog = DailyActivityLog(date: today)
        currentStreak = 0
        longestStreak = 0
        totalActiveDays = 0
        newlyUnlocked.removeAll()
        bootstrap()
    }

    // MARK: - Convenience for views

    /// "今日是否已经达成任一日目标"
    var todayGoalsMet: Bool {
        snapshot.config.isActiveDay(todayLog)
    }

    /// 今日三项目标的进度元组（current / target）
    func progress(for config: DailyGoalConfig) -> (reviews: (Int, Int), grades: (Int, Int), focus: (Int, Int)) {
        (
            reviews: (todayLog.mistakeReviews, config.mistakeReviewTarget),
            grades: (todayLog.gradesRecorded, config.gradeRecordTarget),
            focus: (todayLog.focusMinutes, config.focusMinutesTarget)
        )
    }

    // MARK: - Private

    /// 把今日事件累加到 todayLog；如果跨日，先收尾昨日。
    private func applyActivityToday(mistakeReviews: Int, grades: Int, focusMinutes: Int,
                                    into snap: inout AchievementsSnapshot) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        // 先确保 day rollover 正确（防御性调用）
        if let existing = snap.logs.first(where: { cal.startOfDay(for: $0.date) == today }) {
            let updated = DailyActivityLog(
                date: today,
                mistakeReviews: existing.mistakeReviews + mistakeReviews,
                gradesRecorded: existing.gradesRecorded + grades,
                focusMinutes: existing.focusMinutes + focusMinutes
            )
            snap.logs = snap.logs.filter { cal.startOfDay(for: $0.date) != today } + [updated]
        } else {
            // 新的一天开始
            snap.logs.append(DailyActivityLog(
                date: today,
                mistakeReviews: mistakeReviews,
                gradesRecorded: grades,
                focusMinutes: focusMinutes
            ))
        }
        snap.logs.sort { $0.date < $1.date }
    }

    /// 把 day rollover + 连续计算 + 成就检测 + 持久化 + Published 同步一起做。
    private func finalize(_ snap: inout AchievementsSnapshot, trigger: String) {
        handleDayRolloverIfNeeded(into: &snap)
        let today = Calendar.current.startOfDay(for: Date())
        if let todayLog = snap.logs.first(where: { Calendar.current.startOfDay(for: $0.date) == today }) {
            recomputeStreak(snap: &snap, todayLog: todayLog)
        }
        let unlocked = evaluateAchievements(snap: &snap)
        snap = Self.normalizeAchievements(snap)
        snapshot = snap
        self.todayLog = snap.logs.first(where: {
            Calendar.current.startOfDay(for: $0.date) == today
        }) ?? DailyActivityLog(date: today)
        currentStreak = snap.streak.current
        longestStreak = snap.streak.longest
        totalActiveDays = snap.streak.totalActiveDays
        AchievementStore.save(snap)
        if !unlocked.isEmpty {
            newlyUnlocked.append(contentsOf: unlocked)
            Log.record(.info, category: "Achievement",
                       message: "解锁 \(unlocked.count) 个成就 / Unlocked \(unlocked.count) achievement(s): ids=\(unlocked.map(\.definitionId).joined(separator: ",")) trigger=\(trigger)")
        }
    }

    /// 检测日期是否跨越。如果跨越，按昨日是否达标更新 streak。
    private func handleDayRolloverIfNeeded(into snap: inout AchievementsSnapshot) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        // 找出 todayLog（可能不存在）
        let todayLog = snap.logs.first(where: { cal.startOfDay(for: $0.date) == today })
        if todayLog == nil {
            // 今天还没记录，新建空今日 log
            snap.logs.append(DailyActivityLog(date: today))
            snap.logs.sort { $0.date < $1.date }
        }
        // 检查 lastActiveDate 是否比今日早 1 天以上 → streak 重置
        if let last = snap.streak.lastActiveDate {
            let lastDay = cal.startOfDay(for: last)
            if let dayBeforeToday = cal.date(byAdding: .day, value: -1, to: today),
               lastDay < dayBeforeToday {
                // 昨日没打卡，streak 断
                if todayLog == nil {
                    snap.streak.current = 0
                }
            }
        }
    }

    /// 根据日志重算 streak.current / longest / totalActiveDays / lastActiveDate。
    /// 实现：按日期降序遍历，遇到第一个非达标日停止累加 current；totalActiveDays 重新数所有达标日。
    private func recomputeStreak(snap: inout AchievementsSnapshot, todayLog: DailyActivityLog) {
        let cal = Calendar.current
        let config = snap.config
        // 按日期升序
        let sortedLogs = snap.logs.sorted { $0.date < $1.date }
        var current = 0
        var longest = snap.streak.longest
        var totalActive = 0
        var lastActive: Date? = nil
        for log in sortedLogs {
            if config.isActiveDay(log) {
                totalActive += 1
                lastActive = log.date
            }
        }
        // current：从今天往前数连续段长度
        // 算法：把 sortedLogs 反转，遇到第一个 active +1，连续非 active 停止
        let reversed = sortedLogs.reversed()
        var lastDate: Date? = nil
        for log in reversed {
            let day = cal.startOfDay(for: log.date)
            if let prev = lastDate {
                // 与前一天必须相邻
                if let expected = cal.date(byAdding: .day, value: 1, to: day),
                   cal.startOfDay(for: prev) == expected {
                    // 相邻，继续
                } else {
                    break
                }
            }
            if config.isActiveDay(log) {
                current += 1
                lastDate = day
            } else {
                break
            }
        }
        longest = max(longest, current)
        snap.streak = StreakState(
            current: current,
            longest: longest,
            lastActiveDate: lastActive,
            totalActiveDays: totalActive
        )
    }

    /// 检查所有 catalog 条目，把未解锁的、当前 snapshot 满足的置为解锁。
    /// 返回刚刚解锁的列表（用于 toast）。
    private func evaluateAchievements(snap: inout AchievementsSnapshot) -> [AchievementProgress] {
        var unlocked: [AchievementProgress] = []
        for def in AchievementCatalog.all {
            guard let idx = snap.achievements.firstIndex(where: { $0.definitionId == def.id }) else {
                continue
            }
            var progress = snap.achievements[idx]
            // 更新 currentValue（用于 progress display）
            progress.currentValue = currentValue(for: def, in: snap)
            if !progress.isUnlocked, def.criteria.isSatisfied(by: snap) {
                progress.unlockedAt = Date()
                progress.isNewlyUnlocked = true
                unlocked.append(progress)
                Log.achievement.info("解锁成就 / Achievement unlocked: id=\(def.id, privacy: .public)")
            }
            snap.achievements[idx] = progress
        }
        return unlocked
    }

    /// 计算 catalog 条目的当前进度值。
    private func currentValue(for def: AchievementDefinition, in snap: AchievementsSnapshot) -> Int {
        switch def.criteria {
        case .firstActivity:
            return min(1, snap.cumulative.mistakeReviews
                       + snap.cumulative.gradesRecorded
                       + snap.cumulative.focusMinutes)
        case .goalConfigured:
            return snap.hasConfiguredGoals ? 1 : 0
        case .currentStreak:
            return max(snap.streak.current, snap.streak.longest)
        case .totalActiveDays:
            return snap.streak.totalActiveDays
        case .mistakeReviewsTotal:
            return snap.cumulative.mistakeReviews
        case .gradesRecordedTotal:
            return snap.cumulative.gradesRecorded
        case .focusMinutesTotal:
            return snap.cumulative.focusMinutes
        }
    }

    /// 把 snapshot.achievements 与 catalog 对齐（新增 catalog 条目时自动补 progress）。
    static func normalizeAchievements(_ snap: AchievementsSnapshot) -> AchievementsSnapshot {
        var result = snap
        let existingIds = Set(result.achievements.map(\.definitionId))
        var merged: [AchievementProgress] = []
        for def in AchievementCatalog.all {
            if let existing = result.achievements.first(where: { $0.definitionId == def.id }) {
                merged.append(existing)
            } else {
                merged.append(AchievementProgress(definitionId: def.id))
                _ = existingIds  // silence unused
            }
        }
        result.achievements = merged
        return result
    }

    // MARK: - Backfill (Phase 4)

    /// 首次启动：扫描过去 30 天的 grades + study sessions，反推活动日 + streak。
    private func backfillFromHistory(into snap: inout AchievementsSnapshot) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let cutoff = cal.date(byAdding: .day, value: -30, to: today) else { return }

        // 聚合 study sessions（专注分钟）
        let sessions = StudySessionStore.load().filter {
            $0.completed && cal.startOfDay(for: $0.startDate) >= cutoff
        }
        // 聚合 grades
        let grades = DataManager.shared.grades.filter {
            cal.startOfDay(for: $0.date) >= cutoff
        }

        var byDay: [Date: DailyActivityLog] = [:]
        for s in sessions {
            let day = cal.startOfDay(for: s.startDate)
            var log = byDay[day] ?? DailyActivityLog(date: day)
            log.focusMinutes += s.durationSeconds / 60
            byDay[day] = log
        }
        for g in grades {
            let day = cal.startOfDay(for: g.date)
            var log = byDay[day] ?? DailyActivityLog(date: day)
            log.gradesRecorded += 1
            byDay[day] = log
        }

        // 倒序计算 streak
        let sortedDays = byDay.keys.sorted().reversed()
        let config = snap.config
        var streak = StreakState()
        var prevDay: Date? = nil
        for day in sortedDays {
            if let prev = prevDay {
                let expected = cal.date(byAdding: .day, value: -1, to: prev)!
                if day != expected {
                    break
                }
            }
            if config.isActiveDay(byDay[day]!) {
                streak.current += 1
                streak.longest = max(streak.longest, streak.current)
                streak.totalActiveDays += 1
                streak.lastActiveDate = day
                prevDay = day
            } else {
                break
            }
        }
        // longest = max(倒序连续段, all-time count)
        let allTimeActive = byDay.values.filter { config.isActiveDay($0) }.count
        streak.longest = max(streak.longest, allTimeActive)

        snap.logs = byDay.values.sorted { $0.date < $1.date }
        snap.streak = streak
        snap.cumulative.focusMinutes = sessions.reduce(0) { $0 + $1.durationSeconds / 60 }
        snap.cumulative.gradesRecorded = grades.count
        snap.cumulative.mistakeReviews = 0   // flashcard review 历史未持久化，留 0
        // 注意：hasConfiguredGoals 不在回填时设置；只有用户主动改过才为 true
    }
}