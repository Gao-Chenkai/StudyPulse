import Foundation

// MARK: - AI Coach domain models

nonisolated enum CoachMessageRole: String, Codable, Hashable, Sendable {
    case user, assistant
}

nonisolated struct CoachChat: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let goalID: UUID?
    var title: String
    var isArchived: Bool
    let createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), goalID: UUID? = nil, title: String = "New chat",
         isArchived: Bool = false, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id; self.goalID = goalID; self.title = title
        self.isArchived = isArchived; self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}

nonisolated enum CoachTodoSuggestionStatus: String, Codable, Hashable, Sendable {
    case pending, added, dismissed
}

nonisolated struct CoachTodoSuggestion: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    var title: String
    var subject: String
    var startDate: Date
    var dueDate: Date
    var importance: Int
    var notes: String
    var objective: String
    /// The Todo kind selected by the coach. Kept optional in the wire format for backwards compatibility.
    var taskType: TaskType
    var stopCondition: CoachStopCondition
    var status: CoachTodoSuggestionStatus
    var taskID: UUID?

    private enum CodingKeys: String, CodingKey {
        case id, title, subject, startDate, dueDate, importance, notes, objective, taskType, type
        case stopCondition, status, taskID
    }

    init(id: UUID = UUID(), title: String, subject: String = "", startDate: Date,
         dueDate: Date, importance: Int = 3, notes: String = "", objective: String = "",
         taskType: TaskType = .homework,
         stopCondition: CoachStopCondition, status: CoachTodoSuggestionStatus = .pending,
         taskID: UUID? = nil) {
        self.id = id; self.title = title; self.subject = subject
        self.startDate = startDate; self.dueDate = dueDate
        self.importance = min(5, max(1, importance)); self.notes = notes; self.objective = objective
        self.taskType = taskType
        self.stopCondition = stopCondition; self.status = status; self.taskID = taskID
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let decodedTaskType = try c.decodeIfPresent(TaskType.self, forKey: .taskType)
        let legacyTaskType = try c.decodeIfPresent(TaskType.self, forKey: .type)
        self.init(
            id: try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            title: try c.decode(String.self, forKey: .title),
            subject: try c.decodeIfPresent(String.self, forKey: .subject) ?? "",
            startDate: try c.decode(Date.self, forKey: .startDate),
            dueDate: try c.decode(Date.self, forKey: .dueDate),
            importance: try c.decodeIfPresent(Int.self, forKey: .importance) ?? 3,
            notes: try c.decodeIfPresent(String.self, forKey: .notes) ?? "",
            objective: try c.decodeIfPresent(String.self, forKey: .objective) ?? "",
            taskType: decodedTaskType ?? legacyTaskType ?? .homework,
            stopCondition: try c.decode(CoachStopCondition.self, forKey: .stopCondition),
            status: try c.decodeIfPresent(CoachTodoSuggestionStatus.self, forKey: .status) ?? .pending,
            taskID: try c.decodeIfPresent(UUID.self, forKey: .taskID)
        )
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(subject, forKey: .subject)
        try c.encode(startDate, forKey: .startDate)
        try c.encode(dueDate, forKey: .dueDate)
        try c.encode(importance, forKey: .importance)
        try c.encode(notes, forKey: .notes)
        try c.encode(objective, forKey: .objective)
        try c.encode(taskType, forKey: .taskType)
        try c.encode(stopCondition, forKey: .stopCondition)
        try c.encode(status, forKey: .status)
        try c.encodeIfPresent(taskID, forKey: .taskID)
    }
}

