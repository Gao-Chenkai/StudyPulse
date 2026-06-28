//
//  AchievementCatalog.swift
//  StudyPulse
//
//  成就目录（编译期常量）。所有用户可见文案通过 Localizable.strings 提供。
//  Compile-time catalogue of every achievement the user can unlock.
//
//  - 本地化 key 命名约定：`achievement.<id>.title` / `achievement.<id>.description`
//  - 顺序就是 Settings → Achievements 视图里的展示顺序
//  - 修改 catalog 时务必同步更新 5 份 Localizable.strings
//

import Foundation

/// 全局成就目录常量。
enum AchievementCatalog {
    /// 所有成就的稳定顺序。`AchievementProgress.definitionId` 与本数组元素一一对应。
    nonisolated static let all: [AchievementDefinition] = onboardingTier
        + volumeTier
        + masteryTier
        + streakTier

    /// 顺序倒过来：先 onboarding，再 volume，再 streak（视觉上由浅入深）。
    nonisolated private static let onboardingTier: [AchievementDefinition] = [
        AchievementDefinition(
            id: "first_step",
            titleKey: "first_step.title",
            descriptionKey: "first_step.description",
            icon: "sparkles",
            tier: .onboarding,
            criteria: .firstActivity
        ),
        AchievementDefinition(
            id: "goal_setter",
            titleKey: "goal_setter.title",
            descriptionKey: "goal_setter.description",
            icon: "slider.horizontal.3",
            tier: .onboarding,
            criteria: .goalConfigured
        ),
    ]

    /// 累计类：复习 / 成绩 / 专注分钟。
    nonisolated private static let volumeTier: [AchievementDefinition] = [
        // 错题复习
        AchievementDefinition(
            id: "reviews_10",
            titleKey: "reviews_10.title",
            descriptionKey: "reviews_10.description",
            icon: "rectangle.stack.fill",
            tier: .volume,
            criteria: .mistakeReviewsTotal(10)
        ),
        AchievementDefinition(
            id: "reviews_50",
            titleKey: "reviews_50.title",
            descriptionKey: "reviews_50.description",
            icon: "rectangle.stack.fill.badge.plus",
            tier: .volume,
            criteria: .mistakeReviewsTotal(50)
        ),
        AchievementDefinition(
            id: "reviews_200",
            titleKey: "reviews_200.title",
            descriptionKey: "reviews_200.description",
            icon: "rectangle.stack.badge.play",
            tier: .volume,
            criteria: .mistakeReviewsTotal(200)
        ),
        AchievementDefinition(
            id: "reviews_1000",
            titleKey: "reviews_1000.title",
            descriptionKey: "reviews_1000.description",
            icon: "books.vertical.fill",
            tier: .volume,
            criteria: .mistakeReviewsTotal(1000)
        ),
        // 成绩录入
        AchievementDefinition(
            id: "grades_10",
            titleKey: "grades_10.title",
            descriptionKey: "grades_10.description",
            icon: "list.bullet.rectangle",
            tier: .volume,
            criteria: .gradesRecordedTotal(10)
        ),
        AchievementDefinition(
            id: "grades_50",
            titleKey: "grades_50.title",
            descriptionKey: "grades_50.description",
            icon: "list.bullet.rectangle.fill",
            tier: .volume,
            criteria: .gradesRecordedTotal(50)
        ),
        AchievementDefinition(
            id: "grades_200",
            titleKey: "grades_200.title",
            descriptionKey: "grades_200.description",
            icon: "chart.bar.doc.horizontal",
            tier: .volume,
            criteria: .gradesRecordedTotal(200)
        ),
        // 专注分钟
        AchievementDefinition(
            id: "focus_100",
            titleKey: "focus_100.title",
            descriptionKey: "focus_100.description",
            icon: "timer",
            tier: .volume,
            criteria: .focusMinutesTotal(100)
        ),
        AchievementDefinition(
            id: "focus_600",
            titleKey: "focus_600.title",
            descriptionKey: "focus_600.description",
            icon: "timer.circle",
            tier: .volume,
            criteria: .focusMinutesTotal(600)
        ),
        AchievementDefinition(
            id: "focus_3000",
            titleKey: "focus_3000.title",
            descriptionKey: "focus_3000.description",
            icon: "timer.circle.fill",
            tier: .volume,
            criteria: .focusMinutesTotal(3000)
        ),
    ]

