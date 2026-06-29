//
//  StudyReadinessAlgorithm.swift
//  StudyPulse
//
//  Multi-dimensional study-readiness algorithm.
//
//  HRV is the primary signal of autonomic recovery. The algorithm
//  scores every available signal (HRV, last-night sleep, resting
//  heart rate, respiratory rate, today's exercise, recent activity)
//  and combines them into a single (intensity, focus) recommendation,
//  plus a list of per-signal reasoning lines the user can see in the
//  suggestion card.
//
//  Each signal is calibrated against TWO references:
//    1. The user's personal 30-day mean / stddev (preferred when there
//       are at least 7 daily samples).
//    2. An age-adjusted reference range from `AgeReference` (used as
//       a fallback, so cold-start users with no history still get
//       age-appropriate scores).
//
//  Five intensities × five focus areas yield up to 25 distinct
//  recommendations; the algorithm makes a subset reachable in
//  practice (HRV acts as a hard override) and falls back to a neutral
//  "steady / balanced" recommendation for any combination that the
//  scoring rules do not explicitly cover.
//

import Foundation
import SwiftUI

// MARK: - Public Types

/// Five intensity buckets produced by the algorithm. `peak` and
/// `deepFocus` push the user toward hard material; `light` and
/// `recovery` pull back to material the body can absorb.
enum StudyIntensity: String, Equatable {
    case peak        // 巅峰发挥
    case deepFocus   // 深度学习
    case steady      // 稳态节奏
    case light       // 轻量复习
    case recovery    // 恢复为主
}

/// Focus area recommended for a given intensity. Pairs with intensity
/// to drive a unique (title, description, icon, color) combination.
enum StudyFocus: Equatable {
    case hardestSubjectFirst  // 先攻克难题
    case balancedCurriculum   // 均衡推进
    case reviewFamiliar       // 复习熟悉内容
    case mistakesAndBasics    // 错题 + 基础
    case restAndBreathe       // 休息 + 呼吸
}

/// One row shown in the study-suggestions card.
struct StudySuggestion: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let priority: Priority
    let color: Color

    enum Priority {
        case high, medium, low
    }
}

// MARK: - Calibration Inputs

/// Mean / stddev of a single signal over the user's past 30 days.
/// `nil` when the field has no data, or fewer than 1 sample.
struct PersonalBaselineStats: Equatable {
    let mean: Double
    let stdDev: Double
    let sampleCount: Int
}

/// The user's personal 30-day baselines, one per signal. Used by
/// the algorithm (and the radar chart) so a user with a naturally
/// high or low resting heart rate isn't penalized for being "out of
/// range" relative to the population average.
struct PersonalBaselines: Equatable {
    let hrv: PersonalBaselineStats?
    let restingHeartRate: PersonalBaselineStats?
    let respiratoryRate: PersonalBaselineStats?
    /// Total sleep hours baseline (kept for diagnostic / trend
    /// purposes; the algorithm itself uses `restorativeSleepHours`).
    let sleepHours: PersonalBaselineStats?
    /// Restorative sleep baseline = deep (N3) + REM hours. This is
    /// what the algorithm actually compares the user against for the
    /// "recovery sleep" axis.
    let restorativeSleepHours: PersonalBaselineStats?
    let exerciseMinutes: PersonalBaselineStats?

    static let empty = PersonalBaselines(
        hrv: nil, restingHeartRate: nil, respiratoryRate: nil,
        sleepHours: nil, restorativeSleepHours: nil, exerciseMinutes: nil
    )

