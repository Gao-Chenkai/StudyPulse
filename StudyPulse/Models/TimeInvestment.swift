//
//  TimeInvestment.swift
//  StudyPulse
//
//  Independent long-term time-investment domain. These projects deliberately
//  do not reuse the academic Subject model used by grades and exams.
//

import Foundation

nonisolated enum TimeInvestmentTheme: String, Codable, CaseIterable, Sendable {
    case ocean
    case coral
    case violet
    case sunshine
    case mint

    var colorHex: String {
        switch self {
        case .ocean: return "168AAD"
        case .coral: return "F26B5B"
        case .violet: return "7B61D1"
        case .sunshine: return "F2B705"
        case .mint: return "2AA876"
        }
    }
}

/// Root project shown as a "subject" in the time-investment UI.
nonisolated struct TimeInvestmentSubject: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    var symbolName: String
    var theme: TimeInvestmentTheme
    var startDate: Date
    var sortOrder: Int
    var createdAt: Date
    var isArchived: Bool

    init(
        id: UUID = UUID(),
        name: String,
        symbolName: String = "book.closed.fill",
        theme: TimeInvestmentTheme = .ocean,
        startDate: Date = .now,
        sortOrder: Int = 0,
        createdAt: Date = .now,
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.theme = theme
        self.startDate = startDate
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.isArchived = isArchived
    }
}

/// A child project. A root subject plus at most two SubTask levels produces
/// the product's maximum three-level hierarchy.
nonisolated struct SubTask: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var subjectID: UUID
    var parentSubTaskID: UUID?
    var name: String
    var sortOrder: Int
    var createdAt: Date
    var isArchived: Bool

    init(
        id: UUID = UUID(),
        subjectID: UUID,
        parentSubTaskID: UUID? = nil,
        name: String,
        sortOrder: Int = 0,
        createdAt: Date = .now,
        isArchived: Bool = false
    ) {
        self.id = id
        self.subjectID = subjectID
        self.parentSubTaskID = parentSubTaskID
        self.name = name
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.isArchived = isArchived
    }
}

nonisolated enum InvestmentTarget: Codable, Hashable, Sendable, Identifiable {
    case subject(UUID)
    case subTask(UUID)

    var id: String {
        switch self {
        case .subject(let id): return "subject:\(id.uuidString)"
        case .subTask(let id): return "subtask:\(id.uuidString)"
        }
    }

    var rawID: UUID {
        switch self {
        case .subject(let id), .subTask(let id): return id
        }
    }

    var kindRawValue: String {
        switch self {
        case .subject: return "subject"
        case .subTask: return "subTask"
        }
    }

    init?(kindRawValue: String, id: UUID) {
        switch kindRawValue {
        case "subject": self = .subject(id)
        case "subTask": self = .subTask(id)
        default: return nil
        }
    }
}

nonisolated struct GoalReward: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var title: String
    var symbolName: String
    var target: InvestmentTarget
    var thresholdSeconds: Int
    var createdAt: Date
    var unlockedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        symbolName: String = "gift.fill",
        target: InvestmentTarget,
        thresholdSeconds: Int,
        createdAt: Date = .now,
        unlockedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.symbolName = symbolName
        self.target = target
        self.thresholdSeconds = max(60, thresholdSeconds)
        self.createdAt = createdAt
        self.unlockedAt = unlockedAt
    }
}

nonisolated enum StudySessionSource: String, Codable, Hashable, Sendable {
    case timer
    case manual
}