    /// 连续类。
    nonisolated private static let streakTier: [AchievementDefinition] = [
        AchievementDefinition(
            id: "streak_3",
            titleKey: "streak_3.title",
            descriptionKey: "streak_3.description",
            icon: "flame",
            tier: .streak,
            criteria: .currentStreak(3)
        ),
        AchievementDefinition(
            id: "streak_7",
            titleKey: "streak_7.title",
            descriptionKey: "streak_7.description",
            icon: "flame.fill",
            tier: .streak,
            criteria: .currentStreak(7)
        ),
        AchievementDefinition(
            id: "streak_14",
            titleKey: "streak_14.title",
            descriptionKey: "streak_14.description",
            icon: "flame.circle.fill",
            tier: .streak,
            criteria: .currentStreak(14)
        ),
        AchievementDefinition(
            id: "streak_30",
            titleKey: "streak_30.title",
            descriptionKey: "streak_30.description",
            icon: "calendar.badge.checkmark",
            tier: .streak,
            criteria: .currentStreak(30)
        ),
        AchievementDefinition(
            id: "streak_100",
            titleKey: "streak_100.title",
            descriptionKey: "streak_100.description",
            icon: "calendar.badge.clock",
            tier: .streak,
            criteria: .currentStreak(100)
        ),
        AchievementDefinition(
            id: "streak_365",
            titleKey: "streak_365.title",
            descriptionKey: "streak_365.description",
            icon: "crown.fill",
            tier: .streak,
            criteria: .currentStreak(365)
        ),
    ]

    /// 累计活跃天数成就（独立于连续；断签后还会累计）。
    nonisolated private static let masteryTier: [AchievementDefinition] = [
        AchievementDefinition(
            id: "active_30",
            titleKey: "active_30.title",
            descriptionKey: "active_30.description",
            icon: "calendar",
            tier: .mastery,
            criteria: .totalActiveDays(30)
        ),
        AchievementDefinition(
            id: "active_180",
            titleKey: "active_180.title",
            descriptionKey: "active_180.description",
            icon: "calendar.circle",
            tier: .mastery,
            criteria: .totalActiveDays(180)
        ),
    ]
}

// MARK: - Catalog helpers

extension AchievementDefinition.Criteria {
    /// 该条件在给定 snapshot 下是否满足。
    /// Pure function — no side effects. Used by AchievementManager
    /// when checking whether an achievement just unlocked.
    func isSatisfied(by snapshot: AchievementsSnapshot) -> Bool {
        switch self {
        case .firstActivity:
            return snapshot.cumulative.mistakeReviews >= 1
                || snapshot.cumulative.gradesRecorded >= 1
                || snapshot.cumulative.focusMinutes >= 1
        case .goalConfigured:
            return snapshot.hasConfiguredGoals
        case .currentStreak(let n):
            return snapshot.streak.current >= n || snapshot.streak.longest >= n
        case .totalActiveDays(let n):
            return snapshot.streak.totalActiveDays >= n
        case .mistakeReviewsTotal(let n):
            return snapshot.cumulative.mistakeReviews >= n
        case .gradesRecordedTotal(let n):
            return snapshot.cumulative.gradesRecorded >= n
        case .focusMinutesTotal(let n):
            return snapshot.cumulative.focusMinutes >= n
        }
    }
}

extension AchievementDefinition {
    /// 进度显示值（用于 "5 / 7 days"）。与 catalog criteria 的目标值一一对应。
    /// `currentValue` reported in `AchievementProgress` is updated by the
    /// manager; this just returns the numerator-friendly maximum.
    var targetValue: Int {
        switch criteria {
        case .firstActivity: return 1
        case .goalConfigured: return 1
        case .currentStreak(let n): return n
        case .totalActiveDays(let n): return n
        case .mistakeReviewsTotal(let n): return n
        case .gradesRecordedTotal(let n): return n
        case .focusMinutesTotal(let n): return n
        }
    }
}