    /// Compute personal baselines from a list of daily snapshots.
    /// Only non-nil values contribute to each signal's mean and
    /// standard deviation.
    nonisolated static func compute(from snapshots: [DailyHealthSnapshot]) -> PersonalBaselines {
        func stats<T: BinaryFloatingPoint>(_ values: [T]) -> PersonalBaselineStats? {
            let doubles = values.map { Double($0) }
            guard !doubles.isEmpty else { return nil }
            let mean = doubles.reduce(0, +) / Double(doubles.count)
            let variance = doubles.reduce(0) {
                $0 + pow($1 - mean, 2)
            } / Double(doubles.count)
            let stdDev = sqrt(variance)
            return PersonalBaselineStats(
                mean: mean, stdDev: stdDev, sampleCount: doubles.count
            )
        }
        let restorative = snapshots.compactMap { snap -> Double? in
            switch (snap.deepSleepHours, snap.remSleepHours) {
            case let (d?, r?): return d + r
            case let (d?, nil): return d
            case let (nil, r?): return r
            default: return nil
            }
        }
        return PersonalBaselines(
            hrv:              stats(snapshots.compactMap { $0.hrv }),
            restingHeartRate: stats(snapshots.compactMap { $0.restingHeartRate }),
            respiratoryRate:  stats(snapshots.compactMap { $0.respiratoryRate }),
            sleepHours:       stats(snapshots.compactMap { $0.sleepHours }),
            restorativeSleepHours: stats(restorative),
            exerciseMinutes:  stats(snapshots.compactMap { $0.exerciseMinutes })
        )
    }
}

/// Age-adjusted population reference range. The 0-1 calibration
/// function maps the value to a score by comparing it against the
/// range's `low` and `high` endpoints, with `mid` as the "perfect"
/// target.
struct AgeReference: Equatable {
    struct Range: Equatable {
        let low: Double    // score = 0 below this
        let mid: Double    // score = 1 here
        let high: Double   // score = 0 above this
    }
    let hrv: Range
    let restingHeartRate: Range
    let respiratoryRate: Range
    /// Total sleep hours range (kept for the user-facing "hours slept"
    /// comparison; the algorithm uses `restorativeSleepHours`).
    let sleepHours: Range
    /// Restorative sleep (deep N3 + REM) hours range. This is the
    /// actual recovery-load signal: teens need 2.5–4h, adults 1.5–3h.
    let restorativeSleepHours: Range
    let exerciseMinutes: Range

    /// Generic adult fallback. Used when `age` is unknown or the user
    /// prefers not to disclose it. `mid` is the "perfect" target;
    /// signals that should trend low (RHR) keep `mid` near the lower
    /// end, while signals that should trend high (HRV, sleep) keep
    /// `mid` near the upper-middle of the range.
    static let adult = AgeReference(
        hrv:                    Range(low: 25, mid: 60,  high: 100),
        restingHeartRate:       Range(low: 45, mid: 60,  high: 90),
        respiratoryRate:        Range(low: 10, mid: 14,  high: 20),
        sleepHours:             Range(low: 5,  mid: 7.5, high: 10),
        restorativeSleepHours:  Range(low: 1.0, mid: 2.5, high: 4.0),
        exerciseMinutes:        Range(low: 0,  mid: 30,  high: 90)
    )

