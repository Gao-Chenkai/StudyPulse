//
//  PlantStageTransitionsTests.swift
//  StudyPulseTests
//
//  覆盖 PlantStage.derive(...) 的全部状态机路径。Pure function，无副作用。
//  Covers every state-machine path of `PlantStage.derive(...)`. Pure function.
//

import XCTest
@testable import StudyPulse

@MainActor
final class PlantStageTransitionsTests: XCTestCase {

    // MARK: - 基础阶段

    func testFreshUserIsSeed() {
        let stage = PlantStage.derive(
            streak: 0,
            totalActiveDays: 0,
            todayActive: false,
            lastActiveDate: nil,
            previouslyWithered: false,
            now: Self.referenceNow
        )
        XCTAssertEqual(stage, .seed, "新用户应为 seed")
    }

    func testFirstActivityGoesToSprout() {
        let stage = PlantStage.derive(
            streak: 1,
            totalActiveDays: 1,
            todayActive: true,
            lastActiveDate: Self.referenceNow,
            previouslyWithered: false,
            now: Self.referenceNow
        )
        XCTAssertEqual(stage, .sprout, "首次活跃后应为 sprout")
    }

    func testSevenDayStreakGoesToBud() {
        let stage = PlantStage.derive(
            streak: 7,
            totalActiveDays: 7,
            todayActive: true,
            lastActiveDate: Self.referenceNow,
            previouslyWithered: false,
            now: Self.referenceNow
        )
        XCTAssertEqual(stage, .bud, "7 天连续应为 bud")
    }

    func testFourteenDayStreakGoesToBloom() {
        let stage = PlantStage.derive(
            streak: 14,
            totalActiveDays: 14,
            todayActive: true,
            lastActiveDate: Self.referenceNow,
            previouslyWithered: false,
            now: Self.referenceNow
        )
        XCTAssertEqual(stage, .bloom, "14 天连续应为 bloom")
    }

    func testThirtyDayStreakGoesToFlourish() {
        let stage = PlantStage.derive(
            streak: 30,
            totalActiveDays: 30,
            todayActive: true,
            lastActiveDate: Self.referenceNow,
            previouslyWithered: false,
            now: Self.referenceNow
        )
        XCTAssertEqual(stage, .flourish, "30 天连续应为 flourish")
    }

    func testSixtyDayStreakGoesToLush() {
        let stage = PlantStage.derive(
            streak: 60,
            totalActiveDays: 60,
            todayActive: true,
            lastActiveDate: Self.referenceNow,
            previouslyWithered: false,
            now: Self.referenceNow
        )
        XCTAssertEqual(stage, .lush, "60 天连续应为 lush")
    }

    // MARK: - 凋零 / 重生

    func testThreeDaysInactiveGoesToWithered() {
        // 当前是 sprout,但最后活跃 4 天前
        let lastActive = Self.daysAgo(4)
        let stage = PlantStage.derive(
            streak: 1,
            totalActiveDays: 10,
            todayActive: false,
            lastActiveDate: lastActive,
            previouslyWithered: false,
            now: Self.referenceNow
        )
        XCTAssertEqual(stage, .withered, "3+ 天未活跃应进入 withered")
    }

    func testWitheredToRebornAfterActivity() {
        // 之前 withered,今天又有活动
        let stage = PlantStage.derive(
            streak: 0,
            totalActiveDays: 5,
            todayActive: true,
            lastActiveDate: Self.referenceNow,
            previouslyWithered: true,
            now: Self.referenceNow
        )
        XCTAssertEqual(stage, .reborn, "withered + 今日活跃 → reborn")
    }

    func testRebornStreakClimbsBackToSprout() {
        // reborn 之后,如果继续 1 天活跃(streak<7),应保持 sprout
        let stage = PlantStage.derive(
            streak: 3,
            totalActiveDays: 8,
            todayActive: true,
            lastActiveDate: Self.referenceNow,
            previouslyWithered: false, // 已经过了 reborn 这次 derive
            now: Self.referenceNow
        )
        XCTAssertEqual(stage, .sprout, "reborn 之后 streak 上升未达 7 → 仍为 sprout")
    }

    // MARK: - 边界 / 稳定性

    func testWitheredDoesNotFlickerAtThreeDayBoundary() {
        // 距 last active 正好 3 天:应进入 withered
        let lastActive = Self.daysAgo(3)
        let stage = PlantStage.derive(
            streak: 5,
            totalActiveDays: 10,
            todayActive: false,
            lastActiveDate: lastActive,
            previouslyWithered: false,
            now: Self.referenceNow
        )
        XCTAssertEqual(stage, .withered, "距上次活跃 3 天整:进入 withered")
    }

    func testTwoDaysInactiveStaysProgressive() {
        // 距 last active 2 天:不应 withered
        let lastActive = Self.daysAgo(2)
        let stage = PlantStage.derive(
            streak: 8,
            totalActiveDays: 12,
            todayActive: true,
            lastActiveDate: lastActive,
            previouslyWithered: false,
            now: Self.referenceNow
        )
        XCTAssertEqual(stage, .bud, "2 天未活跃但今日已 active:仍为 bud")
    }

    func testStageRawValuesAreStable() {
        // 持久化契约:rawValue 不能变
        XCTAssertEqual(PlantStage.seed.rawValue, "seed")
        XCTAssertEqual(PlantStage.sprout.rawValue, "sprout")
        XCTAssertEqual(PlantStage.bud.rawValue, "bud")
        XCTAssertEqual(PlantStage.bloom.rawValue, "bloom")
        XCTAssertEqual(PlantStage.flourish.rawValue, "flourish")
        XCTAssertEqual(PlantStage.lush.rawValue, "lush")
        XCTAssertEqual(PlantStage.withered.rawValue, "withered")
        XCTAssertEqual(PlantStage.reborn.rawValue, "reborn")
    }

    func testNewlyWitheredDoesNotImmediatelyRevive() {
        // reborn 仅在 previouslyWithered + todayActive + daysSinceLastActive == 0 时触发
        // 但如果 previouslyWithered 且 daysSinceLastActive >= 3: 不会 reborn,会保持 withered
        // 因为 daysSinceLastActive 不为 0
        let stage = PlantStage.derive(
            streak: 0,
            totalActiveDays: 3,
            todayActive: true,
            lastActiveDate: Self.daysAgo(5),
            previouslyWithered: true,
            now: Self.referenceNow
        )
        XCTAssertNotEqual(stage, .reborn, "lastActive 与 now 差 ≥1:不应 reborn")
    }

    func testAllCasesHaveLeafAndStemConfiguration() {
        // 视觉契约:所有阶段都需要可绘制
        for stage in PlantStage.allCases {
            XCTAssertGreaterThanOrEqual(stage.leafCount, 0)
            XCTAssertGreaterThanOrEqual(stage.stemHeightRatio, 0)
            XCTAssertLessThanOrEqual(stage.stemHeightRatio, 1)
        }
    }

    // MARK: - Fixtures

    private static let referenceNow: Date = {
        var components = DateComponents()
        components.year = 2026; components.month = 6; components.day = 15
        components.hour = 12
        return Calendar(identifier: .gregorian).date(from: components) ?? Date()
    }()

    private static func daysAgo(_ n: Int) -> Date {
        Calendar(identifier: .gregorian).date(byAdding: .day, value: -n, to: referenceNow) ?? referenceNow
    }
}
