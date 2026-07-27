import Foundation

/// An exam target entered by the student.
nonisolated struct ExamGoal: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var examName: String
    var subject: String
    var examDate: Date
    var currentScore: Double
    var targetScore: Double
    var fullScore: Double
    var phaseId: UUID?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        examName: String,
        subject: String,
        examDate: Date,
        currentScore: Double,
        targetScore: Double,
        fullScore: Double,
        phaseId: UUID? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.examName = examName
        self.subject = subject
        self.examDate = examDate
        self.currentScore = currentScore
        self.targetScore = targetScore
        self.fullScore = fullScore
        self.phaseId = phaseId
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, examName, subject, examDate, currentScore, targetScore, fullScore, phaseId, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        examName = try container.decodeIfPresent(String.self, forKey: .examName) ?? ""
        subject = try container.decodeIfPresent(String.self, forKey: .subject) ?? ""
        examDate = try container.decodeIfPresent(Date.self, forKey: .examDate) ?? Date()
        currentScore = try container.decodeIfPresent(Double.self, forKey: .currentScore) ?? 0
        targetScore = try container.decodeIfPresent(Double.self, forKey: .targetScore) ?? 0
        fullScore = try container.decodeIfPresent(Double.self, forKey: .fullScore) ?? 100
        phaseId = try container.decodeIfPresent(UUID.self, forKey: .phaseId)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}

/// An AI-identified weak point in an exam plan.
nonisolated struct WeakPoint: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var topic: String
    var mastery: Double
    var possibleScoreGain: Double
    var priority: Int

    init(
        id: UUID = UUID(),
        topic: String,
        mastery: Double,
        possibleScoreGain: Double,
        priority: Int
    ) {
        self.id = id
        self.topic = topic
        self.mastery = min(max(mastery, 0), 1)
        self.possibleScoreGain = max(0, possibleScoreGain)
        self.priority = max(1, priority)
    }

    private enum CodingKeys: String, CodingKey { case id, topic, mastery, possibleScoreGain, priority }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        topic = try container.decodeIfPresent(String.self, forKey: .topic) ?? ""
        mastery = min(max(try container.decodeIfPresent(Double.self, forKey: .mastery) ?? 0, 0), 1)
        possibleScoreGain = max(0, try container.decodeIfPresent(Double.self, forKey: .possibleScoreGain) ?? 0)
        priority = max(1, try container.decodeIfPresent(Int.self, forKey: .priority) ?? 1)
    }
}

/// One phase in the reverse study route.
nonisolated struct PlanPhase: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    var dayRange: String
    var goal: String

    init(id: UUID = UUID(), name: String, dayRange: String, goal: String) {
        self.id = id
        self.name = name
        self.dayRange = dayRange
        self.goal = goal
    }

    private enum CodingKeys: String, CodingKey { case id, name, dayRange, goal }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        dayRange = try container.decodeIfPresent(String.self, forKey: .dayRange) ?? ""
        goal = try container.decodeIfPresent(String.self, forKey: .goal) ?? ""
    }
}

/// A concrete daily task in an exam plan.
nonisolated struct DailyExamTask: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var dayOffset: Int
    var date: Date
    var subject: String
    var durationMinutes: Int
    var taskTitle: String
    var reason: String

    init(
        id: UUID = UUID(),
        dayOffset: Int,
        date: Date,
        subject: String,
        durationMinutes: Int,
        taskTitle: String,
        reason: String
    ) {
        self.id = id
        self.dayOffset = max(0, dayOffset)
        self.date = date
        self.subject = subject
        self.durationMinutes = max(1, durationMinutes)
        self.taskTitle = taskTitle
        self.reason = reason
    }

    private enum CodingKeys: String, CodingKey {
        case id, dayOffset, date, subject, durationMinutes, taskTitle, reason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        dayOffset = max(0, try container.decodeIfPresent(Int.self, forKey: .dayOffset) ?? 0)
        date = try container.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        subject = try container.decodeIfPresent(String.self, forKey: .subject) ?? ""
        durationMinutes = max(1, try container.decodeIfPresent(Int.self, forKey: .durationMinutes) ?? 30)
        taskTitle = try container.decodeIfPresent(String.self, forKey: .taskTitle) ?? ""
        reason = try container.decodeIfPresent(String.self, forKey: .reason) ?? ""
    }
}

/// The persisted aggregate produced by the reverse planner.
nonisolated struct ExamPlan: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var examGoalID: UUID
    var improvementTarget: Double
    var summary: String
    var weakPoints: [WeakPoint]
    var phases: [PlanPhase]
    var dailyTasks: [DailyExamTask]
    var modelInfo: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        examGoalID: UUID,
        improvementTarget: Double,
        summary: String,
        weakPoints: [WeakPoint],
        phases: [PlanPhase],
        dailyTasks: [DailyExamTask],
        modelInfo: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.examGoalID = examGoalID
        self.improvementTarget = max(0, improvementTarget)
        self.summary = summary
        self.weakPoints = weakPoints
        self.phases = phases
        self.dailyTasks = dailyTasks
        self.modelInfo = modelInfo
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, examGoalID, improvementTarget, summary, weakPoints, phases, dailyTasks, modelInfo, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        examGoalID = try container.decodeIfPresent(UUID.self, forKey: .examGoalID) ?? UUID()
        improvementTarget = max(0, try container.decodeIfPresent(Double.self, forKey: .improvementTarget) ?? 0)
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        weakPoints = try container.decodeIfPresent([WeakPoint].self, forKey: .weakPoints) ?? []
        phases = try container.decodeIfPresent([PlanPhase].self, forKey: .phases) ?? []
        dailyTasks = try container.decodeIfPresent([DailyExamTask].self, forKey: .dailyTasks) ?? []
        modelInfo = try container.decodeIfPresent(String.self, forKey: .modelInfo)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}
