//
//  KnowledgeFaultLine.swift
//  StudyPulse
//
//  In-memory knowledge-gap analysis models. These types intentionally do not
//  participate in MistakeNote or SwiftData persistence.
//

import Foundation

nonisolated enum KnowledgeFaultCategory: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case proportionalReasoning = "proportional_reasoning"
    case unitConversion = "unit_conversion"
    case equationModeling = "equation_modeling"
    case conceptDefinition = "concept_definition"
    case conditionBoundary = "condition_boundary"
    case methodSelection = "method_selection"
    case symbolicCalculation = "symbolic_calculation"
    case readingTranslation = "reading_translation"
    case foundationalMemory = "foundational_memory"
    case other = "other"

    var id: String { rawValue }

    var titleKey: String { "knowledge.fault.category.\(rawValue).title" }

    var displayName: String {
        let localized = titleKey.localized()
        if localized != titleKey { return localized }
        switch self {
        case .proportionalReasoning: return "比例关系"
        case .unitConversion: return "单位换算"
        case .equationModeling: return "方程建模"
        case .conceptDefinition: return "概念与定义"
        case .conditionBoundary: return "条件与边界"
        case .methodSelection: return "方法选择"
        case .symbolicCalculation: return "符号计算"
        case .readingTranslation: return "审题转译"
        case .foundationalMemory: return "基础记忆"
        case .other: return "其他基础能力"
        }
    }
}

nonisolated enum KnowledgeExtractionSource: String, Codable, Hashable, Sendable {
    case rules
    case ai
}

/// The extracted chain for one mistake: target concept → prerequisites → foundation.
nonisolated struct MistakeKnowledgeNode: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let mistakeID: UUID
    let subject: String
    let targetConcept: String
    let prerequisiteConcepts: [String]
    let foundationConcept: String
    let category: KnowledgeFaultCategory
    let evidence: [String]
    let confidence: Double
    let source: KnowledgeExtractionSource

    init(
        id: String? = nil,
        mistakeID: UUID,
        subject: String,
        targetConcept: String,
        prerequisiteConcepts: [String],
        foundationConcept: String,
        category: KnowledgeFaultCategory,
        evidence: [String],
        confidence: Double,
        source: KnowledgeExtractionSource
    ) {
        self.mistakeID = mistakeID
        self.subject = subject
        self.targetConcept = targetConcept
        self.prerequisiteConcepts = prerequisiteConcepts
        self.foundationConcept = foundationConcept
        self.category = category
        self.evidence = evidence
        self.confidence = min(1, max(0, confidence))
        self.source = source
        self.id = id ?? "\(mistakeID.uuidString)|\(targetConcept)|\(foundationConcept)"
    }

    var chainConcepts: [String] {
        [targetConcept] + prerequisiteConcepts + [foundationConcept]
    }
}

/// AI only supplies these fields; the local engine turns them into nodes and
/// performs all aggregation and risk scoring.
nonisolated struct KnowledgeFaultAIExtraction: Codable, Hashable, Sendable {
    let mistakeID: UUID
    let targetConcept: String
    let prerequisiteConcepts: [String]
    let foundationConcept: String
    let category: KnowledgeFaultCategory
    let evidence: String
    let confidence: Double

    init(
        mistakeID: UUID,
        targetConcept: String,
        prerequisiteConcepts: [String],
        foundationConcept: String,
        category: KnowledgeFaultCategory,
        evidence: String,
        confidence: Double = 0.8
    ) {
        self.mistakeID = mistakeID
        self.targetConcept = targetConcept
        self.prerequisiteConcepts = prerequisiteConcepts
        self.foundationConcept = foundationConcept
        self.category = category
        self.evidence = evidence
        self.confidence = min(1, max(0, confidence))
    }
}

nonisolated struct KnowledgeFaultLine: Identifiable, Hashable {
    let id: String
    let category: KnowledgeFaultCategory
    let prerequisiteConcept: String
    let foundationConcept: String
    let impactMistakeCount: Int
    let subjects: [String]
    let recentRecurrenceCount: Int
    let riskScore: Double
    let relatedMistakeIDs: [UUID]
    let relatedMistakes: [MistakeNote]

    var isRepeated: Bool { impactMistakeCount >= KnowledgeFaultLineEngine.minimumOccurrences }
}

nonisolated struct KnowledgeFaultScan: Hashable {
    let nodes: [MistakeKnowledgeNode]
    let faultLines: [KnowledgeFaultLine]
    let usedFallback: Bool
    let aiAppliedCount: Int

    static let empty = KnowledgeFaultScan(nodes: [], faultLines: [], usedFallback: true, aiAppliedCount: 0)

    var repeatedFaultLines: [KnowledgeFaultLine] {
        faultLines.filter(\.isRepeated)
    }

    func node(for mistakeID: UUID) -> MistakeKnowledgeNode? {
        nodes.first { $0.mistakeID == mistakeID }
    }

    func faultLine(id: String) -> KnowledgeFaultLine? {
        faultLines.first { $0.id == id }
    }
}
