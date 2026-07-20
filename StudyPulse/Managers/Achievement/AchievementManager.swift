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
    // MARK: - 发布状态 / Published state

    /// 完整快照（外部 view 不直接改）。
    /// Full snapshot (views must not mutate it directly).
    /// `didSet` 在 snapshot 被赋值后 post `achievementsSnapshotDidChange` 通知,
    /// PlantManager 监听此通知替代原 1.5s polling。
    /// `didSet` posts `achievementsSnapshotDidChange` whenever the snapshot is assigned;
    /// PlantManager listens to this notification instead of the old 1.5s polling.
    @Published private(set) var snapshot: AchievementsSnapshot {
        didSet {
            NotificationCenter.default.post(name: .achievementsSnapshotDidChange, object: nil)
        }
    }

    /// 今日活动日志（date == startOfDay(today) 的副本，便于 view 直接订阅）。
    /// Today's activity log (a copy where date == startOfDay(today) so views can subscribe directly).
    @Published private(set) var todayLog: DailyActivityLog

    /// 当前连续天数（快照副本，避免 view 算）。
    /// Current streak length (snapshot copy, lets views read instead of recomputing).
    @Published private(set) var currentStreak: Int

    /// 历史最长连续天数。
    /// All-time longest streak in days.
    @Published private(set) var longestStreak: Int

    /// 累计活跃天数。
    /// Total number of days that hit the daily goal.
    @Published private(set) var totalActiveDays: Int

    /// 最近一次"刚刚解锁"的成就（用于 toast 队列）。
    /// Recently-unlocked achievements, queued for toast notifications.
    @Published var newlyUnlocked: [AchievementProgress] = []

    // MARK: - Lifecycle
    // MARK: - 生命周期 / Lifecycle

    private init() {
        let today = Calendar.current.startOfDay(for: Date())
        let initial = AchievementStore.load()
        // 首次启动：把 catalog 投影成 achievements 数组（保持 catalog 顺序）
        // First launch: project the catalog into an achievements array (preserves catalog order).
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
    // MARK: - 启动回填 / Bootstrap

    /// 由 StudyPulseApp 在 dataManager.isReady == true 之后调用一次。
    /// 负责：回填历史 + 处理日期滚动 + 写入 todayLog 初始值。
    /// Called once by StudyPulseApp after dataManager.isReady == true.
    /// Handles: backfill history + day rollover + initial todayLog write.
    func bootstrap(container: RepositoryContainer) {
        var snap = snapshot
        let isFresh = snap.logs.isEmpty && snap.streak.totalActiveDays == 0
        if isFresh {
            backfillFromHistory(into: &snap, container: container)
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
    /// Called once when scenePhase == .active; processes day rollover and refreshes today's log.
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
    // MARK: - 事件入口 / Event sinks

    // MARK: - Plant subscriber
    // PlantManager 通过订阅本类的 @Published snapshot（约 1.5s polling）实现
    // 主页植物阶段自动重算。无需在此处添加专门事件。
    // PlantManager observes this class's @Published snapshot (1.5s polling)
    // to recompute the home plant stage. No extra event hook needed here.

    /// DataManager.addGrade / addGrades 在写入 @Published grades 后调用。
    /// Invoked by DataManager.addGrade / addGrades after writing to @Published grades.
    func recordGradeRecorded(count: Int = 1) {
        var snap = snapshot
        snap.cumulative.gradesRecorded += count
        applyActivityToday(mistakeReviews: 0, grades: count, focusMinutes: 0, into: &snap)
        finalize(&snap, trigger: "grade_recorded:\(count)")
    }

    /// FlashcardSessionSummaryView 在 onAppear 时调（一次会话算一次 review）。
    /// Called from FlashcardSessionSummaryView onAppear (one session counts as one review).
    func recordMistakeReviewed(count: Int = 1) {
        guard count > 0 else { return }
        var snap = snapshot
        snap.cumulative.mistakeReviews += count
        applyActivityToday(mistakeReviews: count, grades: 0, focusMinutes: 0, into: &snap)
        finalize(&snap, trigger: "mistake_reviewed:\(count)")
    }

    /// StudyTimerManager.complete() 在写完 StudySessionStore 后调用。
    /// Invoked by StudyTimerManager.complete() after writing to StudySessionStore.
    func recordFocusMinutes(_ minutes: Int) {
        guard minutes > 0 else { return }
        var snap = snapshot
        snap.cumulative.focusMinutes += minutes
        applyActivityToday(mistakeReviews: 0, grades: 0, focusMinutes: minutes, into: &snap)
        finalize(&snap, trigger: "focus_minutes:\(minutes)")
    }

    /// 手动补录指定日期的学习活动，不能登记未来日期。
    func recordManualActivity(kind: ManualActivityKind, count: Int, date: Date) {
        guard count > 0 else { return }
        let cal = Calendar.current
        let day = cal.startOfDay(for: date)
        guard day <= cal.startOfDay(for: Date()) else { return }

        var snap = snapshot
        switch kind {
        case .mistakeReview:
            snap.cumulative.mistakeReviews += count
            applyActivity(on: day, mistakeReviews: count, grades: 0, focusMinutes: 0, into: &snap)
        case .gradeRecorded:
            snap.cumulative.gradesRecorded += count
            applyActivity(on: day, mistakeReviews: 0, grades: count, focusMinutes: 0, into: &snap)
        case .focusMinutes:
            snap.cumulative.focusMinutes += count
            applyActivity(on: day, mistakeReviews: 0, grades: 0, focusMinutes: count, into: &snap)
        }
        finalize(&snap, trigger: "manual_activity:\(kind.rawValue):\(count):\(day)")
    }

    /// DailyGoalsConfigView 保存时调用。
    /// Invoked when DailyGoalsConfigView saves the user's daily goal config.
    func updateConfig(_ config: DailyGoalConfig, markCustomized: Bool = true) {
        var snap = snapshot
        snap.config = config
        if markCustomized {
            snap.hasConfiguredGoals = true
        }
        // 配置变化后重算今日是否达标 + 重算 streak
        // After a config change, recompute today's goal satisfaction + streak.
        if let todayLog = snap.logs.first(where: {
            Calendar.current.startOfDay(for: $0.date) == Calendar.current.startOfDay(for: Date())
        }) {
            recomputeStreak(snap: &snap, todayLog: todayLog)
        }
        finalize(&snap, trigger: "config_updated")
    }

    /// 用户在 toast 队列里主动 dismiss 后调，清除该项。
    /// Called after the user manually dismisses a toast; clears that entry.
    func dismissNewlyUnlocked(_ progress: AchievementProgress) {
        newlyUnlocked.removeAll { $0.definitionId == progress.definitionId }
        if let idx = snapshot.achievements.firstIndex(where: { $0.definitionId == progress.definitionId }) {
            snapshot.achievements[idx].isNewlyUnlocked = false
        }
    }

    /// 调试用：清空全部状态（DataAdminView 可触发）。
    /// Debug-only: wipes all state (DataAdminView can trigger it).
    func resetAll(container: RepositoryContainer) {
        AchievementStore.reset()
        let today = Calendar.current.startOfDay(for: Date())
        snapshot = Self.normalizeAchievements(.empty)
        todayLog = DailyActivityLog(date: today)
        currentStreak = 0
        longestStreak = 0
        totalActiveDays = 0
        newlyUnlocked.removeAll()
        bootstrap(container: container)
    }

    // MARK: - Convenience for views
    // MARK: - 视图便捷属性 / Convenience for views

    /// "今日是否已经达成任一日目标"
    /// Whether today has hit any of the daily goals.
    var todayGoalsMet: Bool {
        snapshot.config.isActiveDay(todayLog)
    }

    /// 今日三项目标的进度元组（current / target）
    /// Progress tuple (current / target) for the three daily goals.
    func progress(for config: DailyGoalConfig) -> (reviews: (Int, Int), grades: (Int, Int), focus: (Int, Int)) {
        (
            reviews: (todayLog.mistakeReviews, config.mistakeReviewTarget),
            grades: (todayLog.gradesRecorded, config.gradeRecordTarget),
            focus: (todayLog.focusMinutes, config.focusMinutesTarget)
        )
    }

    // MARK: - Private
    // MARK: - 私有实现 / Private

    /// 把今日事件累加到 todayLog；如果跨日，先收尾昨日。
    /// Adds today's events into todayLog; rolls over yesterday first if needed.
    private func applyActivityToday(mistakeReviews: Int, grades: Int, focusMinutes: Int,
                                    into snap: inout AchievementsSnapshot) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        applyActivity(on: today, mistakeReviews: mistakeReviews, grades: grades,
                      focusMinutes: focusMinutes, into: &snap)
    }

    private func applyActivity(on day: Date, mistakeReviews: Int, grades: Int, focusMinutes: Int,
                               into snap: inout AchievementsSnapshot) {
        let cal = Calendar.current
        // 先确保 day rollover 正确（防御性调用）
        // Make sure day rollover is correct first (defensive call).
        if let existing = snap.logs.first(where: { cal.startOfDay(for: $0.date) == day }) {
            let updated = DailyActivityLog(
                date: day,
                mistakeReviews: existing.mistakeReviews + mistakeReviews,
                gradesRecorded: existing.gradesRecorded + grades,
                focusMinutes: existing.focusMinutes + focusMinutes
            )
            snap.logs = snap.logs.filter { cal.startOfDay(for: $0.date) != day } + [updated]
        } else {
            // 新的一天开始
            // A new day has started.
            snap.logs.append(DailyActivityLog(
                date: day,
                mistakeReviews: mistakeReviews,
                gradesRecorded: grades,
                focusMinutes: focusMinutes
            ))
        }
        snap.logs.sort { $0.date < $1.date }
    }

    /// 把 day rollover + 连续计算 + 成就检测 + 持久化 + Published 同步一起做。
    /// Performs day rollover + streak recompute + achievement evaluation + persistence + Published sync in one shot.
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
    /// Detects whether the date has rolled over; updates streak based on whether yesterday met the goal.
    private func handleDayRolloverIfNeeded(into snap: inout AchievementsSnapshot) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        // 找出 todayLog（可能不存在）
        // Find todayLog (may not exist yet).
        let todayLog = snap.logs.first(where: { cal.startOfDay(for: $0.date) == today })
        if todayLog == nil {
            // 今天还没记录，新建空今日 log
            // Nothing logged for today yet, create an empty today log.
            snap.logs.append(DailyActivityLog(date: today))
            snap.logs.sort { $0.date < $1.date }
        }
        // 检查 lastActiveDate 是否比今日早 1 天以上 → streak 重置
        // If lastActiveDate is more than 1 day before today → reset streak.
        if let last = snap.streak.lastActiveDate {
            let lastDay = cal.startOfDay(for: last)
            if let dayBeforeToday = cal.date(byAdding: .day, value: -1, to: today),
               lastDay < dayBeforeToday {
                // 昨日没打卡，streak 断
                // Yesterday was not checked in → streak broken.
                if todayLog == nil {
                    snap.streak.current = 0
                }
            }
        }
    }

    /// 根据日志重算 streak.current / longest / totalActiveDays / lastActiveDate。
    /// 实现：按日期降序遍历，遇到第一个非达标日停止累加 current；totalActiveDays 重新数所有达标日。
    /// Recomputes streak.current / longest / totalActiveDays / lastActiveDate from logs.
    /// Walks logs in date order; stops accumulating `current` at the first non-active day; `totalActiveDays` recounts all active days.
    private func recomputeStreak(snap: inout AchievementsSnapshot, todayLog: DailyActivityLog) {
        let cal = Calendar.current
        let config = snap.config
        // 按日期升序
        // Sort by date ascending.
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
        // current: count the consecutive run backwards from today.
        // Algorithm: reverse sortedLogs, increment on the first active day, stop on the first non-active day.
        let reversed = sortedLogs.reversed()
        var lastDate: Date? = nil
        for log in reversed {
            let day = cal.startOfDay(for: log.date)
            if let prev = lastDate {
                // 与前一天必须相邻
                // Must be adjacent to the previous day.
                if let expected = cal.date(byAdding: .day, value: 1, to: day),
                   cal.startOfDay(for: prev) == expected {
                    // 相邻，继续
                    // Adjacent, keep going.
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
    /// Walks every catalog entry and unlocks any that are not yet unlocked but are satisfied by the current snapshot.
    /// Returns the freshly-unlocked list (for toasts).
    private func evaluateAchievements(snap: inout AchievementsSnapshot) -> [AchievementProgress] {
        var unlocked: [AchievementProgress] = []
        for def in AchievementCatalog.all {
            guard let idx = snap.achievements.firstIndex(where: { $0.definitionId == def.id }) else {
                continue
            }
            var progress = snap.achievements[idx]
            // 更新 currentValue（用于 progress display）
            // Update currentValue (used for progress display).
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
    /// Computes the current progress value for a catalog entry.
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
    /// Aligns `snapshot.achievements` with the catalog (auto-fills progress for new catalog entries).
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
                // 仅用于未来 debug 引用，保持 existingIds 不被编译器警告。
                // Kept for future debug references; avoids an unused-variable warning.
            }
        }
        result.achievements = merged
        return result
    }

    // MARK: - Backfill (Phase 4)
    // MARK: - 历史回填 (Phase 4) / Backfill

    /// 首次启动：扫描过去 30 天的 grades + study sessions，反推活动日 + streak。
    /// First launch: scans the past 30 days of grades + study sessions, infers active days + streak from them.
    private func backfillFromHistory(into snap: inout AchievementsSnapshot, container: RepositoryContainer) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let cutoff = cal.date(byAdding: .day, value: -30, to: today) else { return }

        // 聚合 study sessions（专注分钟）
        // Aggregate study sessions (focus minutes).
        let sessions = StudySessionStore.load().filter {
            $0.completed && cal.startOfDay(for: $0.startDate) >= cutoff
        }
        // 聚合 grades
        // Aggregate grades.
        let grades = container.gradeRepo.grades.filter {
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
        // Compute the streak in reverse order.
        let sortedDays = byDay.keys.sorted().reversed()
        let config = snap.config
        var streak = StreakState()
        var prevDay: Date? = nil
        for day in sortedDays {
            // 防御:byDay 是按 day 聚合的,key 必然在 dict 中,但仍用 guard 替代 ! 强解
            // Defensive: byDay is keyed by day so the key must exist, but we use guard instead of force-unwrap.
            guard let activity = byDay[day] else { continue }
            if let prev = prevDay {
                guard let expected = cal.date(byAdding: .day, value: -1, to: prev) else { break }
                if day != expected {
                    break
                }
            }
            if config.isActiveDay(activity) {
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
        // longest = max(reverse-run, all-time active day count).
        let allTimeActive = byDay.values.filter { config.isActiveDay($0) }.count
        streak.longest = max(streak.longest, allTimeActive)

        snap.logs = byDay.values.sorted { $0.date < $1.date }
        snap.streak = streak
        snap.cumulative.focusMinutes = sessions.reduce(0) { $0 + $1.durationSeconds / 60 }
        snap.cumulative.gradesRecorded = grades.count
        snap.cumulative.mistakeReviews = 0   // flashcard review 历史未持久化，留 0
        // flashcard review history isn't persisted, defaulting to 0.
        // 注意：hasConfiguredGoals 不在回填时设置；只有用户主动改过才为 true
        // Note: hasConfiguredGoals is not set during backfill; it only flips to true after the user edits it.
    }
}