    /// Age-bracketed population reference. Approximates the
    /// literature values for HRV decline with age, sleep-need guidance
    /// (NSF / WHO), and the fact that RHR is "lower-is-better within
    /// a healthy range" (so `mid` sits at the LOW end, not the middle).
    /// Restorative sleep (deep+REM) is roughly:
    ///   - young children: 3.0–5.0 h of an 8–10 h night
    ///   - teens:           2.5–4.0 h of an 8–10 h night
    ///   - adults:         1.5–3.0 h of a 7–9 h night
    ///   - older adults:   1.0–2.5 h of a 6–8 h night
    static func compute(age: Int) -> AgeReference {
        // HRV (SDNN) — generally higher in younger adults.
        let hrv: Range
        switch age {
        case ..<18:   hrv = Range(low: 35, mid: 75, high: 120)
        case 18...25: hrv = Range(low: 30, mid: 70, high: 110)
        case 26...35: hrv = Range(low: 28, mid: 60, high: 100)
        case 36...45: hrv = Range(low: 25, mid: 55, high: 90)
        case 46...55: hrv = Range(low: 22, mid: 48, high: 80)
        case 56...65: hrv = Range(low: 18, mid: 40, high: 70)
        default:      hrv = Range(low: 15, mid: 33, high: 60)
        }
        // Resting HR — lower is better. `mid` is set to a HEALTHY low
        // target (60 for teens/adults) so a value near 60 scores 1.0
        // and a value at the population mean (~70–75) scores ~0.5.
        // Teens with athletic conditioning may run 45–55, which still
        // scores well but not "perfect".
        let rhr: Range
        switch age {
        case ..<13:   rhr = Range(low: 55, mid: 70, high: 110)
        case 13...17: rhr = Range(low: 45, mid: 60, high: 100)
        default:      rhr = Range(low: 45, mid: 60, high: 90)
        }
        // Total sleep — teens need 8–10h, younger kids more, older
        // adults slightly less. Kept for the "hours slept" label.
        let sleep: Range
        switch age {
        case ..<13:   sleep = Range(low: 6,   mid: 9.5, high: 12)
        case 13...17: sleep = Range(low: 6,   mid: 8.5, high: 11)
        case 18...64: sleep = Range(low: 5.5, mid: 7.5, high: 10)
        default:      sleep = Range(low: 5,   mid: 7,   high: 9)
        }
        // Restorative sleep (deep N3 + REM) — the recovery stages.
        // Younger users spend a larger fraction of sleep in these
        // stages; older users spend less.
        let restorative: Range
        switch age {
        case ..<13:   restorative = Range(low: 1.5, mid: 3.5, high: 5.5)
        case 13...17: restorative = Range(low: 1.5, mid: 3.0, high: 4.5)
        case 18...64: restorative = Range(low: 1.0, mid: 2.5, high: 4.0)
        default:      restorative = Range(low: 0.8, mid: 2.0, high: 3.5)
        }
        // Respiratory rate and exercise target are essentially
        // age-invariant for our purposes. RR: ~14 brpm is the
        // population mean; lower is fine, higher is mild stress.
        // Exercise: 0 is sedentary, 30+ is on-target, 90+ is high.
        let rr = Range(low: 10, mid: 14, high: 20)
        let ex = Range(low: 0,  mid: 30, high: 90)
        return AgeReference(
            hrv: hrv, restingHeartRate: rhr,
            respiratoryRate: rr, sleepHours: sleep,
            restorativeSleepHours: restorative, exerciseMinutes: ex
        )
    }
}

/// Output of the calibration step. Lets the UI show the user
/// whether a value was compared to their personal baseline or to
/// the age-adjusted reference (and what it was compared to).
struct CalibratedValue: Equatable {
    let score: Double        // 0-1
    let comparedTo: Comparison
    let referenceValue: Double

    enum Comparison: Equatable {
        case personal           // user's 30-day mean
        case ageAdjusted        // population reference for their age
    }
}

// MARK: - Algorithm

/// Pure functions that turn health signals into a study recommendation.
/// No state, no SwiftUI dependencies on the view side — easy to test
/// or to call from widgets / shortcuts in the future.
enum StudyReadinessAlgorithm {

    /// Number of personal-baseline samples required before we trust it
    /// more than the age-adjusted reference. Anything below this falls
    /// back to the age-adjusted comparison.
    nonisolated static let minPersonalSamples = 7

