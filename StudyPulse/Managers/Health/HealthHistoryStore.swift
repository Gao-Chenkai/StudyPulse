//
//  HealthHistoryStore.swift
//  StudyPulse
//
//  Persists the past 60 days of `DailyHealthSnapshot` records to
//  ~/Documents/health_history.json. Used by `HealthKitManager` to
//  build the user's 30-day personal baseline for the readiness
//  algorithm.
//

import Foundation
import os

enum HealthHistoryStore {
    nonisolated static let fileName = "health_history.json"
    /// Keep the file small; 60 days is more than enough for a stable
    /// 30-day baseline with room to spare.
    nonisolated static let retentionDays = 60

    // MARK: - File I/O

    nonisolated static func fileURL() throws -> URL {
        let dir = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return dir.appendingPathComponent(fileName)
    }

    nonisolated static func load() -> [DailyHealthSnapshot] {
        guard let url = try? fileURL(),
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            Log.healthHistory.debug("健康历史文件不存在或读取失败 / Health history file missing or unreadable, returning empty")
            return []
        }
        do {
            let decoded = try JSONDecoder().decode(
                [DailyHealthSnapshot].self, from: data)
            Log.healthHistory.info("加载健康历史成功 / Loaded health history: count=\(decoded.count, privacy: .public) bytes=\(data.count, privacy: .public)")
            return decoded
        } catch {
            Log.healthHistory.error("健康历史解码失败 / Health history decode failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    nonisolated static func save(_ snapshots: [DailyHealthSnapshot]) {
        guard let url = try? fileURL() else {
            Log.healthHistory.error("健康历史保存失败：无法解析文件 URL / Health history save failed: cannot resolve file URL")
            return
        }
        let trimmed = trimToRetention(snapshots)
        let dropped = snapshots.count - trimmed.count
        if dropped > 0 {
            Log.healthHistory.debug("健康历史已截断到保留窗口 / Health history trimmed to retention window: dropped=\(dropped, privacy: .public) kept=\(trimmed.count, privacy: .public)")
        }
        do {
            let data = try JSONEncoder().encode(trimmed)
            try data.write(to: url, options: .atomic)
            Log.healthHistory.debug("保存健康历史成功 / Saved health history: count=\(trimmed.count, privacy: .public) bytes=\(data.count, privacy: .public)")
        } catch {
            Log.healthHistory.error("健康历史保存失败 / Health history save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Merge today's snapshot into the file (per-field fallback so
    /// partial updates don't clobber earlier readings) and return the
    /// post-write history.
    @discardableResult
    nonisolated static func upsert(snapshot: DailyHealthSnapshot) -> [DailyHealthSnapshot] {
        let existing = load()
        let cal = Calendar.current
        let day = cal.startOfDay(for: snapshot.date)
        let prior = existing.first {
            cal.startOfDay(for: $0.date) == day
        }
        let merged = DailyHealthSnapshot(
            date: day,
            hrv:               snapshot.hrv               ?? prior?.hrv,
            restingHeartRate:  snapshot.restingHeartRate  ?? prior?.restingHeartRate,
            respiratoryRate:   snapshot.respiratoryRate   ?? prior?.respiratoryRate,
            sleepHours:        snapshot.sleepHours        ?? prior?.sleepHours,
            deepSleepHours:    snapshot.deepSleepHours    ?? prior?.deepSleepHours,
            remSleepHours:     snapshot.remSleepHours     ?? prior?.remSleepHours,
            exerciseMinutes:   snapshot.exerciseMinutes   ?? prior?.exerciseMinutes
        )
        var updated = existing.filter {
            cal.startOfDay(for: $0.date) != day
        }
        updated.append(merged)
        save(updated)
        let filledFields: [String] = [
            snapshot.hrv.map { _ in "hrv" },
            snapshot.restingHeartRate.map { _ in "rhr" },
            snapshot.respiratoryRate.map { _ in "rr" },
            snapshot.sleepHours.map { _ in "sleep" },
            snapshot.deepSleepHours.map { _ in "deep" },
            snapshot.remSleepHours.map { _ in "rem" },
            snapshot.exerciseMinutes.map { _ in "exercise" }
        ].compactMap { $0 }
        Log.healthHistory.debug("健康历史 upsert 完成 / Health history upsert: date=\(day, privacy: .public) filled=\(filledFields.joined(separator: ","), privacy: .public) total=\(updated.count, privacy: .public)")
        return updated
    }

    nonisolated static func trimToRetention(_ snapshots: [DailyHealthSnapshot]) -> [DailyHealthSnapshot] {
        let cutoff = Calendar.current.date(
            byAdding: .day, value: -retentionDays, to: Date()
        ) ?? Date()
        return snapshots
            .filter { $0.date >= cutoff }
            .sorted { $0.date > $1.date }
    }
}
