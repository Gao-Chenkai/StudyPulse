//
//  HealthHistory.swift
//  StudyPulse
//
//  One-day snapshot of body signals. Persisted by
//  `HealthHistoryStore` so the readiness algorithm can calibrate its
//  scores against the user's personal 30-day mean / standard
//  deviation, with an age-adjusted reference range as a fallback
//  when there isn't enough personal data yet.
//

import Foundation

/// Aggregate body-signal data for a single calendar day. Any field
/// may be `nil` when no HealthKit sample was found for that day.
nonisolated struct DailyHealthSnapshot: Codable, Equatable, Identifiable {
    /// Start-of-day, local time. Used as both the persistence key and
    /// the `Identifiable` id.
    let date: Date
    /// First HRV (SDNN) sample of the day, in milliseconds.
    let hrv: Double?
    /// Most recent resting heart rate of the day, in bpm.
    let restingHeartRate: Double?
    /// Most recent respiratory rate of the day, in breaths/min.
    let respiratoryRate: Double?
    /// Total sleep hours that night (sleep that ended in the morning
    /// of this day, looking back 18 hours).
    let sleepHours: Double?
    /// Deep sleep (N3 / slow-wave sleep) hours that night. The
    /// physically most restorative stage.
    let deepSleepHours: Double?
    /// REM sleep hours that night. The cognitively restorative stage
    /// responsible for memory consolidation.
    let remSleepHours: Double?
    /// Total Apple Exercise Time for the day, in minutes.
    let exerciseMinutes: Double?

    var id: Date { date }

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