    /// Compute the recommendation from HRV + body status. Returns `nil`
    /// when no signal is usable (e.g. monitoring disabled or both data
    /// sources still empty).
    ///
    /// - Parameters:
    ///   - hrvEnabled / hrvOnboardingCompleted / isAuthorized: gate
    ///     flags from `HealthKitManager`.
    ///   - hrv: the latest `HRVReadiness` snapshot.
    ///   - bodyStatus: today's vitals + sleep + exercise.
    ///   - baselines: the user's 30-day personal baselines (optional;
    ///     falls back to `AgeReference` when nil or under-sampled).
    ///   - age: the user's age in years, used to pick the
    ///     age-adjusted reference range. Nil → generic adult.
    static func recommend(
        hrvEnabled: Bool,
        hrvOnboardingCompleted: Bool,
        isAuthorized: Bool,
        hrv: HRVReadiness,
        bodyStatus: BodyStatus,
        baselines: PersonalBaselines = .empty,
        age: Int? = nil
    ) -> StudySuggestion? {
        guard hrvEnabled, hrvOnboardingCompleted, isAuthorized else {
            return nil
        }
        let hrvUsable = hrv.category == .excellent
            || hrv.category == .normal
            || hrv.category == .low
        guard bodyStatus.isUsable || hrvUsable else { return nil }

        let ageRef = age.map(AgeReference.compute) ?? .adult

        // --- 1. Per-signal stress level -----------------------------------
        // HRV is the primary signal of autonomic recovery.
        let hrvStress: Int = {
            switch hrv.category {
            case .excellent: return -1
            case .normal:    return 0
            case .low:       return 1
            default:         return 0
            }
        }()

        // --- Calibrated, comparable values for the other signals --------
        // Each signal is converted to a 0-1 score using the user's
        // personal 30-day baseline when available, falling back to the
        // age-adjusted reference. We then map that score to a stress
        // level for the algorithm.
        // Sleep is calibrated against RESTORATIVE sleep (deep N3 +
        // REM) — not total hours in bed — because the recovery
        // stages are what determine cognitive and physical readiness.
        let sleepCal    = calibrated(value: bodyStatus.restorativeSleepHours,
                                     baseline: baselines.restorativeSleepHours,
                                     range: ageRef.restorativeSleepHours)
        let rhrCal      = calibrated(value: bodyStatus.restingHeartRate,
                                     baseline: baselines.restingHeartRate,
                                     range: ageRef.restingHeartRate)
        let rrCal       = calibrated(value: bodyStatus.respiratoryRate,
                                     baseline: baselines.respiratoryRate,
                                     range: ageRef.respiratoryRate)
        let exerciseCal = calibrated(value: bodyStatus.exerciseMinutesToday,
                                     baseline: baselines.exerciseMinutes,
                                     range: ageRef.exerciseMinutes)

        // Sleep: low calibrated score = poor recovery = high stress.
        let sleepStress: Int = scoreToStress(sleepCal.score,
                                             lowScore: +1, highScore: -1)
        // Resting heart rate: low calibrated score = HR far from
        // healthy low target = high stress.
        let rhrStress: Int = scoreToStress(rhrCal.score,
                                           lowScore: +1, highScore: -1)
        // Respiratory rate: lower is better.
        let rrStress: Int = rrCal.score < 0.5 ? 1 : 0
        // Exercise: 30-120 min sweet spot is a stress-reliever
        // (mapped via the score — high = good, low = either zero or
        // overtraining depending on the upper end of the range).
        let exerciseStress: Int = {
            guard let ex = bodyStatus.exerciseMinutesToday else { return 0 }
            if ex > 120 { return 1 }       // overtraining penalty on top
            if ex < 30  { return 0 }       // missing is neutral
            return -1                      // 30-120 min is stress-relief
        }()

        // Recent exertion: latest HR is well above resting.
        let activityStress: Int = {
            guard let latest = bodyStatus.latestHeartRate,
                  let rhr = bodyStatus.restingHeartRate else { return 0 }
            return latest >= rhr + 25 ? 1 : 0
        }()

        // --- 2. Total stress ----------------------------------------------
        let totalStress = hrvStress + sleepStress + rhrStress
            + rrStress + activityStress + exerciseStress

        // --- 3. Intensity (HRV is the hard primary signal) ---------------
        // HRV low → at minimum "light"; with anything else also stressed,
        // escalate straight to "recovery". HRV excellent → at minimum
        // "deepFocus" so the user never gets a "rest" suggestion on a
        // strong day. To reach the top "peak" bucket the user must
        // have HRV positive AND at least two other body signals also
        // at -1 (i.e. totalStress <= -3) — a single good HRV is not
        // enough.
        let intensity: StudyIntensity
        if hrvStress >= 1 {
            intensity = totalStress >= 3 ? .recovery : .light
        } else if totalStress <= -3 {
            intensity = .peak
        } else if totalStress <= -1 {
            intensity = .deepFocus
        } else if totalStress == 0 {
            intensity = .steady
        } else if totalStress <= 2 {
            intensity = .light
        } else {
            intensity = .recovery
        }

        // --- 4. Focus area -----------------------------------------------
        let focus: StudyFocus
        switch intensity {
        case .peak:
            focus = .hardestSubjectFirst
        case .deepFocus:
            // If none of the primary recovery signals (HRV, sleep,
            // resting HR) is in a stressed state, the body can absorb
            // the hardest material; otherwise balance the load so the
            // user doesn't burn out on one weak signal. (Previously
            // this used `== 0` which incorrectly excluded the
            // "above-baseline" / -1 case.)
            let primaryStressed = hrvStress > 0 || sleepStress > 0 || rhrStress > 0
            focus = primaryStressed
                ? .balancedCurriculum
                : .hardestSubjectFirst
        case .steady:
            focus = .balancedCurriculum
        case .light:
            // If HRV is the dominant concern, mistakes/basics drill the
            // fundamentals that the body can absorb; otherwise review
            // already-familiar material to keep momentum.
            focus = hrvStress >= 1 ? .mistakesAndBasics : .reviewFamiliar
        case .recovery:
            // Strong HRV low signal + bad sleep → the body is asking for
            // rest. Without HRV data but multiple body signals stressed,
            // we still keep the user on a gentle review track.
            focus = hrvStress >= 1 && sleepStress >= 1
                ? .restAndBreathe
                : .mistakesAndBasics
        }

        // --- 5. Reasoning lines (user-visible) ---------------------------
        let reasoning = buildReasoning(
            hrv: hrv, bodyStatus: bodyStatus,
            hrvUsable: hrvUsable,
            activityStressed: activityStress > 0,
            sleepCal: sleepCal, rhrCal: rhrCal,
            rrCal: rrCal, exerciseCal: exerciseCal,
            baselines: baselines, age: age
        )

        return makeSuggestion(intensity: intensity, focus: focus,
                              reasoning: reasoning)
    }

