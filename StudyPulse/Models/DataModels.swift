//
//  DataModels.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import Foundation

// MARK: - 图表数据点 (补全了原代码缺失的部分)
//struct ChartDataPoint: Identifiable {
//    let id = UUID()
//    let date: Date
//    let score: Double
//    let scoreRate: Double // 得分率 (0.0 - 1.0)
//}

nonisolated struct Subject: Identifiable, Codable {
    var id = UUID()
    var name: String
    var enabled: Bool
    
    init(name: String, enabled: Bool = true) {
        self.name = name
        self.enabled = enabled
    }
}

nonisolated struct Grade: Identifiable, Codable {
    var id = UUID()
    var subject: String
    var score: Double
    var rawScore: Double? // 赋分时的卷面分
    var ranking: Int?
    var importance: Int // 1-5星
    var image: Data? // 卷面图片（兼容旧数据，新数据使用 imageFileName）
    var imageFileName: String? // 图片文件路径（新方案，存文件系统）
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
    
    /// 获取图片数据：优先从 imageFileName 加载，回退到内嵌 image
    @MainActor func getImage() -> Data? {
        if let fileName = imageFileName {
            return DataManager.shared.loadGradeImage(filename: fileName)
        }
        return image
    }
}

nonisolated struct MistakeNote: Identifiable, Codable {
    var id = UUID()
    var title: String
    var subject: String // 科目
    var originalQuestion: String
    var source: String
    var date: Date
    var errorReason: String
    var wrongSolution: String
    var correctSolution: String
    var questionImages: [Data]      // 题目图片
    var reasonImages: [Data]        // 错因图片
    var wrongSolutionImages: [Data] // 错误解法图片
    var correctSolutionImages: [Data] // 正确解法图片
    
    init(title: String, subject: String = "", originalQuestion: String, source: String, date: Date = Date(),
         errorReason: String, wrongSolution: String, correctSolution: String,
         questionImages: [Data] = [], reasonImages: [Data] = [],
         wrongSolutionImages: [Data] = [], correctSolutionImages: [Data] = []) {
        self.title = title
        self.subject = subject
        self.originalQuestion = originalQuestion
        self.source = source
        self.date = date
        self.errorReason = errorReason
        self.wrongSolution = wrongSolution
        self.correctSolution = correctSolution
        self.questionImages = questionImages
        self.reasonImages = reasonImages
        self.wrongSolutionImages = wrongSolutionImages
        self.correctSolutionImages = correctSolutionImages
    }
}

nonisolated struct UserProfile: Codable {
    var username: String = "Student"
    var age: Int = 16
    var educationLevel: String = "High School"
    var educationSystem: String = "National Curriculum"
    var region: String = "China"
    var selectedSubjects: [Subject] = []
    var theme: String = "Auto" // Auto, Light, Dark
}

nonisolated struct Exam: Identifiable, Codable, Hashable {
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

nonisolated struct comprehensiveExam: Identifiable, Codable, Hashable {
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
