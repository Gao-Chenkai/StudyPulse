//
//  BodyRadarValues.swift
//  StudyPulse
//
//  6 轴雷达的归一化数值(0-1),以及卡片 UI 使用的原始值字符串和每轴颜色。
//  Normalized values (0-1) for the 6 radar axes, plus the raw value
//  strings and per-axis colors used by the card UI.
//
//  Phase 3 拆分 (2026-07-14):原 `HRVStatusCard.swift` 抽出,数据计算独立可测试。
//

import Foundation
import SwiftUI

/// 6 轴雷达的归一化数值(0-1)+ 原始值字符串 + 每轴颜色。
/// 6-axis radar normalized values (0-1) + raw value strings + per-axis colors.
struct BodyRadarValues {
    let hrv: Double
    let heartRate: Double
    let sleep: Double
    let exercise: Double
    let respiratory: Double
    let psychologicalStability: Double

    var all: [Double] { [hrv, heartRate, sleep, exercise, respiratory, psychologicalStability] }

    // Per-axis text (raw, un-normalized)
    let hrvValueText: String
    let heartRateValueText: String
    let sleepValueText: String
    let exerciseValueText: String
    let respiratoryValueText: String
    let psychologicalStabilityValueText: String

    // Per-axis colors (bad → good: red → orange → blue → green)
    let hrvColor: Color
    let heartRateColor: Color
    let sleepColor: Color
    let exerciseColor: Color
    let respiratoryColor: Color
    let psychologicalStabilityColor: Color

    /// Build radar values from the current `HRVReadiness` and
    /// `BodyStatus`. Each axis is normalized to 0-1 using the
    /// personal 30-day baseline (when there are ≥ 7 samples) or
    /// the age-adjusted reference range; missing data is treated as
    /// neutral (0.5) so the polygon doesn't collapse.
    static func compute(
        hrv: HRVReadiness,
        body: BodyStatus,
        baselines: PersonalBaselines = .empty,
        age: Int? = nil,
        mistakes: [MistakeNote] = []
    ) -> BodyRadarValues {
        let ageRef = age.map(AgeReference.compute) ?? .adult

        // HRV uses its own 14/30-day Z-score path (already exposed on
        // HRVReadiness). It does not need a personal baseline lookup
        // here because `readiness` is recomputed with its own.
        let hrvScore: Double = {
            if let z = hrv.zScore { return clamp((z + 2) / 4) }
            return 0.5
        }()
        let hrvText: String = hrv.todayHRV.map {
            String(format: "%.0f ms", $0)
        } ?? "--"

        // The remaining four signals are calibrated against the
        // personal 30-day baseline (preferred) or the age reference.
        // Sleep is calibrated against RESTORATIVE sleep (deep N3 +
        // REM), not total hours in bed — total hours determine the
        // user-facing quality label, but only deep+REM is the
        // recovery-load signal.
        let hrCal      = StudyReadinessAlgorithm.calibrated(
            value: body.restingHeartRate,
            baseline: baselines.restingHeartRate,
            range: ageRef.restingHeartRate)
        let sleepCal   = StudyReadinessAlgorithm.calibrated(
            value: body.restorativeSleepHours,
            baseline: baselines.restorativeSleepHours,
            range: ageRef.restorativeSleepHours)
        let rrCal      = StudyReadinessAlgorithm.calibrated(
            value: body.respiratoryRate,
            baseline: baselines.respiratoryRate,
            range: ageRef.respiratoryRate)
        let exerciseCal = StudyReadinessAlgorithm.calibrated(
            value: body.exerciseMinutesToday,
            baseline: baselines.exerciseMinutes,
            range: ageRef.exerciseMinutes)

        let hrText      = body.restingHeartRate.map {
            String(format: "%.0f bpm", $0)
        } ?? "--"
        // The tile shows restorative sleep (deep+REM) as the primary
        // value, with the total hours in parentheses for context.
        let sleepText: String = {
            guard let r = body.restorativeSleepHours else { return "--" }
            let total = body.lastNightSleepHours
            let totalStr = total.map { String(format: "·%.1fh", $0) } ?? ""
            return String(format: "%.1fh", r) + totalStr
        }()
        let rrText      = body.respiratoryRate.map {
            String(format: "%.0f", $0)
        } ?? "--"
        let exerciseText = body.exerciseMinutesToday.map {
            String(format: "%.0f m", $0)
        } ?? "--"

        // Psychological stability score calculation:
        // 思路:把所有"心理/思维类"错题标签列出来,每条匹配上的错题贡献 (1 - mastery),
        // 总体 stability = 1 - average(影响),即掌握度越低的心理类错题越多,stability 越低。
        // 缺数据时 stability = 1.0(默认满分)。
        let psychTags: Set<String> = [
            "概念混淆", "计算粗心", "跳步", "审题不清", "思维定势",
            "逻辑不严密", "考试焦虑", "急躁粗心", "笔误", "遗漏条件",
            "concept confusion", "careless calculation", "skipping steps",
            "misreading", "fixed thinking", "loose logic", "exam anxiety",
            "impatience", "slip of pen", "missing condition"
        ]

        let stabilityScore: Double = {
            guard !mistakes.isEmpty else { return 1.0 }
            var totalImpact = 0.0
            for m in mistakes {
                let hasPsych = m.tags.contains { tag in
                    psychTags.contains(tag.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))
                }
                if hasPsych {
                    totalImpact += (1.0 - m.masteryScore)
                }
            }
            let val = 1.0 - (totalImpact / Double(mistakes.count))
            return max(0.0, min(1.0, val))
        }()
        let stabilityText = String(format: "%.0f%%", stabilityScore * 100)

        return BodyRadarValues(
            hrv: hrvScore,
            heartRate: hrCal.score,
            sleep: sleepCal.score,
            exercise: exerciseCal.score,
            respiratory: rrCal.score,
            psychologicalStability: stabilityScore,
            hrvValueText: hrvText,
            heartRateValueText: hrText,
            sleepValueText: sleepText,
            exerciseValueText: exerciseText,
            respiratoryValueText: rrText,
            psychologicalStabilityValueText: stabilityText,
            hrvColor: colorFor(score: hrvScore),
            heartRateColor: colorFor(score: hrCal.score),
            sleepColor: colorFor(score: sleepCal.score),
            exerciseColor: colorFor(score: exerciseCal.score),
            respiratoryColor: colorFor(score: rrCal.score),
            psychologicalStabilityColor: colorFor(score: stabilityScore)
        )
    }

    private static func clamp(_ x: Double) -> Double {
        max(0, min(1, x))
    }

    private static func colorFor(score: Double) -> Color {
        switch score {
        case ..<0.34: return .red
        case ..<0.5:  return .orange
        case ..<0.75: return .blue
        default:      return .green
        }
    }
}
