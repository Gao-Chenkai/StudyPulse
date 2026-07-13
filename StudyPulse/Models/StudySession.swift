import os

import Foundation

/// 单次已完成的专注计时会话，持久化用于趋势分析。
/// A single completed study timer session, persisted for trend analysis.
struct StudySession: Codable, Identifiable, Equatable, Sendable {
    /// 唯一会话 id
    /// Unique session identifier.
    let id: UUID
    /// 会话开始时间
    /// When the session started.
    let startDate: Date
    /// 时长（秒）
    /// Duration in seconds.
    let durationSeconds: Int
    /// 会话开始时所处的强度档位
    /// The intensity tier active when the session was started.
    let intensity: SessionIntensity
    /// 是否自然完成（true）或被取消（false）
    /// Whether the session completed naturally (true) or was cancelled (false).
    let completed: Bool

    /// 专注会话强度档位。
    /// Focus session intensity tier.
    enum SessionIntensity: String, Codable, Equatable, Sendable, CaseIterable {
        case peak
        case deepFocus
        case steady
        case light
        case recovery

        /// 本地化显示名
        /// Localized display name.
        var displayName: String {
            switch self {
            case .peak: return "Peak Performance".localized()
            case .deepFocus: return "Deep Focus".localized()
            case .steady: return "Steady Rhythm".localized()
            case .light: return "Light Review".localized()
            case .recovery: return "Recovery".localized()
            }
        }

        /// SF Symbol 图标
        /// SF Symbol icon.
        var icon: String {
            switch self {
            case .peak: return "bolt.heart.fill"
            case .deepFocus: return "brain.head.profile"
            case .steady: return "chart.bar.fill"
            case .light: return "book.closed.fill"
            case .recovery: return "bed.double.fill"
            }
        }

        /// 6 位 hex (RRGGBB) 主色，用于 Live Activity / Dynamic Island。
        /// 与 StudyTimerView / StudyTimerCard 中的取值保持一致。
        /// 6-digit hex (RRGGBB) for the Live Activity / Dynamic Island
        /// accent color. Mirrors the values used in StudyTimerView /
        /// StudyTimerCard.
        var colorHex: String {
            switch self {
            case .peak: return "34C759"        // green
            case .deepFocus: return "0A84FF"    // blue
            case .steady: return "5856D6"       // indigo
            case .light: return "FF9500"        // orange
            case .recovery: return "FF3B30"     // red
            }
        }

        /// 推荐会话时长（秒），由强度档位决定。
        /// Recommended session duration in seconds based on the intensity tier.
        var recommendedDurationSeconds: Int {
            switch self {
            case .peak: return 50 * 60       // 50 min
            case .deepFocus: return 45 * 60   // 45 min
            case .steady: return 35 * 60      // 35 min
            case .light: return 25 * 60       // 25 min
            case .recovery: return 20 * 60    // 20 min
            }
        }
    }

    /// 从 `StudyIntensity`（算法层）映射到 `SessionIntensity`（持久化层）。
    /// Convert from `StudyIntensity` (algorithm) to `SessionIntensity` (persistence).
    static func fromAlgorithmIntensity(_ intensity: StudyIntensity) -> SessionIntensity {
        switch intensity {
        case .peak: return .peak
        case .deepFocus: return .deepFocus
        case .steady: return .steady
        case .light: return .light
        case .recovery: return .recovery
        }
    }
}

/// 把已完成的专注会话持久化到 `~/Documents/study_sessions.json`。
/// Persists completed study sessions to ~/Documents/study_sessions.json.
enum StudySessionStore {
    /// 持久化文件名
    /// Persistence file name.
    static let fileName = "study_sessions.json"
    /// 最多保留 90 天的会话
    /// Keep at most 90 days of sessions.
    static let retentionDays = 90

    /// 持久化文件 URL
    /// Persistence file URL.
    static func fileURL() throws -> URL {
        let dir = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return dir.appendingPathComponent(fileName)
    }

    /// 加载全部已保存的会话
    /// Load all persisted sessions.
    static func load() -> [StudySession] {
        guard let url = try? fileURL(),
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            return []
        }
        do {
            let decoded = try JSONDecoder().decode([StudySession].self, from: data)
            return decoded
        } catch {
            Log.app.error("StudySessionStore decode failed: \(error.localizedDescription)")
            return []
        }
    }

    /// 保存全部会话（自动剔除 retentionDays 之外的旧记录）
    /// Save all sessions (auto-trims to retentionDays window).
    static func save(_ sessions: [StudySession]) {
        guard let url = try? fileURL() else {
            Log.app.error("StudySessionStore save failed: cannot resolve file URL")
            return
        }
        let cutoff = Calendar.current.date(
            byAdding: .day, value: -retentionDays, to: Date()
        ) ?? Date()
        let trimmed = sessions
            .filter { $0.startDate >= cutoff }
            .sorted { $0.startDate > $1.startDate }
        do {
            let data = try JSONEncoder().encode(trimmed)
            try data.write(to: url, options: .atomic)
            Log.app.debug("Saved study sessions: count=\(trimmed.count) bytes=\(data.count)")
        } catch {
            Log.app.error("StudySessionStore save failed: \(error.localizedDescription)")
        }
    }

    /// 追加一条会话并落盘
    /// Append a new session and persist.
    @discardableResult
    static func append(_ session: StudySession) -> [StudySession] {
        var sessions = load()
        sessions.append(session)
        save(sessions)
        return sessions
    }

    /// 今日已完成专注分钟数
    /// Total completed minutes today.
    static func todayTotalMinutes() -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return load()
            .filter { $0.completed && cal.isDate($0.startDate, inSameDayAs: today) }
            .reduce(0) { $0 + $1.durationSeconds / 60 }
    }

    /// 滚动 N 天每日已完成专注分钟数（含今日）
    /// Total completed minutes over the last `days` (including today).
    static func rollingMinutes(days: Int) -> [(date: Date, minutes: Int)] {
        let cal = Calendar.current
        let all = load().filter(\.completed)
        var result: [(Date, Int)] = []
        for d in 0..<days {
            guard let date = cal.date(byAdding: .day, value: -d, to: Date()) else { continue }
            let dayStart = cal.startOfDay(for: date)
            let mins = all
                .filter { cal.isDate($0.startDate, inSameDayAs: dayStart) }
                .reduce(0) { $0 + $1.durationSeconds / 60 }
            result.append((date: dayStart, minutes: mins))
        }
        return result.reversed()
    }
}