nonisolated struct CoachConversationMessage: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let goalID: UUID?
    let chatID: UUID
    let role: CoachMessageRole
    var content: String
    let createdAt: Date
    var isStreaming: Bool
    var error: String?
    var todoSuggestions: [CoachTodoSuggestion]
    /// Current-turn image attachments. Deliberately excluded from persistence.
    var attachments: [LLMImageAttachment]

    private enum CodingKeys: String, CodingKey { case id, goalID, chatID, role, content, createdAt, isStreaming, error, todoSuggestions }

    init(id: UUID = UUID(), goalID: UUID? = nil, chatID: UUID = UUID(), role: CoachMessageRole, content: String = "",
         createdAt: Date = Date(), isStreaming: Bool = false, error: String? = nil,
         todoSuggestions: [CoachTodoSuggestion] = [], attachments: [LLMImageAttachment] = []) {
        self.id = id; self.goalID = goalID; self.chatID = chatID; self.role = role; self.content = content
        self.createdAt = createdAt; self.isStreaming = isStreaming; self.error = error
        self.todoSuggestions = todoSuggestions
        self.attachments = attachments
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
                  goalID: try c.decodeIfPresent(UUID.self, forKey: .goalID),
                  chatID: try c.decodeIfPresent(UUID.self, forKey: .chatID) ?? UUID(),
                  role: try c.decode(CoachMessageRole.self, forKey: .role),
                  content: try c.decodeIfPresent(String.self, forKey: .content) ?? "",
                  createdAt: try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date(),
                  isStreaming: try c.decodeIfPresent(Bool.self, forKey: .isStreaming) ?? false,
                  error: try c.decodeIfPresent(String.self, forKey: .error),
                  todoSuggestions: try c.decodeIfPresent([CoachTodoSuggestion].self, forKey: .todoSuggestions) ?? [])
    }
}

nonisolated enum CoachGoalStatus: String, Codable, Sendable, CaseIterable {
    case active, paused, achieved, abandoned
}

nonisolated struct CoachGoalVersion: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let version: Int
    let subjects: [CoachGoalSubject]
    let targetDate: Date
    let dailyAvailableMinutes: Int
    let createdAt: Date
    let changeNote: String

    init(id: UUID = UUID(), version: Int, subjects: [CoachGoalSubject], targetDate: Date,
         dailyAvailableMinutes: Int, createdAt: Date, changeNote: String) {
        self.id = id; self.version = version; self.subjects = subjects; self.targetDate = targetDate
        self.dailyAvailableMinutes = dailyAvailableMinutes; self.createdAt = createdAt; self.changeNote = changeNote
    }
}

nonisolated struct CoachGoalSubject: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    var subject: String
    var baselineScore: Double
    var targetScore: Double
    var fullScore: Double
    var weight: Double

    /// Relative contribution to the multi-subject weighted target.
    var contribution: Double { weight }

    init(id: UUID = UUID(), subject: String, baselineScore: Double = 0,
         targetScore: Double, fullScore: Double = 100, weight: Double = 1) {
        self.id = id; self.subject = subject; self.baselineScore = baselineScore
        self.targetScore = targetScore; self.fullScore = fullScore
        self.weight = max(0, weight)
    }
}

extension CoachGoal {
    /// Normalized share used by the Coach UI and analysis explanations.
    func contribution(of subject: CoachGoalSubject) -> Double {
        let total = subjects.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return 0 }
        return subject.weight / total
    }
}

nonisolated struct CoachGoal: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    var title: String
    var subjects: [CoachGoalSubject]
    var examID: UUID?
    var comprehensiveExamID: UUID?
    var startDate: Date
    var targetDate: Date
    var dailyAvailableMinutes: Int
    var purpose: String
    var constraints: String
    var status: CoachGoalStatus
    var version: Int
    var createdAt: Date
    var updatedAt: Date
    var history: [CoachGoalVersion]

    init(id: UUID = UUID(), title: String, subjects: [CoachGoalSubject],
         examID: UUID? = nil, comprehensiveExamID: UUID? = nil,
         startDate: Date = Date(), targetDate: Date,
         dailyAvailableMinutes: Int = 120, purpose: String = "",
         constraints: String = "", status: CoachGoalStatus = .active,
         version: Int = 1, createdAt: Date = Date(), updatedAt: Date = Date(), history: [CoachGoalVersion] = []) {
        self.id = id; self.title = title; self.subjects = subjects
        self.examID = examID; self.comprehensiveExamID = comprehensiveExamID
        self.startDate = startDate; self.targetDate = targetDate
        self.dailyAvailableMinutes = max(0, dailyAvailableMinutes)
        self.purpose = purpose; self.constraints = constraints; self.status = status
        self.version = version; self.createdAt = createdAt; self.updatedAt = updatedAt; self.history = history
    }

    private enum CodingKeys: String, CodingKey { case id, title, subjects, examID, comprehensiveExamID, startDate, targetDate, dailyAvailableMinutes, purpose, constraints, status, version, createdAt, updatedAt, history }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(), title: try c.decode(String.self, forKey: .title), subjects: try c.decode([CoachGoalSubject].self, forKey: .subjects), examID: try c.decodeIfPresent(UUID.self, forKey: .examID), comprehensiveExamID: try c.decodeIfPresent(UUID.self, forKey: .comprehensiveExamID), startDate: try c.decodeIfPresent(Date.self, forKey: .startDate) ?? Date(), targetDate: try c.decode(Date.self, forKey: .targetDate), dailyAvailableMinutes: try c.decodeIfPresent(Int.self, forKey: .dailyAvailableMinutes) ?? 120, purpose: try c.decodeIfPresent(String.self, forKey: .purpose) ?? "", constraints: try c.decodeIfPresent(String.self, forKey: .constraints) ?? "", status: try c.decodeIfPresent(CoachGoalStatus.self, forKey: .status) ?? .active, version: try c.decodeIfPresent(Int.self, forKey: .version) ?? 1, createdAt: try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date(), updatedAt: try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date(), history: try c.decodeIfPresent([CoachGoalVersion].self, forKey: .history) ?? [])
    }
}

