import Foundation

/// A bounded vocabulary for describing behavior observed during a simulated exam.
/// These are session patterns, never permanent personality traits.
nonisolated enum ExamRoleType: String, Codable, CaseIterable, Sendable {
    case firstQuestionFixation
    case overChecking
    case intuitionSkipping
    case frontSlowBackPanic
    case answerChanging
    case pressureDrop

    var displayName: String {
        switch self {
        case .firstQuestionFixation: return "首题执着型".localized()
        case .overChecking: return "过度检查型".localized()
        case .intuitionSkipping: return "凭感觉跳题型".localized()
        case .frontSlowBackPanic: return "前松后慌型".localized()
        case .answerChanging: return "改答案型".localized()
        case .pressureDrop: return "压力失忆型".localized()
        }
    }

    var symbol: String {
        switch self {
        case .firstQuestionFixation: return "lock.circle.fill"
        case .overChecking: return "checkmark.arrow.trianglehead.counterclockwise"
        case .intuitionSkipping: return "forward.fill"
        case .frontSlowBackPanic: return "timer"
        case .answerChanging: return "arrow.trianglehead.2.clockwise.rotate.90"
        case .pressureDrop: return "waveform.path.ecg"
        }
    }
}

nonisolated enum ExamSimulationStatus: String, Codable, Sendable {
    case preparing
    case running
    case grading
    case analyzing
    case completed
    case abandoned
    case analysisFailed
}

nonisolated enum ExamSimulationEventKind: String, Codable, Sendable {
    case started
    case questionEntered
    case questionLeft
    case answerChanged
    case skipped
    case submitted
    case timedOut
    case abandoned
}

/// One append-only behavior event. Times are absolute so a session can be rebuilt
/// accurately even when the app is backgrounded.
nonisolated struct ExamSimulationEvent: Identifiable, Codable, Hashable, Sendable {
    var id: UUID = UUID()
    var kind: ExamSimulationEventKind
    var timestamp: Date
    var questionId: UUID?
    var questionIndex: Int?
    var previousAnswer: String?
    var answer: String?
    var remainingSeconds: Int
}

/// Aggregated per-question behavior stored alongside the append-only event stream.
nonisolated struct ExamSimulationQuestionRecord: Identifiable, Codable, Hashable, Sendable {
    var id: UUID { question.id }
    var question: QuizQuestion
    var firstViewedAt: Date?
    var lastEnteredAt: Date?
    var lastLeftAt: Date?
    var totalViewSeconds: TimeInterval = 0
    var visitCount: Int = 0
    var skipCount: Int = 0
    var answerChangeCount: Int = 0
    var firstAnswer: String?
    var finalAnswer: String?
    var submittedAt: Date?
    var isCorrect: Bool?
    var score: Int?

    init(question: QuizQuestion) {
        self.question = question
    }
}

nonisolated struct ExamRoleEvidence: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var title: String
    var detail: String
    var questionIndex: Int?

    init(id: UUID = UUID(), title: String, detail: String, questionIndex: Int? = nil) {
        self.id = id
        self.title = title
        self.detail = detail
        self.questionIndex = questionIndex
    }

    private enum CodingKeys: String, CodingKey { case id, title, detail, questionIndex }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        detail = try container.decode(String.self, forKey: .detail)
        questionIndex = try container.decodeIfPresent(Int.self, forKey: .questionIndex)
    }
}

nonisolated struct ExamRoleAnalysis: Codable, Hashable, Sendable {
    var role: ExamRoleType
    var confidence: Double
    var evidence: [ExamRoleEvidence]
    var risk: String
    var strategies: [String]
    var isStable: Bool
    var generatedAt: Date

    init(
        role: ExamRoleType,
        confidence: Double,
        evidence: [ExamRoleEvidence],
        risk: String,
        strategies: [String],
        isStable: Bool,
        generatedAt: Date = Date()
    ) {
        self.role = role
        self.confidence = min(max(confidence, 0), 1)
        self.evidence = Array(evidence.prefix(4))
        self.risk = risk
        self.strategies = Array(strategies.prefix(4))
        self.isStable = isStable
        self.generatedAt = generatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case role, confidence, evidence, risk, strategies, isStable, generatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        role = try container.decode(ExamRoleType.self, forKey: .role)
        confidence = min(max(try container.decode(Double.self, forKey: .confidence), 0), 1)
        evidence = Array(try container.decode([ExamRoleEvidence].self, forKey: .evidence).prefix(4))
        risk = try container.decode(String.self, forKey: .risk)
        strategies = Array(try container.decode([String].self, forKey: .strategies).prefix(4))
        isStable = try container.decode(Bool.self, forKey: .isStable)
        generatedAt = try container.decodeIfPresent(Date.self, forKey: .generatedAt) ?? Date()
    }
}

nonisolated struct ExamSimulation: Identifiable, Codable, Hashable, Sendable {
    static let defaultDurationSeconds = 20 * 60
    static let defaultQuestionCount = 10

    var id: UUID
    var subject: String
    var createdAt: Date
    var startedAt: Date?
    var endedAt: Date?
    var durationSeconds: Int
    var status: ExamSimulationStatus
    var questionRecords: [ExamSimulationQuestionRecord]
    var events: [ExamSimulationEvent]
    var totalScore: Int?
    var analysis: ExamRoleAnalysis?
    var lastError: String?

    init(
        id: UUID = UUID(),
        subject: String,
        createdAt: Date = Date(),
        startedAt: Date? = nil,
        endedAt: Date? = nil,
        durationSeconds: Int = ExamSimulation.defaultDurationSeconds,
        status: ExamSimulationStatus = .preparing,
        questions: [QuizQuestion] = [],
        questionRecords: [ExamSimulationQuestionRecord]? = nil,
        events: [ExamSimulationEvent] = [],
        totalScore: Int? = nil,
        analysis: ExamRoleAnalysis? = nil,
        lastError: String? = nil
    ) {
        self.id = id
        self.subject = subject
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationSeconds = durationSeconds
        self.status = status
        self.questionRecords = questionRecords ?? questions.map(ExamSimulationQuestionRecord.init)
        self.events = events
        self.totalScore = totalScore
        self.analysis = analysis
        self.lastError = lastError
    }

    private enum CodingKeys: String, CodingKey {
        case id, subject, createdAt, startedAt, endedAt, durationSeconds
        case status, questionRecords, events, totalScore, analysis, lastError
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        subject = try container.decode(String.self, forKey: .subject)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt)
        endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
        durationSeconds = try container.decodeIfPresent(Int.self, forKey: .durationSeconds)
            ?? Self.defaultDurationSeconds
        status = try container.decodeIfPresent(ExamSimulationStatus.self, forKey: .status) ?? .preparing
        questionRecords = try container.decodeIfPresent(
            [ExamSimulationQuestionRecord].self,
            forKey: .questionRecords
        ) ?? []
        events = try container.decodeIfPresent([ExamSimulationEvent].self, forKey: .events) ?? []
        totalScore = try container.decodeIfPresent(Int.self, forKey: .totalScore)
        analysis = try container.decodeIfPresent(ExamRoleAnalysis.self, forKey: .analysis)
        lastError = try container.decodeIfPresent(String.self, forKey: .lastError)
    }

    var isValidCompletedSession: Bool {
        endedAt != nil && questionRecords.count == Self.defaultQuestionCount &&
            [.completed, .analysisFailed].contains(status)
    }

    var answeredCount: Int {
        questionRecords.filter { !($0.finalAnswer ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }
}
