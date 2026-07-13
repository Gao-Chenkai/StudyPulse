//
//  HealthHistory.swift
//  StudyPulse
//
//  身体信号的单日快照；由 HealthHistoryStore 持久化，
//  用于 readiness 算法结合用户个人 30 天均值/标准差做校准，
//  个人数据不足时回退到按年龄调整的参考区间。
//
//  One-day snapshot of body signals. Persisted by
//  `HealthHistoryStore` so the readiness algorithm can calibrate its
//  scores against the user's personal 30-day mean / standard
//  deviation, with an age-adjusted reference range as a fallback
//  when there isn't enough personal data yet.
//

import Foundation

/// 单个日历日的身体信号汇总。任一字段为 nil 表示该日无 HealthKit 样本。
/// Aggregate body-signal data for a single calendar day. Any field
/// may be `nil` when no HealthKit sample was found for that day.
nonisolated struct DailyHealthSnapshot: Codable, Equatable, Identifiable {
    /// 当日起点，本地时区。同时作为持久化 key 和 Identifiable id。
    /// Start-of-day, local time. Used as both the persistence key and
    /// the `Identifiable` id.
    let date: Date
    /// 当日首个 HRV (SDNN) 样本，单位毫秒。
    /// First HRV (SDNN) sample of the day, in milliseconds.
    let hrv: Double?
    /// 当日最近一次静息心率，单位 bpm。
    /// Most recent resting heart rate of the day, in bpm.
    let restingHeartRate: Double?
    /// 当日最近一次呼吸频率，单位 breaths/min。
    /// Most recent respiratory rate of the day, in breaths/min.
    let respiratoryRate: Double?
    /// 当晚睡眠总时长（次日早晨结束的回溯 18 小时窗口）。
    /// Total sleep hours that night (sleep that ended in the morning
    /// of this day, looking back 18 hours).
    let sleepHours: Double?
    /// 当晚深度睡眠（N3 / 慢波）时长。最具生理恢复力的阶段。
    /// Deep sleep (N3 / slow-wave sleep) hours that night. The
    /// physically most restorative stage.
    let deepSleepHours: Double?
    /// 当晚 REM 睡眠时长。负责记忆巩固的认知恢复阶段。
    /// REM sleep hours that night. The cognitively restorative stage
    /// responsible for memory consolidation.
    let remSleepHours: Double?
    /// 当日 Apple Exercise Time 总分钟数。
    /// Total Apple Exercise Time for the day, in minutes.
    let exerciseMinutes: Double?

    var id: Date { date }

    // 向后兼容：`~/Documents/health_history.json` 中在 deep/REM 字段添加之前
    // 写入的旧文件，自定义 decoder 让它们加载时不会丢新字段。
    // Backwards-compat: older JSON files in `~/Documents/health_history.json`
    // were persisted before deep/REM fields existed. Custom decoding lets
    // those files load without losing the new fields.
    private enum CodingKeys: String, CodingKey {
        case date, hrv, restingHeartRate, respiratoryRate,
             sleepHours, deepSleepHours, remSleepHours, exerciseMinutes
    }
    init(date: Date, hrv: Double?, restingHeartRate: Double?,
         respiratoryRate: Double?, sleepHours: Double?,
         deepSleepHours: Double?, remSleepHours: Double?,
         exerciseMinutes: Double?) {
        self.date = date
        self.hrv = hrv
        self.restingHeartRate = restingHeartRate
        self.respiratoryRate = respiratoryRate
        self.sleepHours = sleepHours
        self.deepSleepHours = deepSleepHours
        self.remSleepHours = remSleepHours
        self.exerciseMinutes = exerciseMinutes
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.date = try c.decode(Date.self, forKey: .date)
        self.hrv = try c.decodeIfPresent(Double.self, forKey: .hrv)
        self.restingHeartRate = try c.decodeIfPresent(Double.self, forKey: .restingHeartRate)
        self.respiratoryRate = try c.decodeIfPresent(Double.self, forKey: .respiratoryRate)
        self.sleepHours = try c.decodeIfPresent(Double.self, forKey: .sleepHours)
        self.deepSleepHours = try c.decodeIfPresent(Double.self, forKey: .deepSleepHours)
        self.remSleepHours = try c.decodeIfPresent(Double.self, forKey: .remSleepHours)
        self.exerciseMinutes = try c.decodeIfPresent(Double.self, forKey: .exerciseMinutes)
    }
}