nonisolated enum CoachStopConditionKind: String, Codable, Sendable, CaseIterable {
    case mistakeReviewCount, masteryThreshold, questionCount, knowledgePoint, studySessionReflection
}

nonisolated struct CoachStopCondition: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    var kind: CoachStopConditionKind
    var value: Double
    var label: String
    var targetIDs: [UUID]

    init(id: UUID = UUID(), kind: CoachStopConditionKind, value: Double = 1,
         label: String = "", targetIDs: [UUID] = []) {
        self.id = id; self.kind = kind; self.value = max(0, value)
        self.label = label; self.targetIDs = targetIDs
    }

    private enum CodingKeys: String, CodingKey { case id, kind, value, label, targetIDs }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            kind: try container.decode(CoachStopConditionKind.self, forKey: .kind),
            value: try container.decodeIfPresent(Double.self, forKey: .value) ?? 1,
            label: try container.decodeIfPresent(String.self, forKey: .label) ?? "",
            targetIDs: try container.decodeIfPresent([UUID].self, forKey: .targetIDs) ?? []
        )
    }
}

nonisolated struct CoachTaskSpec: Codable, Hashable, Sendable {
    var startDate: Date
    var subject: String
    var objective: String
    var stopCondition: CoachStopCondition
    var goalID: UUID
    var proposalID: UUID?
    var evaluation: CoachTaskEvaluation?

    init(startDate: Date, subject: String, objective: String,
         stopCondition: CoachStopCondition, goalID: UUID, proposalID: UUID? = nil,
         evaluation: CoachTaskEvaluation? = nil) {
        self.startDate = startDate; self.subject = subject; self.objective = objective
        self.stopCondition = stopCondition; self.goalID = goalID; self.proposalID = proposalID; self.evaluation = evaluation
    }

    private enum CodingKeys: String, CodingKey { case startDate, subject, objective, stopCondition, goalID, proposalID, evaluation }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(startDate: try c.decode(Date.self, forKey: .startDate), subject: try c.decode(String.self, forKey: .subject), objective: try c.decode(String.self, forKey: .objective), stopCondition: try c.decode(CoachStopCondition.self, forKey: .stopCondition), goalID: try c.decode(UUID.self, forKey: .goalID), proposalID: try c.decodeIfPresent(UUID.self, forKey: .proposalID), evaluation: try c.decodeIfPresent(CoachTaskEvaluation.self, forKey: .evaluation))
    }
}

nonisolated enum CoachTaskEvaluationStatus: String, Codable, Sendable {
    case pending, inProgress, completed, notMet
}

nonisolated struct CoachTaskEvaluation: Codable, Hashable, Sendable {
    var status: CoachTaskEvaluationStatus
    var progress: Double
    var evaluatedAt: Date
    var detail: String
}

nonisolated enum CoachProposalStatus: String, Codable, Sendable, CaseIterable {
    case pending, approved, rejected, expired, superseded
}

nonisolated struct CoachPlanItem: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    var title: String
    var subject: String
    var startDate: Date
    var objective: String
    var stopCondition: CoachStopCondition
    var importance: Int

    init(id: UUID = UUID(), title: String, subject: String, startDate: Date,
         objective: String, stopCondition: CoachStopCondition, importance: Int = 3) {
        self.id = id; self.title = title; self.subject = subject; self.startDate = startDate
        self.objective = objective; self.stopCondition = stopCondition
        self.importance = min(5, max(1, importance))
    }
}

