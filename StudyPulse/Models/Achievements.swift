//
//  Achievements.swift
//  StudyPulse
//
//  学习连续剧 & 成就系统的数据模型层。
//  Data models for the streak / achievement system.
//
//  - `DailyGoalConfig`      用户每日目标阈值
//  - `DailyActivityLog`     单日活动累计（错题复习 / 成绩录入 / 专注分钟）
//  - `StreakState`          当前 / 历史最长 / 总活跃天数
//  - `AchievementDefinition` 单个成就的目录条目（编译期常量）
//  - `AchievementProgress`  用户的进度与解锁状态
//  - `AchievementsSnapshot` 总快照（持久化根对象）
//
//  所有模型遵循仓库约定：nonisolated value type，Codable，Sendable，
//  可安全跨 actor 传递。AchievementsSnapshot 是单文件持久化根。
//

import Foundation

// MARK: - Daily Goal Configuration

/// 用户每日目标的阈值配置。任一目标达成即视为当日活跃（"中等"规则）。
/// User-configurable daily targets. The day counts as "active" when
/// at least one of the three goals is met (per the agreed semantics).
nonisolated struct DailyGoalConfig: Codable, Equatable {
    /// 错题复习目标（道）
    var mistakeReviewTarget: Int
    /// 成绩记录目标（条）
    var gradeRecordTarget: Int
    /// 专注分钟目标（分钟）
    var focusMinutesTarget: Int
    /// 是否启用每日提醒本地通知
    var reminderEnabled: Bool
    /// 提醒时间（24 小时制小时）
    var reminderHour: Int
    /// 提醒时间（分钟）
    var reminderMinute: Int

    static let `default` = DailyGoalConfig(
        mistakeReviewTarget: 5,
        gradeRecordTarget: 1,
        focusMinutesTarget: 25,
        reminderEnabled: true,
        reminderHour: 20,
        reminderMinute: 0
    )

    /// 任一日志满足任一目标阈值 → 当日活跃。
    /// Returns `true` when the log meets at least one configured target.
    func isActiveDay(_ log: DailyActivityLog) -> Bool {
        log.mistakeReviews >= mistakeReviewTarget
        || log.gradesRecorded >= gradeRecordTarget
        || log.focusMinutes >= focusMinutesTarget
    }

    /// 用于 Settings 步进器 / Slider 的合理上下界。
    enum Bounds {
        static let mistakeReviewRange: ClosedRange<Int> = 1...50
        static let gradeRecordRange: ClosedRange<Int> = 1...10
        static let focusMinutesRange: ClosedRange<Int> = 5...120
        static let reminderHourRange: ClosedRange<Int> = 0...23
        static let reminderMinuteRange: ClosedRange<Int> = 0...59
    }

    // MARK: - Backwards-compatible decoding
    // Older JSON files (v1.0 之前的快照) 没有 reminder* 字段。
    // Older snapshots may lack the reminder fields; default them so
    // decoding doesn't fail on a saved file.
    private enum CodingKeys: String, CodingKey {
        case mistakeReviewTarget, gradeRecordTarget, focusMinutesTarget,
             reminderEnabled, reminderHour, reminderMinute
    }
    init(mistakeReviewTarget: Int, gradeRecordTarget: Int, focusMinutesTarget: Int,
         reminderEnabled: Bool, reminderHour: Int, reminderMinute: Int) {
        self.mistakeReviewTarget = mistakeReviewTarget
        self.gradeRecordTarget = gradeRecordTarget
        self.focusMinutesTarget = focusMinutesTarget
        self.reminderEnabled = reminderEnabled
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.mistakeReviewTarget = try c.decodeIfPresent(
            Int.self, forKey: .mistakeReviewTarget) ?? Self.default.mistakeReviewTarget
        self.gradeRecordTarget = try c.decodeIfPresent(
            Int.self, forKey: .gradeRecordTarget) ?? Self.default.gradeRecordTarget
        self.focusMinutesTarget = try c.decodeIfPresent(
            Int.self, forKey: .focusMinutesTarget) ?? Self.default.focusMinutesTarget
        self.reminderEnabled = try c.decodeIfPresent(
            Bool.self, forKey: .reminderEnabled) ?? Self.default.reminderEnabled
        self.reminderHour = try c.decodeIfPresent(
            Int.self, forKey: .reminderHour) ?? Self.default.reminderHour
        self.reminderMinute = try c.decodeIfPresent(
            Int.self, forKey: .reminderMinute) ?? Self.default.reminderMinute
    }
}

