//
//  PlantState.swift
//  StudyPulse
//
//  Plant state machine for the Home plant card.
//  Defines `PlantStage` (8 cases) and the pure `derive(...)` function that
//  converts an `AchievementManager` snapshot + current date into a stage.
//
//  设计原则：
//  - 全部状态机逻辑收敛在 `PlantStage.derive` 静态方法中，便于单测覆盖所有 8 个转换。
//  - 不在 View 层或 Manager 层重写"用户今日是否活跃"逻辑——直接消费 AchievementManager 的 snapshot。
//  - 不把 rawValue 用作 UI 文案；展示走 `localizedTitle` / `localizedSubtitle`。
//

import Foundation

// MARK: - Plant Stage

/// 主页植物的 8 个生长阶段。rawValue 必须保持稳定（用于 SwiftData 持久化与本地化 key）。
/// 8 growth stages for the home plant. rawValue is the persistence & localization key.
nonisolated enum PlantStage: String, CaseIterable, Codable, Sendable, Identifiable {
    case seed      // 全新用户，尚未达成任一日目标
    case sprout    // 累计活跃天数 >= 1，streak < 7
    case bud       // 当前连续打卡 7~13 天
    case bloom     // 14~29 天
    case flourish  // 30~59 天
    case lush      // 60+ 天
    case withered  // 断签 3 天以上（任何阶段都可能进入）
    case reborn    // 曾在 withered，重新活跃（streak 重生）

    var id: String { rawValue }

    /// 视觉上的"进阶顺序"。withered/reborn 单独排，用于 animation 的 sortOrder。
    /// Visual progression order (used for animation tween). Withered/reborn are
    /// off the main axis on purpose.
    var sortOrder: Int {
        switch self {
        case .seed: return 0
        case .sprout: return 1
        case .bud: return 2
        case .bloom: return 3
        case .flourish: return 4
        case .lush: return 5
        case .withered: return -1
        case .reborn: return 1 // reborn 在视觉上与 sprout 同档
        }
    }

    /// 是否"凋零态"，影响 Canvas 灰色覆盖。
    var isWithered: Bool { self == .withered }

    /// 是否处于"进阶主线"（seed/sprout/bud/bloom/flourish/lush/reborn）。
    /// 进阶主线的 stage 才有花或花苞；withered 走特殊覆盖。
    var isProgressive: Bool {
        switch self {
        case .seed, .sprout, .bud, .bloom, .flourish, .lush, .reborn:
            return true
        case .withered:
            return false
        }
    }

    /// 是否出现花苞。bud 起出现。
    var hasBud: Bool {
        switch self {
        case .bud, .bloom, .flourish, .lush, .reborn: return true
        default: return false
        }
    }

    /// 是否绽放完整花朵。bloom 起。
    var hasBloom: Bool {
        switch self {
        case .bloom, .flourish, .lush: return true
        default: return false
        }
    }

    /// 是否出现飘动光点。flourish 起。
    var hasSparkles: Bool {
        switch self {
        case .flourish, .lush: return true
        default: return false
        }
    }

    /// 叶片数量（0-6）。sprout=2, bud=3, bloom=4, flourish=5, lush=6。
    var leafCount: Int {
        switch self {
        case .seed, .withered: return 0
        case .sprout, .reborn: return 2
        case .bud: return 3
        case .bloom: return 4
        case .flourish: return 5
        case .lush: return 6
        }
    }

    /// 茎高比例（0~1）。seed=0, lush=1。
    var stemHeightRatio: CGFloat {
        switch self {
        case .seed, .withered: return 0.05
        case .sprout, .reborn: return 0.30
        case .bud: return 0.50
        case .bloom: return 0.68
        case .flourish: return 0.82
        case .lush: return 0.95
        }
    }
}

// MARK: - Localized Display

extension PlantStage {
    /// 本地化阶段名（从 Localizable.strings 取 "plant.stage.<rawValue>.title"）。
    /// Localized stage title (key: `plant.stage.<rawValue>.title`).
    @MainActor
    var localizedTitle: String {
        "plant.stage.\(rawValue).title".localized()
    }

    /// 本地化副标题（一行小字）。
    /// Localized stage subtitle (key: `plant.stage.<rawValue>.subtitle`).
    @MainActor
    var localizedSubtitle: String {
        "plant.stage.\(rawValue).subtitle".localized()
    }
}

// MARK: - Stage Derivation (Pure Function)

extension PlantStage {
    /// 纯函数：根据 AchievementManager 提供的状态 + 当前时间，计算 plant 阶段。
    /// Pure function that maps achievement state to a plant stage. Has no side
    /// effects and is fully covered by `PlantStageTransitionsTests`.
    ///
    /// - Parameters:
    ///   - streak: 当前连续天数（AchievementManager.snapshot.streak.current）
    ///   - totalActiveDays: 累计活跃天数（streak.totalActiveDays）
    ///   - todayActive: 今日是否已达成任一日目标（todayGoalsMet）
    ///   - lastActiveDate: 上一次"达标"的日期（streak.lastActiveDate，可能为 nil）
    ///   - previouslyWithered: 上一次 derive 的结果是否处于 withered（用于 reborn 触发）
    ///   - now: 当前时间（注入便于测试）
    /// - Returns: 推算出的 PlantStage
    static func derive(
        streak: Int,
        totalActiveDays: Int,
        todayActive: Bool,
        lastActiveDate: Date?,
        previouslyWithered: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> PlantStage {
        // 1) 全新用户 → seed
        if totalActiveDays == 0 {
            return .seed
        }

        // 2) 计算"距上次活跃天数"
        let daysSinceLastActive: Int
        if let last = lastActiveDate {
            let lastDay = calendar.startOfDay(for: last)
            let today = calendar.startOfDay(for: now)
            daysSinceLastActive = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
        } else {
            daysSinceLastActive = Int.max
        }

        // 3) reborn: 之前 withered 且今天已活跃 → 重新开始
        if previouslyWithered && todayActive && daysSinceLastActive == 0 {
            return .reborn
        }

        // 4) withered: 距上次活跃 ≥ 3 天（且当前不在 withered/reborn → 避免 reborn 后立刻 withered 抖动）
        if daysSinceLastActive >= 3 && !previouslyWithered {
            return .withered
        }

        // 5) 进阶主线（按 streak.current 决定）
        switch streak {
        case ..<7:   return .sprout
        case 7..<14: return .bud
        case 14..<30: return .bloom
        case 30..<60: return .flourish
        default: return .lush
        }
    }
}

// MARK: - Plant Stage Transition

/// 阶段切换记录（用于 PlantDetailView 展示历史）。
/// A single stage-transition event stored in the snapshot history.
nonisolated struct PlantStageTransition: Codable, Equatable, Sendable, Identifiable {
    var id: UUID
    var fromStage: PlantStage
    var toStage: PlantStage
    var date: Date
    var trigger: String

    init(id: UUID = UUID(),
         fromStage: PlantStage,
         toStage: PlantStage,
         date: Date = Date(),
         trigger: String) {
        self.id = id
        self.fromStage = fromStage
        self.toStage = toStage
        self.date = date
        self.trigger = trigger
    }
}
