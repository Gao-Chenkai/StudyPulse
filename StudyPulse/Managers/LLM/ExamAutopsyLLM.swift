import Foundation

enum ExamAutopsyLLM {
    private static let system = """
    你是考试复盘助手。只返回合法 JSON，不要代码围栏或 JSON 以外的解释。格式：{"items":[{"questionNumber":"","question":"","userAnswer":"","correctAnswer":"","points":null,"knowledgePoints":[],"behavior":"","reason":"knowledgeGap|unstableMastery|methodError|calculationError|readingError|timeInsufficient|unanswered|expressionIssue|unknown","evidence":"","confidence":0.0,"repairSuggestion":""}],"conclusion":"","keyProblems":[],"historicalFacts":[]}
    question、userAnswer、correctAnswer、evidence、behavior、repairSuggestion、conclusion、keyProblems 中的所有数学表达式必须使用 Markdown 数学格式：行内 $...$，独立公式 $$...$$；禁止裸 LaTeX。只能根据图片可见内容作答；无法确认就使用空字符串、null、unknown，并降低 confidence。不要使用“粗心”，请描述具体行为。
    """

    @MainActor
    static func analyze(images: [Data], context: String, config: LLMConfig) async throws -> (items: [ExamAutopsyItem], report: ExamAutopsyReport) {
        guard config.isConfigured, config.multimodalEnabled, !images.isEmpty else { throw LLMError.notConfigured }
        let urls = images.map { LLMImageAttachment(data: $0).dataURL }
        let prompt = LLMPrompt(system: system, messages: [.user("请分析试卷图片。上下文：\n\(context)", imageDataURLs: urls)])
        let raw = try await LLMClient.shared.complete(prompt: prompt, config: config, caller: "ExamAutopsy")
        return try parseResponse(raw)
    }

    nonisolated static func parseResponse(_ raw: String) throws -> (items: [ExamAutopsyItem], report: ExamAutopsyReport) {
        guard let start = raw.firstIndex(of: "{"), let end = raw.lastIndex(of: "}") else { throw LLMError.malformedResponse }
        let data = String(raw[start...end]).data(using: .utf8)
        guard let data, let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw LLMError.malformedResponse }
        let itemsData = (try? JSONSerialization.data(withJSONObject: object["items"] ?? [])) ?? Data("[]".utf8)
        let rawItems = (try? JSONDecoder().decode([RawItem].self, from: itemsData)) ?? []
        let items = rawItems.map { $0.snapshot() }
        let conclusion = object["conclusion"] as? String ?? ""
        let keyProblems = object["keyProblems"] as? [String] ?? []
        let facts = object["historicalFacts"] as? [String] ?? []
        var counts: [String: Int] = [:]
        for item in items { counts[item.reason.rawValue, default: 0] += 1 }
        return (items, ExamAutopsyReport(conclusion: conclusion, reasonCounts: counts, keyProblems: keyProblems, historicalFacts: facts))
    }

    private struct RawItem: Codable {
        var questionNumber: String?; var question: String?; var userAnswer: String?; var correctAnswer: String?; var points: Double?
        var knowledgePoints: [String]?; var behavior: String?; var reason: String?; var evidence: String?; var confidence: Double?; var repairSuggestion: String?
        nonisolated func snapshot() -> ExamAutopsyItem { ExamAutopsyItem(questionNumber: questionNumber ?? "", question: question ?? "", userAnswer: userAnswer ?? "", correctAnswer: correctAnswer ?? "", points: points, knowledgePoints: knowledgePoints ?? [], behavior: behavior ?? "", reason: AutopsyLossReason(rawValue: reason ?? "") ?? .unknown, evidence: evidence ?? "", confidence: min(max(confidence ?? 0, 0), 1), source: .aiDraft, isConfirmed: false, repairSuggestion: repairSuggestion ?? "") }
    }
}
