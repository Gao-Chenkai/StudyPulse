//
//  AIQuizModels.swift
//  StudyPulse
//
//  Created for AI Quiz feature.
//

import Foundation

/// AI 自测题目模型
/// AI self-quiz question model.
public struct QuizQuestion: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    /// 题目类型: "multiple_choice" 或 "fill_in_the_blank"
    /// Question type: "multiple_choice" or "fill_in_the_blank".
    public let type: String
    /// 题干内容 (支持 Markdown / LaTeX 数学公式)
    /// Question text (supports Markdown / LaTeX math).
    public let question: String
    /// 选择题选项 (填空题为 nil 或空)
    /// Options for multiple-choice (nil or empty for fill-in-the-blank).
    public let options: [String]?
    /// 正确答案
    /// Correct answer.
    public let correctAnswer: String
    /// 详细解析
    /// Detailed solution / explanation.
    public let solution: String

    public init(id: UUID = UUID(), type: String, question: String, options: [String]?, correctAnswer: String, solution: String) {
        self.id = id
        self.type = type
        self.question = question
        self.options = options
        self.correctAnswer = correctAnswer
        self.solution = solution
    }

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case question
        case options
        case correctAnswer
        case solution
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.type = try container.decode(String.self, forKey: .type)
        self.question = try container.decode(String.self, forKey: .question)
        self.options = try container.decodeIfPresent([String].self, forKey: .options)
        self.correctAnswer = try container.decode(String.self, forKey: .correctAnswer)
        self.solution = try container.decode(String.self, forKey: .solution)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(question, forKey: .question)
        try container.encode(options, forKey: .options)
        try container.encode(correctAnswer, forKey: .correctAnswer)
        try container.encode(solution, forKey: .solution)
    }
}

/// 用户自测答案状态
/// User's submitted answer for one quiz question.
public struct UserQuizAnswer: Codable, Equatable, Sendable {
    public let questionId: UUID
    public var answerText: String
    
    public init(questionId: UUID, answerText: String) {
        self.questionId = questionId
        self.answerText = answerText
    }
}

/// LLM 评分单题结果
/// LLM grading result for a single question.
public struct QuizQuestionGradingResult: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    /// 对应第几道题 (0-indexed)
    /// Index of the question (0-based).
    public let index: Int
    /// 题目得分 (e.g. 0 或 10)
    /// Score for the question (e.g. 0 or 10).
    public let score: Int
    /// 是否回答正确 (得分 >= 80 视为正确)
    /// Whether the answer is correct (score >= 80 counts as correct).
    public let isCorrect: Bool
    /// 评分依据与订正反馈
    /// Grading rationale and feedback.
    public let feedback: String

    public init(id: UUID = UUID(), index: Int, score: Int, isCorrect: Bool, feedback: String) {
        self.id = id
        self.index = index
        self.score = score
        self.isCorrect = isCorrect
        self.feedback = feedback
    }

    enum CodingKeys: String, CodingKey {
        case id
        case index
        case score
        case isCorrect
        case feedback
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.index = try container.decode(Int.self, forKey: .index)
        self.score = try container.decode(Int.self, forKey: .score)
        self.isCorrect = try container.decode(Bool.self, forKey: .isCorrect)
        self.feedback = try container.decode(String.self, forKey: .feedback)
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(index, forKey: .index)
        try container.encode(score, forKey: .score)
        try container.encode(isCorrect, forKey: .isCorrect)
        try container.encode(feedback, forKey: .feedback)
    }
}

/// LLM 自测评分整卷结果
/// LLM grading response for the whole quiz.
public struct QuizGradingResponse: Codable, Sendable {
    public let totalScore: Int
    public let results: [QuizQuestionGradingResult]

    public init(totalScore: Int, results: [QuizQuestionGradingResult]) {
        self.totalScore = totalScore
        self.results = results
    }
}