// MARK: - Daily Activity Log

/// 单个日历日的活动累计。
/// Aggregated activity counts for a single calendar day.
nonisolated struct DailyActivityLog: Codable, Equatable, Identifiable {
    /// 当日开始时间（`Calendar.startOfDay(for: Date())`，本地时区）。
    /// Both the persistence key and `Identifiable` id.
    var date: Date
    /// 当日完成的错题复习数量。
    var mistakeReviews: Int
    /// 当日录入的成绩数量。
    var gradesRecorded: Int
    /// 当日累计专注分钟。
    var focusMinutes: Int

    var id: Date { date }

    init(date: Date,
         mistakeReviews: Int = 0,
         gradesRecorded: Int = 0,
         focusMinutes: Int = 0) {
        self.date = date
        self.mistakeReviews = mistakeReviews
        self.gradesRecorded = gradesRecorded
        self.focusMinutes = focusMinutes
    }

    /// 当日总活跃度（用于趋势/进度展示）。
    /// Simple "activity points" used purely for visualization, not persistence.
    var totalActivityPoints: Int {
        mistakeReviews + gradesRecorded * 5 + focusMinutes
    }
}

// MARK: - Streak State

/// 连续打卡状态。
/// Tracks the user's current streak, longest streak, and lifetime totals.
nonisolated struct StreakState: Codable, Equatable {
    /// 当前连续天数（含今日已达标则为今日，否则为到昨日为止的连续段长度）。
    var current: Int
    /// 历史最长连续天数。
    var longest: Int
    /// 上一次"达标"的日子（`startOfDay`），用于日期滚动判定。
    var lastActiveDate: Date?
    /// 累计活跃天数（达成任一目标的日子数）。
    var totalActiveDays: Int

    init(current: Int = 0,
         longest: Int = 0,
         lastActiveDate: Date? = nil,
         totalActiveDays: Int = 0) {
        self.current = current
        self.longest = longest
        self.lastActiveDate = lastActiveDate
        self.totalActiveDays = totalActiveDays
    }
}

// MARK: - Achievement Definition

/// 单个成就的目录定义。catalog 是编译期常量（AchievementCatalog.all）。
/// Compile-time catalogue entry; one per supported achievement.
nonisolated struct AchievementDefinition: Identifiable, Equatable, Sendable {
    /// 唯一稳定 id（也是本地化 key 的一部分，如 "achievement.streak_7.title"）。
    let id: String
    /// 本地化 key（不含 "achievement." 前缀）。
    let titleKey: String
    /// 本地化 key（不含 "achievement." 前缀）。
    let descriptionKey: String
    /// SF Symbol 图标名。
    let icon: String
    /// 成就分层。
    let tier: Tier
    /// 解锁条件。增量检查时根据 snapshot 状态判定。
    let criteria: Criteria

    enum Tier: String, Codable, Sendable {
        case onboarding
        case streak
        case volume
        case mastery
        case special
    }

    /// 解锁条件。
    /// Keep cases simple — complex aggregate checks happen in
    /// `AchievementCatalog.evaluate(_:snapshot:)`, not here.
    enum Criteria: Equatable, Sendable {
        /// 任意一项活动 ≥ 1（用于"first_step"）。
        case firstActivity
        /// 用户主动修改过每日目标配置。
        case goalConfigured
        /// 连续打卡天数达到 N。
        case currentStreak(Int)
        /// 累计活跃天数达到 N。
        case totalActiveDays(Int)
        /// 累计复习错题数达到 N。
        case mistakeReviewsTotal(Int)
        /// 累计录入成绩数达到 N。
        case gradesRecordedTotal(Int)
        /// 累计专注分钟达到 N。
        case focusMinutesTotal(Int)
    }

    init(id: String,
         titleKey: String,
         descriptionKey: String,
         icon: String,
         tier: Tier,
         criteria: Criteria) {
        self.id = id
        self.titleKey = titleKey
        self.descriptionKey = descriptionKey
        self.icon = icon
        self.tier = tier
        self.criteria = criteria
    }
}

// MARK: - Achievement Progress