    // MARK: - Calibration helpers

    /// Map a single signal value to a 0-1 score, preferring the user's
    /// personal 30-day baseline when there are enough samples, and
    /// falling back to the age-adjusted reference range.
    ///
    /// - Personal path: z = (value - mean) / stddev; clamp(z) to
    ///   [-2, +2]; map [-2, +2] → [0, 1].
    /// - Age path: piecewise linear against the `low`/`mid`/`high`
    ///   endpoints, peaking at `mid`.
    nonisolated static func calibrated(
        value: Double?,
        baseline: PersonalBaselineStats?,
        range: AgeReference.Range
    ) -> CalibratedValue {
        guard let v = value else {
            return CalibratedValue(score: 0.5, comparedTo: .ageAdjusted, referenceValue: range.mid)
        }
        if let b = baseline, b.sampleCount >= minPersonalSamples {
            let safeStd = max(b.stdDev, 0.0001)
            let z = (v - b.mean) / safeStd
            let clamped = max(-2, min(2, z))
            return CalibratedValue(
                score: (clamped + 2) / 4,
                comparedTo: .personal,
                referenceValue: b.mean
            )
        }
        // Age-adjusted piecewise linear around the `mid` target.
        let score: Double
        if v <= range.low || v >= range.high {
            score = 0
        } else if v <= range.mid {
            score = (v - range.low) / (range.mid - range.low)
        } else {
            score = (range.high - v) / (range.high - range.mid)
        }
        return CalibratedValue(
            score: max(0, min(1, score)),
            comparedTo: .ageAdjusted,
            referenceValue: range.mid
        )
    }

    /// Map a 0-1 calibrated score to a -1 / 0 / +1 stress level.
    /// Convention: a calibrated score of 0 means "the value is bad",
    /// a score of 1 means "the value is good" (for whichever signal
    /// the caller passed). So `lowScore` is returned when the value
    /// is bad and `highScore` when the value is good. For most
    /// "lower-is-better" signals like RHR, pass
    /// `lowScore: +1, highScore: -1`; for "higher-is-better" signals
    /// like HRV, the same convention works because HRV is fed
    /// directly through `hrv.category` and never goes through this
    /// function.
    private static func scoreToStress(
        _ score: Double, lowScore: Int, highScore: Int
    ) -> Int {
        if score < 0.34 { return lowScore }
        if score < 0.7  { return 0 }
        return highScore
    }

    // MARK: - Reasoning builder

