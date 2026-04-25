//
//  DataModels.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import Foundation

// MARK: - 图表数据点 (补全了原代码缺失的部分)
struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let score: Double
    let scoreRate: Double // 得分率 (0.0 - 1.0)
}

struct Subject: Identifiable, Codable {
    var id = UUID()
    var name: String
    var enabled: Bool
    
    init(name: String, enabled: Bool = true) {
        self.name = name
        self.enabled = enabled
    }
}

struct Grade: Identifiable, Codable {
    var id = UUID()
    var subject: String
    var score: Double
    var rawScore: Double? // 赋分时的卷面分
    var ranking: Int?
    var importance: Int // 1-5星
    var image: Data? // 卷面图片
    var date: Date
    var examName: String
    
    var scoreRate: Double {
            // 这里简单假设满分是150，你可以根据 subject 动态判断
            let fullScore: Double = 150.0
            return score / fullScore
    }
    
    
    init(subject: String, score: Double, rawScore: Double? = nil, ranking: Int? = nil,
         importance: Int = 3, image: Data? = nil, date: Date = Date(), examName: String = "") {
        self.subject = subject
        self.score = score
        self.rawScore = rawScore
        self.ranking = ranking
        self.importance = min(max(importance, 1), 5)
        self.image = image
        self.date = date
        self.examName = examName
    }
}

struct MistakeNote: Identifiable, Codable {
    var id = UUID()
    var title: String
    var originalQuestion: String
    var source: String
    var date: Date
    var errorReason: String
    var wrongSolution: String
    var correctSolution: String
    var images: [Data] // 原题、错解、正解的图片
    
    init(title: String, originalQuestion: String, source: String, date: Date = Date(),
         errorReason: String, wrongSolution: String, correctSolution: String, images: [Data] = []) {
        self.title = title
        self.originalQuestion = originalQuestion
        self.source = source
        self.date = date
        self.errorReason = errorReason
        self.wrongSolution = wrongSolution
        self.correctSolution = correctSolution
        self.images = images
    }
}

struct UserProfile: Codable {
    var username: String = "Student"
    var age: Int = 16
    var educationLevel: String = "High School"
    var educationSystem: String = "National Curriculum"
    var region: String = "China"
    var selectedSubjects: [Subject] = []
    var theme: String = "Auto" // Auto, Light, Dark
}

struct Exam: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var examDate: Date
    var importance: Int
    var subject: String
    var examName: String
    var masteryDegree: Int
    
    init(name: String, date: Date, importance: Int, subject: String, examName: String, masteryDegree: Int) {
        self.name = name
        self.examDate = date
        self.importance = importance
        self.subject = subject
        self.examName = examName
        self.masteryDegree = masteryDegree
    }
}

struct comprehensiveExam: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var examDate: Date
    var importance: Int
    var subject: [String]
    var examName: String
    var masteryDegree: Int
    
    init(name: String, date: Date, importance: Int, subject: [String],examName: String, masteryDegree: Int) {
        self.name = name
        self.examDate = date
        self.importance = importance
        self.subject = subject
        self.examName = examName
        self.masteryDegree = masteryDegree
    }
}