/// 单个成就的进度与解锁状态。
nonisolated struct AchievementProgress: Codable, Equatable, Identifiable {
    /// catalog id（与 AchievementDefinition.id 对应）。
    var definitionId: String
    /// 当前进度值（用于 "5 / 7 days" 这种展示）。
    var currentValue: Int
    /// 解锁时间；nil 表示未解锁。
    var unlockedAt: Date?
    /// 是否"刚刚"解锁（用于触发一次性 toast；下次启动或 dismiss 后置 false）。
    var isNewlyUnlocked: Bool

    var id: String { definitionId }

    init(definitionId: String,
         currentValue: Int = 0,
         unlockedAt: Date? = nil,
         isNewlyUnlocked: Bool = false) {
        self.definitionId = definitionId
        self.currentValue = currentValue
        self.unlockedAt = unlockedAt
        self.isNewlyUnlocked = isNewlyUnlocked
    }

    var isUnlocked: Bool { unlockedAt != nil }

    /// 从 catalog 反向查找定义（便于视图层取 icon / tier / title）。
    var definition: AchievementDefinition {
        AchievementCatalog.all.first(where: { $0.id == definitionId })!
    }

}

// MARK: - Achievements Snapshot

/// 持久化根对象。写入 `~/Documents/achievements.json`。
/// Root persistence object — a single JSON file per device.
nonisolated struct AchievementsSnapshot: Codable, Equatable {
    /// 文件 schema 版本号，便于未来字段升级。
    var version: Int
    /// 用户每日目标配置。
    var config: DailyGoalConfig
    /// 每日活动日志（90 天滚动窗口）。
    var logs: [DailyActivityLog]
    /// 连续打卡状态。
    var streak: StreakState
    /// 所有成就的进度（与 catalog 一一对应；顺序与 catalog.all 一致）。
    var achievements: [AchievementProgress]
    /// 累计统计（永不重置，用于成就条件判定）。
    var cumulative: CumulativeTotals
    /// 用户是否主动修改过默认目标配置（首次保存 Goals 时置 true）。
    var hasConfiguredGoals: Bool

    /// 用于成就判定的累计统计（永不重置，与 logs 不同——logs 只保留 90 天）。
    nonisolated struct CumulativeTotals: Codable, Equatable {
        var mistakeReviews: Int
        var gradesRecorded: Int
        var focusMinutes: Int

        init(mistakeReviews: Int = 0,
             gradesRecorded: Int = 0,
             focusMinutes: Int = 0) {
            self.mistakeReviews = mistakeReviews
            self.gradesRecorded = gradesRecorded
            self.focusMinutes = focusMinutes
        }
    }

    static let empty = AchievementsSnapshot(
        version: 1,
        config: .default,
        logs: [],
        streak: StreakState(),
        achievements: [],
        cumulative: CumulativeTotals(),
        hasConfiguredGoals: false
    )

    init(version: Int,
         config: DailyGoalConfig,
         logs: [DailyActivityLog],
         streak: StreakState,
         achievements: [AchievementProgress],
         cumulative: CumulativeTotals,
         hasConfiguredGoals: Bool) {
        self.version = version
        self.config = config
        self.logs = logs
        self.streak = streak
        self.achievements = achievements
        self.cumulative = cumulative
        self.hasConfiguredGoals = hasConfiguredGoals
    }

    // MARK: - Backwards-compatible decoding
    // 老 schema（v1）可能没有 cumulative 或 hasConfiguredGoals 字段。
    private enum CodingKeys: String, CodingKey {
        case version, config, logs, streak, achievements, cumulative, hasConfiguredGoals
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        self.config = try c.decode(DailyGoalConfig.self, forKey: .config)
        self.logs = try c.decodeIfPresent([DailyActivityLog].self, forKey: .logs) ?? []
        self.streak = try c.decodeIfPresent(StreakState.self, forKey: .streak) ?? StreakState()
        self.achievements = try c.decodeIfPresent([AchievementProgress].self, forKey: .achievements) ?? []
        self.cumulative = try c.decodeIfPresent(CumulativeTotals.self, forKey: .cumulative) ?? CumulativeTotals()
        self.hasConfiguredGoals = try c.decodeIfPresent(Bool.self, forKey: .hasConfiguredGoals) ?? false
    }
}