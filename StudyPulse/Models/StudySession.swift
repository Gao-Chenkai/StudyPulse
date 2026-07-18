import os

import Foundation

/// 单次心率采样点（Apple Watch 通过 HealthKit 写入）。
/// A single heart-rate sample written by Apple Watch via HealthKit.
struct HeartRateSample: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    let timestamp: Date
    let bpm: Double
}

/// 学习会话中遇到的难题标注（用户在心率峰值处手动登记）。
/// A difficulty annotation logged by the user at a high-heart-rate point
/// during a study session.
struct DifficultyAnnotation: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    /// 在会话时间轴上的位置
    /// Position on the session timeline.
    let timestamp: Date
    /// 标注时的心率（若有）
    /// Heart rate at the annotation moment, if available.
    let heartRate: Double?
    /// 用户输入的难题描述
    /// User-entered description of the difficulty encountered.
    let note: String
    /// 可选关联学科
    /// Optional associated subject id.
    let subjectId: UUID?
}

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
    /// 会话期间采集的心率样本（仅自然完成且开启采集时存在）
    /// Heart-rate samples collected during the session (only present when
    /// the session completed naturally and streaming was enabled).
    let heartRateSamples: [HeartRateSample]?
    /// 用户在心率峰值处登记的难题标注
    /// Difficulty annotations logged by the user at high-HR points.
    let difficultyAnnotations: [DifficultyAnnotation]?

    /// 成员初始化器
    /// Memberwise initializer.
    nonisolated init(
        id: UUID,
        startDate: Date,
        durationSeconds: Int,
        intensity: SessionIntensity,
        completed: Bool,
        heartRateSamples: [HeartRateSample]? = nil,
        difficultyAnnotations: [DifficultyAnnotation]? = nil
    ) {
        self.id = id
        self.startDate = startDate
        self.durationSeconds = durationSeconds
        self.intensity = intensity
        self.completed = completed
        self.heartRateSamples = heartRateSamples
        self.difficultyAnnotations = difficultyAnnotations
    }

    /// 自定义解码器:新字段用 decodeIfPresent 兜底,保证旧 JSON 兼容。
    /// Custom decoder: new fields use decodeIfPresent so legacy JSON
    /// without them decodes without throwing.
    private enum CodingKeys: String, CodingKey {
        case id, startDate, durationSeconds, intensity, completed
        case heartRateSamples, difficultyAnnotations
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        startDate = try c.decode(Date.self, forKey: .startDate)
        durationSeconds = try c.decode(Int.self, forKey: .durationSeconds)
        intensity = try c.decode(SessionIntensity.self, forKey: .intensity)
        completed = try c.decode(Bool.self, forKey: .completed)
        heartRateSamples = try c.decodeIfPresent([HeartRateSample].self, forKey: .heartRateSamples)
        difficultyAnnotations = try c.decodeIfPresent([DifficultyAnnotation].self, forKey: .difficultyAnnotations)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(startDate, forKey: .startDate)
        try c.encode(durationSeconds, forKey: .durationSeconds)
        try c.encode(intensity, forKey: .intensity)
        try c.encode(completed, forKey: .completed)
        try c.encodeIfPresent(heartRateSamples, forKey: .heartRateSamples)
        try c.encodeIfPresent(difficultyAnnotations, forKey: .difficultyAnnotations)
    }

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
    nonisolated static func fromAlgorithmIntensity(_ intensity: StudyIntensity) -> SessionIntensity {
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
    nonisolated static let fileName = "study_sessions.json"
    /// 最多保留 90 天的会话
    /// Keep at most 90 days of sessions.
    nonisolated static let retentionDays = 90

    /// 持久化文件 URL
    /// Persistence file URL.
    nonisolated static func fileURL() throws -> URL {
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
    nonisolated static func load() -> [StudySession] {
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
    nonisolated static func save(_ sessions: [StudySession]) {
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
    nonisolated static func append(_ session: StudySession) -> [StudySession] {
        var sessions = load()
        sessions.append(session)
        save(sessions)
        return sessions
    }

    /// 通用更新:按 id 替换会话并落盘
    /// Replace a session by id and persist.
    @discardableResult
    nonisolated static func updateSession(_ updated: StudySession) -> [StudySession] {
        var sessions = load()
        guard let idx = sessions.firstIndex(where: { $0.id == updated.id }) else {
            return sessions
        }
        sessions[idx] = updated
        save(sessions)
        return sessions
    }

    /// 仅更新某条会话的难题标注
    /// Update only the difficulty annotations of a session by id.
    @discardableResult
    nonisolated static func updateAnnotations(sessionId: UUID, annotations: [DifficultyAnnotation]) -> [StudySession] {
        var sessions = load()
        guard let idx = sessions.firstIndex(where: { $0.id == sessionId }) else {
            return sessions
        }
        sessions[idx] = StudySession(
            id: sessions[idx].id,
            startDate: sessions[idx].startDate,
            durationSeconds: sessions[idx].durationSeconds,
            intensity: sessions[idx].intensity,
            completed: sessions[idx].completed,
            heartRateSamples: sessions[idx].heartRateSamples,
            difficultyAnnotations: annotations
        )
        save(sessions)
        return sessions
    }

    /// 提取最近 N 天内所有会话的难题标注(扁平化)
    /// Flatten all difficulty annotations from sessions within the last `days`.
    nonisolated static func recentAnnotations(days: Int = 7) -> [DifficultyAnnotation] {
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return load()
            .filter { $0.startDate >= cutoff }
            .flatMap { $0.difficultyAnnotations ?? [] }
    }

    /// 今日已完成专注分钟数
    /// Total completed minutes today.
    nonisolated static func todayTotalMinutes() -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return load()
            .filter { $0.completed && cal.isDate($0.startDate, inSameDayAs: today) }
            .reduce(0) { $0 + $1.durationSeconds / 60 }
    }

    /// 滚动 N 天每日已完成专注分钟数（含今日）
    /// Total completed minutes over the last `days` (including today).
    nonisolated static func rollingMinutes(days: Int) -> [(date: Date, minutes: Int)] {
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
