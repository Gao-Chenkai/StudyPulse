//
//  PlantStateRecord.swift
//  StudyPulse
//
//  SwiftData @Model for persisting the home plant's stage + history + debug override.
//  Singleton semantics: at most one record per device (singleton enforced by the
//  `migratePlantStateIfNeeded` factory and the `attach` bootstrap).
//

import Foundation
import SwiftData

// MARK: - PlantState (value-type mirror)

/// 值类型镜像，便于跨 actor 传递与单测。
/// Value-type mirror of the SwiftData record; safe to pass around.
nonisolated struct PlantState: Codable, Equatable, Sendable {
    /// 当前阶段（持久化以 rawValue 存）
    var currentStage: PlantStage
    /// 阶段切换历史（最近 50 条）
    var history: [PlantStageTransition]
    /// 最近一次阶段更新时间
    var lastUpdated: Date
    /// Debug 强制覆盖（nil = 跟随 derive 逻辑；非 nil = Debug 锁定到该阶段）
    var forceOverride: PlantStage?
    /// 上一次 recordActivity 触达的时间
    var lastActivityAt: Date?
    /// Debug 模拟 streak（nil = 不覆盖）
    var simulatedStreak: Int?
    /// Debug 模拟 lastActiveDate（nil = 不覆盖）
    var simulatedLastActiveDate: Date?

    init(currentStage: PlantStage = .seed,
         history: [PlantStageTransition] = [],
         lastUpdated: Date = Date(),
         forceOverride: PlantStage? = nil,
         lastActivityAt: Date? = nil,
         simulatedStreak: Int? = nil,
         simulatedLastActiveDate: Date? = nil) {
        self.currentStage = currentStage
        self.history = history
        self.lastUpdated = lastUpdated
        self.forceOverride = forceOverride
        self.lastActivityAt = lastActivityAt
        self.simulatedStreak = simulatedStreak
        self.simulatedLastActiveDate = simulatedLastActiveDate
    }
}

// MARK: - PlantStateRecord (SwiftData)

@Model
final class PlantStateRecord {
    @Attribute(.unique) var id: UUID
    /// 持久化以 rawValue 字符串
    var currentStageRaw: String
    /// 历史 JSON 编码（避免嵌套 @Model）
    var historyData: Data?
    var lastUpdated: Date
    /// Debug 强制覆盖 rawValue（nil = 不覆盖）
    var forceOverrideRaw: String?
    /// 上一次 recordActivity 触达时间
    var lastActivityAt: Date?
    /// 上一次 derive 输入快照（用于 reborn 判定：previouslyWithered）
    /// Previous derive stage (used to detect withered → reborn).
    var previousStageRaw: String
    /// Debug 模拟：临时把 streak 覆盖为这个值（nil = 不覆盖）
    var simulatedStreakOverride: Int?
    /// Debug 模拟：临时把 lastActiveDate 覆盖为这个值（nil = 不覆盖）
    var simulatedLastActiveDate: Date?

    init(
        id: UUID = UUID(),
        currentStageRaw: String,
        historyData: Data? = nil,
        lastUpdated: Date = Date(),
        forceOverrideRaw: String? = nil,
        lastActivityAt: Date? = nil,
        previousStageRaw: String,
        simulatedStreakOverride: Int? = nil,
        simulatedLastActiveDate: Date? = nil
    ) {
        self.id = id
        self.currentStageRaw = currentStageRaw
        self.historyData = historyData
        self.lastUpdated = lastUpdated
        self.forceOverrideRaw = forceOverrideRaw
        self.lastActivityAt = lastActivityAt
        self.previousStageRaw = previousStageRaw
        self.simulatedStreakOverride = simulatedStreakOverride
        self.simulatedLastActiveDate = simulatedLastActiveDate
    }

    convenience init(from snapshot: PlantState, previousStage: PlantStage) {
        let data: Data? = snapshot.history.isEmpty
            ? nil
            : try? JSONEncoder().encode(snapshot.history)
        self.init(
            id: UUID(),
            currentStageRaw: snapshot.currentStage.rawValue,
            historyData: data,
            lastUpdated: snapshot.lastUpdated,
            forceOverrideRaw: snapshot.forceOverride?.rawValue,
            lastActivityAt: snapshot.lastActivityAt,
            previousStageRaw: previousStage.rawValue,
            simulatedStreakOverride: snapshot.simulatedStreak,
            simulatedLastActiveDate: snapshot.simulatedLastActiveDate
        )
    }

    func toSnapshot() -> PlantState {
        let history: [PlantStageTransition] = {
            guard let data = historyData else { return [] }
            return (try? JSONDecoder().decode([PlantStageTransition].self, from: data)) ?? []
        }()
        return PlantState(
            currentStage: PlantStage(rawValue: currentStageRaw) ?? .seed,
            history: history,
            lastUpdated: lastUpdated,
            forceOverride: forceOverrideRaw.flatMap(PlantStage.init(rawValue:)),
            lastActivityAt: lastActivityAt,
            simulatedStreak: simulatedStreakOverride,
            simulatedLastActiveDate: simulatedLastActiveDate
        )
    }

    /// 暴露 previousStage 用于下次 derive 计算 previouslyWithered。
    var previousStage: PlantStage {
        PlantStage(rawValue: previousStageRaw) ?? .seed
    }
}
