//
//  AchievementStore.swift
//  StudyPulse
//
//  成就快照的持久化层。
//  Persistence for `AchievementsSnapshot` → ~/Documents/achievements.json.
//
//  设计模式与 HealthHistoryStore 完全一致：fileURL + load + save + 滚动窗口。
//  AchievementsSnapshot 是单一 JSON 根；logs 字段独立做 90 天滚动。
//

import Foundation
import os

/// `AchievementsSnapshot` 的文件持久化。
enum AchievementStore {
    static let fileName = "achievements.json"
    /// logs 字段的滚动窗口。90 天足以覆盖成就回填和近期趋势分析。
    static let logsRetentionDays = 90

    // MARK: - File I/O

    static func fileURL() throws -> URL {
        let dir = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return dir.appendingPathComponent(fileName)
    }

    static func load() -> AchievementsSnapshot {
        guard let url = try? fileURL(),
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            Log.achievement.debug("成就快照文件不存在或读取失败 / Achievements snapshot missing or unreadable, returning empty")
            return .empty
        }
        do {
            let decoded = try JSONDecoder().decode(AchievementsSnapshot.self, from: data)
            Log.achievement.info("加载成就快照成功 / Loaded achievements snapshot: version=\(decoded.version, privacy: .public) logs=\(decoded.logs.count, privacy: .public) achievements=\(decoded.achievements.count, privacy: .public)")
            return decoded
        } catch {
            Log.achievement.error("成就快照解码失败 / Achievements snapshot decode failed: \(error.localizedDescription, privacy: .public)")
            return .empty
        }
    }

    static func save(_ snapshot: AchievementsSnapshot) {
        guard let url = try? fileURL() else {
            Log.achievement.error("成就快照保存失败：无法解析文件 URL / Achievements snapshot save failed: cannot resolve file URL")
            return
        }
        // logs 单独做 90 天滚动；其他字段原样保存。
        var trimmed = snapshot
        let beforeCount = trimmed.logs.count
        trimmed.logs = trimLogsToRetention(trimmed.logs)
        let dropped = beforeCount - trimmed.logs.count
        if dropped > 0 {
            Log.achievement.debug("成就日志已截断到保留窗口 / Achievement logs trimmed to retention window: dropped=\(dropped, privacy: .public) kept=\(trimmed.logs.count, privacy: .public)")
        }
        do {
            let data = try JSONEncoder().encode(trimmed)
            try data.write(to: url, options: .atomic)
            Log.achievement.debug("保存成就快照成功 / Saved achievements snapshot: bytes=\(data.count, privacy: .public)")
        } catch {
            Log.achievement.error("成就快照保存失败 / Achievements snapshot save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 按日期（startOfDay）合并当日日志条目，返回合并后的 logs 数组。
    /// 同一日多次累加：mistakeReviews / gradesRecorded / focusMinutes 全部相加。
    @discardableResult
    static func upsertLog(_ log: DailyActivityLog, into logs: [DailyActivityLog]) -> [DailyActivityLog] {
        let cal = Calendar.current
        let day = cal.startOfDay(for: log.date)
        var working = logs.filter { cal.startOfDay(for: $0.date) != day }
        if let prior = logs.first(where: { cal.startOfDay(for: $0.date) == day }) {
            let merged = DailyActivityLog(
                date: day,
                mistakeReviews: prior.mistakeReviews + log.mistakeReviews,
                gradesRecorded: prior.gradesRecorded + log.gradesRecorded,
                focusMinutes: prior.focusMinutes + log.focusMinutes
            )
            working.append(merged)
        } else {
            working.append(DailyActivityLog(
                date: day,
                mistakeReviews: log.mistakeReviews,
                gradesRecorded: log.gradesRecorded,
                focusMinutes: log.focusMinutes
            ))
        }
        return working.sorted { $0.date < $1.date }
    }

    /// 按日期降序返回最近的 N 条日志（含今日）。
    static func recentLogs(_ logs: [DailyActivityLog], days: Int) -> [DailyActivityLog] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let cutoff = cal.date(byAdding: .day, value: -(days - 1), to: today) else {
            return logs
        }
        return logs.filter { $0.date >= cutoff }.sorted { $0.date > $1.date }
    }

    static func trimLogsToRetention(_ logs: [DailyActivityLog]) -> [DailyActivityLog] {
        let cutoff = Calendar.current.date(
            byAdding: .day, value: -logsRetentionDays, to: Date()
        ) ?? Date()
        return logs
            .filter { $0.date >= cutoff }
            .sorted { $0.date > $1.date }
    }

    /// 删除持久化文件。仅供调试 / DataAdminView 使用。
    static func reset() {
        guard let url = try? fileURL() else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
            Log.achievement.info("成就快照已重置 / Achievements snapshot reset")
        }
    }
}