import Foundation

nonisolated enum ExamRoleLLM {
    static let defaultSystem = """
    你是一位严谨的考试行为分析师。你分析的是用户在一次限时模拟中的可改变决策模式，
    不是性格、人格或心理诊断。只能从以下固定角色中选择一个：
    firstQuestionFixation, overChecking, intuitionSkipping,
    frontSlowBackPanic, answerChanging, pressureDrop。

    判断必须引用输入中的可观察行为。证据不足时降低 confidence，不得创造新角色。
    当 validSessionCount 小于 3 时 isStable 必须为 false；达到 3 次后，只有当前结果与历史
    模式具有一致证据时才可为 true。

    严格输出以下 JSON，不要输出 Markdown 或额外文字：
    {
      "role": "<固定角色 ID>",
      "confidence": <0 到 1>,
      "evidence": [
        {"title": "<短标题>", "detail": "<包含可核对数值的证据>", "questionIndex": <0-based 或 null>}
      ],
      "risk": "<该模式在真实考试中的主要风险>",
      "strategies": ["<下一场可执行策略>", "<下一场可执行策略>"],
      "isStable": <true 或 false>
    }
    evidence 必须为 2 到 4 条，strategies 必须为 2 到 4 条。
    """

    static func makePrompt(
        simulation: ExamSimulation,
        previous: [ExamSimulation]
    ) -> LLMPrompt {
        let records = simulation.questionRecords.enumerated().map { index, record in
            """
            Q\(index + 1): type=\(record.question.type), visits=\(record.visitCount), \
            viewSeconds=\(Int(record.totalViewSeconds.rounded())), skips=\(record.skipCount), \
            answerChanges=\(record.answerChangeCount), firstAnswer=\(safe(record.firstAnswer)), \
            finalAnswer=\(safe(record.finalAnswer)), correctAnswer=\(safe(record.question.correctAnswer)), \
            isCorrect=\(record.isCorrect.map(String.init) ?? "unknown"), score=\(record.score.map(String.init) ?? "unknown")
            """
        }.joined(separator: "\n")

        let history = previous.prefix(5).map { item in
            let role = item.analysis?.role.rawValue ?? "unknown"
            let confidence = item.analysis.map { String(format: "%.2f", $0.confidence) } ?? "unknown"
            return "\(item.createdAt.timeIntervalSince1970): role=\(role), confidence=\(confidence)"
        }.joined(separator: "\n")

        let elapsed = simulation.startedAt.flatMap { start in
            simulation.endedAt.map { Int($0.timeIntervalSince(start).rounded()) }
        } ?? simulation.durationSeconds

        let user = """
        subject=\(simulation.subject)
        durationLimitSeconds=\(simulation.durationSeconds)
        elapsedSeconds=\(elapsed)
        totalScore=\(simulation.totalScore.map(String.init) ?? "unknown")
        answeredCount=\(simulation.answeredCount)
        validSessionCount=\(previous.count + 1)

        currentQuestionBehavior:
        \(records)

        previousRoleSummaries:
        \(history.isEmpty ? "(none)" : history)
        """
        return LLMPrompt(system: defaultSystem, messages: [.user(user)])
    }

    static func parse(_ rawText: String) -> ExamRoleAnalysis? {
        guard let data = cleanedJSON(rawText).data(using: .utf8),
              let decoded = try? JSONDecoder().decode(ExamRoleAnalysis.self, from: data),
              (2...4).contains(decoded.evidence.count),
              (2...4).contains(decoded.strategies.count) else {
            return nil
        }
        return decoded
    }

    static func parseQuestions(_ rawText: String) -> [QuizQuestion]? {
        guard let data = cleanedJSON(rawText).data(using: .utf8),
              let questions = try? JSONDecoder().decode([QuizQuestion].self, from: data),
              questions.count == ExamSimulation.defaultQuestionCount else {
            return nil
        }
        return questions
    }

    static func parseGrading(_ rawText: String) -> QuizGradingResponse? {
        guard let data = cleanedJSON(rawText).data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(QuizGradingResponse.self, from: data)
    }

    private static func safe(_ value: String?) -> String {
        let compact = (value ?? "(unanswered)")
            .replacingOccurrences(of: "\n", with: " ")
            .prefix(180)
        return String(compact)
    }

    private static func cleanedJSON(_ rawText: String) -> String {
        var cleaned = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```json") {
            cleaned.removeFirst(7)
        } else if cleaned.hasPrefix("```") {
            cleaned.removeFirst(3)
        }
        if cleaned.hasSuffix("```") {
            cleaned.removeLast(3)
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