nonisolated struct CoachProposal: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    var goalID: UUID
    var goalVersion: Int
    var analysisID: UUID
    var conclusion: String
    var rationale: String
    var items: [CoachPlanItem]
    var status: CoachProposalStatus
    var createdAt: Date
    var expiresAt: Date
    var resolvedAt: Date?
    var failureReason: String?
    var alternative: String?

    init(id: UUID = UUID(), goalID: UUID, goalVersion: Int, analysisID: UUID,
         conclusion: String, rationale: String, items: [CoachPlanItem],
         status: CoachProposalStatus = .pending, createdAt: Date = Date(),
         expiresAt: Date? = nil, resolvedAt: Date? = nil, failureReason: String? = nil,
         alternative: String? = nil) {
        self.id = id; self.goalID = goalID; self.goalVersion = goalVersion
        self.analysisID = analysisID; self.conclusion = conclusion; self.rationale = rationale
        self.items = items; self.status = status; self.createdAt = createdAt
        self.expiresAt = expiresAt ?? Calendar.current.date(byAdding: .day, value: 2, to: createdAt) ?? createdAt
        self.resolvedAt = resolvedAt; self.failureReason = failureReason; self.alternative = alternative
    }

    private enum CodingKeys: String, CodingKey { case id, goalID, goalVersion, analysisID, conclusion, rationale, items, status, createdAt, expiresAt, resolvedAt, failureReason, alternative }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(), goalID: try c.decode(UUID.self, forKey: .goalID), goalVersion: try c.decodeIfPresent(Int.self, forKey: .goalVersion) ?? 1, analysisID: try c.decode(UUID.self, forKey: .analysisID), conclusion: try c.decode(String.self, forKey: .conclusion), rationale: try c.decodeIfPresent(String.self, forKey: .rationale) ?? "", items: try c.decodeIfPresent([CoachPlanItem].self, forKey: .items) ?? [], status: try c.decodeIfPresent(CoachProposalStatus.self, forKey: .status) ?? .pending, createdAt: try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date(), expiresAt: try c.decodeIfPresent(Date.self, forKey: .expiresAt), resolvedAt: try c.decodeIfPresent(Date.self, forKey: .resolvedAt), failureReason: try c.decodeIfPresent(String.self, forKey: .failureReason), alternative: try c.decodeIfPresent(String.self, forKey: .alternative))
    }
}

nonisolated struct CoachSubjectPrediction: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let subject: String
    let predicted: Double
    let lowerBound: Double
    let upperBound: Double
    let targetScore: Double
    let confidence: Double
    let sampleSize: Int

    init(id: UUID = UUID(), subject: String, predicted: Double, lowerBound: Double,
         upperBound: Double, targetScore: Double, confidence: Double, sampleSize: Int) {
        self.id = id; self.subject = subject; self.predicted = predicted
        self.lowerBound = lowerBound; self.upperBound = upperBound; self.targetScore = targetScore
        self.confidence = confidence; self.sampleSize = sampleSize
    }
}

nonisolated enum CoachDecision: String, Codable, Sendable { case continueGoal, adjustStrategy, notFeasible, insufficientData }

nonisolated struct CoachAnalysis: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let goalID: UUID
    let goalVersion: Int
    let calculatedAt: Date
    let decision: CoachDecision
    let weightedPredicted: Double
    let weightedLowerBound: Double
    let weightedUpperBound: Double
    let successProbability: Double
    let predictions: [CoachSubjectPrediction]
    let risks: [String]
    let evidence: [String]
    let dataFingerprint: String
    let healthDataAvailable: Bool

    init(id: UUID = UUID(), goalID: UUID, goalVersion: Int, calculatedAt: Date = Date(),
         decision: CoachDecision, weightedPredicted: Double, weightedLowerBound: Double,
         weightedUpperBound: Double, successProbability: Double,
         predictions: [CoachSubjectPrediction], risks: [String], evidence: [String],
         dataFingerprint: String, healthDataAvailable: Bool = false) {
        self.id = id; self.goalID = goalID; self.goalVersion = goalVersion; self.calculatedAt = calculatedAt
        self.decision = decision; self.weightedPredicted = weightedPredicted
        self.weightedLowerBound = weightedLowerBound; self.weightedUpperBound = weightedUpperBound
        self.successProbability = min(1, max(0, successProbability)); self.predictions = predictions
        self.risks = risks; self.evidence = evidence; self.dataFingerprint = dataFingerprint
        self.healthDataAvailable = healthDataAvailable
    }
}