    private static func buildReasoning(
        hrv: HRVReadiness,
        bodyStatus: BodyStatus,
        hrvUsable: Bool,
        activityStressed: Bool,
        sleepCal: CalibratedValue,
        rhrCal: CalibratedValue,
        rrCal: CalibratedValue,
        exerciseCal: CalibratedValue,
        baselines: PersonalBaselines,
        age: Int?
    ) -> [String] {
        var lines: [String] = []
        if hrvUsable, let z = hrv.zScore {
            switch hrv.category {
            case .excellent:
                lines.append(String(format: "HRV 高于基线 %@σ".localized(),
                                    String(format: "%+.1f", z)))
            case .normal:
                lines.append("HRV 在个人正常范围".localized())
            case .low:
                lines.append(String(format: "HRV 低于基线 %@σ".localized(),
                                    String(format: "%+.1f", z)))
            default: break
            }
        }
        // Each calibrated signal is annotated with the comparison
        // source so the user can tell whether a "low" reading is being
        // judged against their own history or the population range.
        // Sleep line shows RESTORATIVE sleep (deep + REM), the
        // recovery-load signal — not total hours in bed. The total
        // hours are still surfaced on the radar tile for context.
        if let restorative = bodyStatus.restorativeSleepHours {
            let deepStr = bodyStatus.deepSleepHours.map { String(format: "深 %.1fh", $0) } ?? ""
            let remStr  = bodyStatus.remSleepHours.map  { String(format: "REM %.1fh", $0) } ?? ""
            let breakdown = (deepStr.isEmpty ? "" : deepStr)
                + (deepStr.isEmpty || remStr.isEmpty ? "" : " · ")
                + (remStr.isEmpty ? "" : remStr)
            let valueText = String(format: "%.1fh", restorative)
                + (breakdown.isEmpty ? "" : " (\(breakdown))")
            lines.append(calibratedLine(
                kind: "恢复性睡眠".localized(),
                value: valueText,
                cal: sleepCal,
                baseline: baselines.restorativeSleepHours,
                formatter: { String(format: "%.1fh", $0) }
            ))
        }
        if let rhr = bodyStatus.restingHeartRate {
            lines.append(calibratedLine(
                kind: "静息心率".localized(),
                value: String(format: "%.0f bpm", rhr),
                cal: rhrCal,
                baseline: baselines.restingHeartRate,
                formatter: { String(format: "%.0f bpm", $0) }
            ))
        }
        if let rr = bodyStatus.respiratoryRate {
            lines.append(calibratedLine(
                kind: "呼吸".localized(),
                value: String(format: "%.0f 次/分", rr),
                cal: rrCal,
                baseline: baselines.respiratoryRate,
                formatter: { String(format: "%.0f 次/分", $0) }
            ))
        }
        if activityStressed {
            lines.append("近期活动后心率仍偏高".localized())
        }
        if let ex = bodyStatus.exerciseMinutesToday {
            lines.append(calibratedLine(
                kind: "今日锻炼".localized(),
                value: String(format: "%.0f min", ex),
                cal: exerciseCal,
                baseline: baselines.exerciseMinutes,
                formatter: { String(format: "%.0f min", $0) }
            ))
        }
        // Footer: which references were actually used.
        let comparisonTags = comparisonSummary(baselines: baselines, age: age)
        if !comparisonTags.isEmpty {
            lines.append(comparisonTags)
        }
        return lines
    }

    /// Format one signal as: "睡眠 6.2h — vs 你的 30 天均值 7.4h"
    private static func calibratedLine(
        kind: String,
        value: String,
        cal: CalibratedValue,
        baseline: PersonalBaselineStats?,
        formatter: (Double) -> String
    ) -> String {
        switch cal.comparedTo {
        case .personal:
            return String(
                format: "%@ %@ — 对比 30 天均值 %@".localized(),
                kind, value, formatter(baseline?.mean ?? cal.referenceValue)
            )
        case .ageAdjusted:
            return String(
                format: "%@ %@ — 暂用年龄段参考".localized(),
                kind, value
            )
        }
    }

