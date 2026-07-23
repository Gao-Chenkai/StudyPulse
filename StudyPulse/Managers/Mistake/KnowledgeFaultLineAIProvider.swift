//
//  KnowledgeFaultLineAIProvider.swift
//  StudyPulse
//

import Foundation

@MainActor
protocol KnowledgeFaultLineAIProviding: AnyObject {
    func extract(
        from mistakes: [MistakeNote],
        config: LLMConfig
    ) async throws -> [KnowledgeFaultAIExtraction]
}

@MainActor
final class DefaultKnowledgeFaultLineAIProvider: KnowledgeFaultLineAIProviding {
    private let batchSize = 20

    func extract(
        from mistakes: [MistakeNote],
        config: LLMConfig
    ) async throws -> [KnowledgeFaultAIExtraction] {
        guard !mistakes.isEmpty else { return [] }
        var extractions: [KnowledgeFaultAIExtraction] = []
        var firstError: Error?

        for start in stride(from: 0, to: mistakes.count, by: batchSize) {
            let end = min(start + batchSize, mistakes.count)
            let batch = Array(mistakes[start..<end])
            do {
                let prompt = KnowledgeFaultLineLLM.makePrompt(mistakes: batch)
                let raw = try await LLMClient.shared.complete(
                    prompt: prompt,
                    config: config,
                    caller: "KnowledgeFaultLine"
                )
                extractions.append(contentsOf: KnowledgeFaultLineLLM.parse(raw))
            } catch {
                firstError = firstError ?? error
                if extractions.isEmpty { throw error }
                break
            }
        }

        if extractions.isEmpty, let firstError { throw firstError }
        return extractions
    }
}

nonisolated enum KnowledgeFaultLineLLM {
    private struct Payload: Decodable {
        let items: [RawItem]
    }

    private struct RawItem: Decodable {
        let mistakeID: String?
        let targetConcept: String?
        let prerequisiteConcepts: [String]?
        let foundationConcept: String?
        let category: String?
        let evidence: String?
        let confidence: Double?

        enum CodingKeys: String, CodingKey {
            case mistakeID = "mistake_id"
            case targetConcept = "target_concept"
            case prerequisiteConcepts = "prerequisites"
            case foundationConcept = "foundation"
            case category
            case evidence
            case confidence
        }
    }

    static func makePrompt(mistakes: [MistakeNote]) -> LLMPrompt {
        let records = mistakes.map { mistake in
            """
            {
              "mistake_id": "\(mistake.id.uuidString)",
              "subject": "\(compact(mistake.subject))",
              "title": "\(compact(mistake.title))",
              "tags": "\(compact(mistake.tags.joined(separator: ", ")))",
              "error_reason": "\(compact(mistake.errorReason))",
              "wrong_solution": "\(compact(mistake.wrongSolution))",
              "correct_solution": "\(compact(mistake.correctSolution))"
            }
            """
        }.joined(separator: ",\n")

        let system = """
        你是学习诊断助手，只负责从错题文本中提取知识关系，不负责评分或学习建议。
        对每一道错题返回一个 item。target_concept 是题目直接考查的知识点；prerequisites 是最多 3 个前置概念；foundation 是最底层需要修复的能力；category 必须从以下 ID 中选择：proportional_reasoning, unit_conversion, equation_modeling, concept_definition, condition_boundary, method_selection, symbolic_calculation, reading_translation, foundational_memory, other。
        没有足够证据时使用 other，并保守填写概念。严格只返回 JSON，不要 Markdown 代码块：
        {"items":[{"mistake_id":"UUID","target_concept":"...","prerequisites":["..."],"foundation":"...","category":"other","evidence":"...","confidence":0.0}]}
        """

        let user = """
        请分析以下错题：
        [
        \(records)
        ]
        """
        return LLMPrompt(system: system, messages: [.user(user)])
    }

    static func parse(_ text: String) -> [KnowledgeFaultAIExtraction] {
        guard let data = jsonData(from: text) else { return [] }
        let rawItems: [RawItem]
        if let payload = try? JSONDecoder().decode(Payload.self, from: data) {
            rawItems = payload.items
        } else if let array = try? JSONDecoder().decode([RawItem].self, from: data) {
            rawItems = array
        } else {
            return []
        }

        var seen = Set<UUID>()
        return rawItems.compactMap { item in
            guard let rawMistakeID = item.mistakeID,
                  let mistakeID = UUID(uuidString: rawMistakeID),
                  seen.insert(mistakeID).inserted,
                  let target = item.targetConcept?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !target.isEmpty,
                  let foundation = item.foundationConcept?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !foundation.isEmpty,
                  let rawCategory = item.category,
                  let category = KnowledgeFaultCategory(rawValue: rawCategory) else {
                return nil
            }
            let prerequisites = (item.prerequisiteConcepts ?? [])
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .prefix(3)
            return KnowledgeFaultAIExtraction(
                mistakeID: mistakeID,
                targetConcept: target,
                prerequisiteConcepts: Array(prerequisites),
                foundationConcept: foundation,
                category: category,
                evidence: item.evidence?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                confidence: item.confidence ?? 0.75
            )
        }
    }

    private static func jsonData(from text: String) -> Data? {
        let cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = cleaned.data(using: .utf8),
           ((try? JSONDecoder().decode(Payload.self, from: data)) != nil ||
            (try? JSONDecoder().decode([RawItem].self, from: data)) != nil) {
            return data
        }
        guard let start = cleaned.firstIndex(of: "{"), let end = cleaned.lastIndex(of: "}") else { return nil }
        return String(cleaned[start...end]).data(using: .utf8)
    }

    private static func compact(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}
