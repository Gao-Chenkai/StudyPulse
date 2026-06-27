import os

import Foundation

/// A single completed study timer session, persisted for trend analysis.
struct StudySession: Codable, Identifiable, Equatable, Sendable {
    /// Unique session identifier.
    let id: UUID
    /// When the session started.
    let startDate: Date
    /// Duration in seconds.
    let durationSeconds: Int
    /// The intensity tier active when the session was started.
    let intensity: SessionIntensity
    /// Whether the session completed naturally (true) or was cancelled (false).
    let completed: Bool

    enum SessionIntensity: String, Codable, Equatable, Sendable {
        case peak
        case deepFocus
        case steady
        case light
        case recovery

        var displayName: String {
            switch self {
            case .peak: return "Peak Performance".localized()
            case .deepFocus: return "Deep Focus".localized()
            case .steady: return "Steady Rhythm".localized()
            case .light: return "Light Review".localized()
            case .recovery: return "Recovery".localized()
            }
        }

        var icon: String {
            switch self {
            case .peak: return "bolt.heart.fill"
            case .deepFocus: return "brain.head.profile"
            case .steady: return "chart.bar.fill"
            case .light: return "book.closed.fill"
            case .recovery: return "bed.double.fill"
            }
        }

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

/// Persists completed study sessions to ~/Documents/study_sessions.json.
enum StudySessionStore {
    static let fileName = "study_sessions.json"
    /// Keep at most 90 days of sessions.
    static let retentionDays = 90

    static func fileURL() throws -> URL {
        let dir = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return dir.appendingPathComponent(fileName)
    }

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

    /// Append a new session and persist.
    @discardableResult
    static func append(_ session: StudySession) -> [StudySession] {
        var sessions = load()
        sessions.append(session)
        save(sessions)
        return sessions
    }

    /// Total completed minutes today.
    static func todayTotalMinutes() -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return load()
            .filter { $0.completed && cal.isDate($0.startDate, inSameDayAs: today) }
            .reduce(0) { $0 + $1.durationSeconds / 60 }
    }

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