    /// Footer line showing which calibration sources were used.
    private static func comparisonSummary(
        baselines: PersonalBaselines, age: Int?
    ) -> String {
        var parts: [String] = []
        let personalCount = [baselines.hrv, baselines.restingHeartRate,
                             baselines.respiratoryRate, baselines.sleepHours,
                             baselines.exerciseMinutes]
            .compactMap { $0 }
            .filter { $0.sampleCount >= minPersonalSamples }
            .count
        if personalCount > 0 {
            parts.append(String(
                format: "已用 30 天均值校准 %d/5 项".localized(), personalCount
            ))
        } else {
            parts.append("尚无 30 天数据,使用年龄参考".localized())
        }
        if let age = age {
            parts.append(String(format: "年龄 %d".localized(), age))
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Suggestion builder

    private static func makeSuggestion(
        intensity: StudyIntensity,
        focus: StudyFocus,
        reasoning: [String]
    ) -> StudySuggestion {
        let reasoningBlock: String = {
            guard !reasoning.isEmpty else { return "" }
            let bullets = reasoning.map { "• " + $0 }.joined(separator: "  ")
            return "\n" + "依据".localized() + "：\(bullets)"
        }()

        let title: String
        let desc: String
        let priority: StudySuggestion.Priority
        let color: Color
        let icon: String

        // The reachable (intensity, focus) combinations below are exactly
        // the ones produced by the scoring rules. The default branch is a
        // neutral fallback for the (theoretically unreachable) cases such
        // as (.peak, .restAndBreathe).
        switch (intensity, focus) {
        case (.peak, .hardestSubjectFirst):
            title = "巅峰发挥日".localized()
            desc = "今日多个身体指标同时处于积极区间,HRV 尤为突出。趁状态最好优先攻克最具挑战性的科目或完成一次完整模拟测试。".localized() + reasoningBlock
            priority = .high; color = .green; icon = "bolt.heart.fill"

        case (.deepFocus, .hardestSubjectFirst):
            title = "适合深度学习".localized()
            desc = "身体状态支持长时间专注，今天可先挑战最难的科目或完成一套高难度练习。".localized() + reasoningBlock
            priority = .high; color = .green; icon = "brain.head.profile"

        case (.deepFocus, .balancedCurriculum):
            title = "深度学习日".localized()
            desc = "整体状态良好，可安排 2-3 小时的深度学习块；按学科难度均匀分配，避免单科过度消耗。".localized() + reasoningBlock
            priority = .medium; color = .blue; icon = "brain"

        case (.steady, .balancedCurriculum):
            title = "稳态学习日".localized()
            desc = "身体信号处于中性区间，保持 1-2 小时的专注块、学科均衡推进即可。".localized() + reasoningBlock
            priority = .medium; color = .blue; icon = "chart.bar.fill"

        case (.light, .reviewFamiliar):
            title = "轻量复习日".localized()
            desc = "部分身体指标有压力。今天以复习熟悉内容、观看录播、整理笔记为主，避免新难题。".localized() + reasoningBlock
            priority = .high; color = .orange; icon = "book.closed.fill"

        case (.light, .mistakesAndBasics):
            title = "回到错题与基础".localized()
            desc = "HRV 提示恢复不足，建议以错题回顾和基础概念为主。强度低、收益高，等身体跟上再冲击新题。".localized() + reasoningBlock
            priority = .high; color = .orange; icon = "arrow.uturn.backward.circle.fill"

        case (.recovery, .mistakesAndBasics):
            title = "以恢复为主".localized()
            desc = "多个身体信号都提示今天需要降负荷。只做最轻松的错题复习和整理笔记，争取今晚提早就寝。".localized() + reasoningBlock
            priority = .high; color = .red; icon = "bed.double.fill"

        case (.recovery, .restAndBreathe):
            title = "今天以休息为主".localized()
            desc = "HRV 显著低于基线、睡眠不足，叠加呼吸或心率异常。建议先做 5 分钟呼吸练习或轻度散步，把今天让给身体。".localized() + reasoningBlock
            priority = .high; color = .red; icon = "wind"

        default:
            // Safety net for any (intensity, focus) combination the
            // scoring rules don't explicitly produce. Maps to a calm
            // "steady / balanced" suggestion.
            title = "稳态学习日".localized()
            desc = "综合身体信号暂无明显倾向。保持 1-2 小时的专注块、学科均衡推进即可。".localized() + reasoningBlock
            priority = .medium; color = .blue; icon = "chart.bar.fill"
        }

        return StudySuggestion(
            icon: icon,
            title: title,
            description: desc,
            priority: priority,
            color: color
        )
    }
}
