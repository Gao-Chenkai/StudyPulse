//
//  MistakeImageRecognitionLLM.swift
//  StudyPulse
//

import Foundation

/// The four editable fields produced from a mistake photo.
nonisolated struct MistakeImageRecognitionResult: Codable, Equatable, Sendable {
    let question: String
    let errorReason: String
    let wrongSolution: String
    let correctSolution: String
}

/// Builds the existing OpenAI-compatible multimodal request and parses its JSON response.
enum MistakeImageRecognitionLLM {
    private static let systemPrompt = """
    你是 StudyPulse 的错题识别助手。请仔细阅读用户提供的错题图片，提取并分析其中的信息。
    只输出一个合法的 JSON 对象，不要输出 Markdown 代码围栏、解释或额外文字。JSON 必须且只能包含这四个字符串字段：question、errorReason、wrongSolution、correctSolution。
    所有字段中的数学表达式都必须使用 Markdown 数学格式：行内公式放在 $...$ 中，独立公式放在 $$...$$ 中；LaTeX 命令只能出现在这些定界符内部。禁止输出裸 LaTeX（例如直接输出 \\frac{a}{b}），也不要使用代码块包裹公式。示例：行内写 $x^2+1=0$，独立写 $$x = \\frac{-b \\pm \\sqrt{b^2-4ac}}{2a}$$。
    question：完整还原题目、所有选项、公式和已知条件，并严格遵守上述 Markdown 数学格式。
    errorReason：根据图片中可见的题目与学生答案，分析学生出错的根本原因；不能确定时明确写“[不确定：无法从图片确认]”。
    wrongSolution：整理图片中学生的错误解题过程；如果图片中没有学生答案，必须为空字符串；看不清时明确标记不确定，不要补写。
    correctSolution：给出正确、清晰、适合学生理解的分步解题过程，并严格遵守上述 Markdown 数学格式。
    图片中无法辨认或没有依据的内容不要编造，使用“[不确定：无法从图片确认]”明确标记。
    """

    @MainActor
    static func analyze(imageData: Data, config: LLMConfig) async throws -> MistakeImageRecognitionResult {
        guard config.isConfigured, config.multimodalEnabled else { throw LLMError.notConfigured }
        let attachment = LLMImageAttachment(data: imageData)
        let prompt = LLMPrompt(
            system: systemPrompt,
            messages: [.user("请识别这张错题图片，并按要求返回四字段 JSON。", imageDataURLs: [attachment.dataURL])]
        )
        let raw = try await LLMClient.shared.complete(prompt: prompt, config: config, caller: "MistakeImageRecognition")
        return try parseResponse(raw)
    }

    /// Accepts plain JSON or JSON wrapped in a code fence.
    nonisolated static func parseResponse(_ raw: String) throws -> MistakeImageRecognitionResult {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let start = trimmed.firstIndex(of: "{"), let end = trimmed.lastIndex(of: "}"), start <= end else {
            throw LLMError.malformedResponse
        }

        let json = String(trimmed[start...end])
        if let result = decode(json) {
            return try validated(result)
        }

        // Vision models sometimes emit single LaTeX backslashes or literal
        // newlines inside JSON strings. Repair these common JSON violations.
        let repaired = repairRelaxedJSON(json)
        guard let result = decode(repaired) else {
            throw LLMError.malformedResponse
        }
        return try validated(result)
    }

    nonisolated private static func decode(_ json: String) -> MistakeImageRecognitionResult? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(MistakeImageRecognitionResult.self, from: data)
    }

    nonisolated private static func repairRelaxedJSON(_ json: String) -> String {
        let characters = Array(json)
        let validEscapes: Set<Character> = ["\"", "\\", "/", "b", "f", "n", "r", "t", "u"]
        var output = ""
        output.reserveCapacity(json.count + 32)
        var isInsideString = false
        var index = 0

        while index < characters.count {
            let character = characters[index]
            if !isInsideString {
                output.append(character)
                if character == "\"" { isInsideString = true }
                index += 1
                continue
            }

            if character == "\"" {
                output.append(character)
                isInsideString = false
                index += 1
            } else if character == "\\" {
                guard index + 1 < characters.count else {
                    output.append("\\")
                    output.append("\\")
                    index += 1
                    continue
                }
                let next = characters[index + 1]
                if validEscapes.contains(next) {
                    output.append(character)
                    output.append(next)
                    index += 2
                } else {
                    output.append("\\")
                    output.append("\\")
                    index += 1
                }
            } else if character == "\n" {
                output.append(contentsOf: "\\n")
                index += 1
            } else if character == "\r" {
                output.append(contentsOf: "\\r")
                index += 1
            } else if character == "\t" {
                output.append(contentsOf: "\\t")
                index += 1
            } else {
                output.append(character)
                index += 1
            }
        }

        return output.replacingOccurrences(
            of: #",\s*([}\]])"#,
            with: "$1",
            options: .regularExpression
        )
    }

    nonisolated private static func validated(_ result: MistakeImageRecognitionResult) throws -> MistakeImageRecognitionResult {
        guard !result.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !result.correctSolution.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LLMError.malformedResponse
        }
        return result
    }
}
