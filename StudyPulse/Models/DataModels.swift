//
//  DataModels.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import Foundation

// MARK: - Subject Models (科目)

/// 用户科目模型，支持自定义满分和显示名称
nonisolated struct Subject: Identifiable, Codable, Hashable {
    var id = UUID()
    /// 科目内部标识名（英文，如 "Mathematics"）
    var name: String
    /// 是否启用该科目
    var enabled: Bool
    /// 科目满分（可自定义）
    var fullScore: Double
    /// 科目显示名称（支持中文，如 "数学"）
    var displayName: String
    
    /// 创建科目
    /// - Parameters:
    ///   - name: 科目内部标识名
    ///   - displayName: 显示名称，默认与 name 相同
    ///   - enabled: 是否启用，默认 true
    ///   - fullScore: 满分，默认 100
    init(name: String, displayName: String? = nil, enabled: Bool = true, fullScore: Double = 100) {
        self.name = name
        self.displayName = displayName ?? name
        self.enabled = enabled
        self.fullScore = fullScore
    }
}

// MARK: - Grade Records (成绩记录)

/// 单条成绩记录，包含科目、分数、排名等信息
nonisolated struct Grade: Identifiable, Codable {
    var id = UUID()
    /// 科目名称
    var subject: String
    /// 实际得分
    var score: Double
    /// 赋分时的卷面分（如浙江高考赋分制）
    var rawScore: Double?
    /// 排名（可选）
    var ranking: Int?
    /// 重要程度（1-5 星）
    var importance: Int
    /// 卷面图片数据（兼容旧方案，新数据使用 imageFileName）
    var image: Data?
    /// 图片文件路径（新方案，存储于文件系统）
    var imageFileName: String?
    /// 录入日期
    var date: Date
    /// 考试名称
    var examName: String
    /// 该成绩对应的满分（为空时取科目配置的满分）
    var fullScore: Double? = nil
    
    /// 计算得分率
    /// - Parameter subjectFullScore: 科目默认满分（可选，优先使用成绩自带的满分）
    /// - Returns: 得分率（0.0 - 1.0）
    func scoreRate(subjectFullScore: Double = 100) -> Double {
        let totalFullScore = fullScore ?? subjectFullScore
        guard totalFullScore > 0 else { return 0 }
        return score / totalFullScore
    }
    
    /// 创建成绩记录
    init(subject: String, score: Double, rawScore: Double? = nil, ranking: Int? = nil,
         importance: Int = 3, image: Data? = nil, imageFileName: String? = nil,
         date: Date = Date(), examName: String = "", fullScore: Double? = nil) {
        self.subject = subject
        self.score = score
        self.rawScore = rawScore
        self.ranking = ranking
        self.importance = min(max(importance, 1), 5)
        self.image = image
        self.imageFileName = imageFileName
        self.date = date
        self.examName = examName
        self.fullScore = fullScore
    }
    
    /// 获取图片数据：优先从 imageFileName 加载，回退到内嵌 image
    @MainActor func getImage() -> Data? {
        if let fileName = imageFileName {
            return DataManager.shared.loadGradeImage(filename: fileName)
        }
        return image
    }
}

// MARK: - Mistake Notes (错题笔记)

/// 错题笔记模型，支持四段式编辑（原题/错因/错误解法/正确解法）
nonisolated struct MistakeNote: Identifiable, Codable {
    var id = UUID()
    /// 题目标题
    var title: String
    /// 所属科目
    var subject: String
    /// 原题内容
    var originalQuestion: String
    /// 题目来源
    var source: String
    /// 录入日期
    var date: Date
    /// 错误原因分析
    var errorReason: String
    /// 错误解法
    var wrongSolution: String
    /// 正确解法
    var correctSolution: String
    /// 题目图片
    var questionImages: [Data]
    /// 错因图片
    var reasonImages: [Data]
    /// 错误解法图片
    var wrongSolutionImages: [Data]
    /// 正确解法图片
    var correctSolutionImages: [Data]
    /// 间隔重复（SRS）状态，nil = 未加入复习队列
    /// Spaced repetition state; nil means not enrolled in the review queue.
    var reviewState: ReviewState?

    init(title: String, subject: String = "", originalQuestion: String, source: String, date: Date = Date(),
         errorReason: String, wrongSolution: String, correctSolution: String,
         questionImages: [Data] = [], reasonImages: [Data] = [],
         wrongSolutionImages: [Data] = [], correctSolutionImages: [Data] = [],
         reviewState: ReviewState? = nil) {
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
        self.reviewState = reviewState
    }
}

// MARK: - User Profile (用户资料)

/// 用户资料模型，包含个人信息、教育阶段、目标等
nonisolated struct UserProfile: Codable {
    /// 用户名（显示名称）
    var username: String = "Student"
    /// 年龄
    var age: Int = 16
    /// 教育水平（旧字段）
    var educationLevel: String = "High School"
    /// 教育体系（旧字段）
    var educationSystem: String = "National Curriculum"
    /// 地区（旧字段）
    var region: String = "China"
    /// 已选科目列表
    var selectedSubjects: [Subject] = []
    /// 主题模式（Auto / Light / Dark）
    var theme: String = "Auto"
    /// 头像文件路径（存储于文件系统）
    var avatarFileName: String? = nil
    
    // MARK: - 新增详细资料字段
    
    /// 真实姓名
    var realName: String = ""
    /// 年级（如：高一、初三）
    var grade: String = ""
    /// 班级
    var className: String = ""
    /// 学校名称
    var schoolName: String = ""
    /// 学号
    var studentId: String = ""
    /// 入学年份
    var enrollmentYear: Int = Calendar.current.component(.year, from: Date())
    /// 考试年份（如高考年份）
    var examYear: Int = Calendar.current.component(.year, from: Date())
    /// 教育阶段（EducationStage rawValue）
    var educationStage: String = "High School"
    /// 地区代码（EducationRegion.name）
    var regionCode: String = "mainland"
    /// 性别
    var gender: String = "Not Specified"
    /// 目标学校
    var targetSchool: String = ""
    /// 目标总分
    var targetScore: Double = 0
}

// MARK: - Exam Time Slot (考试时间段)

/// 考试时间段（开始和结束时间）
nonisolated struct ExamTimeSlot: Codable, Hashable, Sendable {
    var startTime: Date
    var endTime: Date
}

// MARK: - Exam Models (考试)

/// 单科目考试
nonisolated struct Exam: Identifiable, Codable, Hashable {
    var id = UUID()
    /// 考试名称
    var name: String
    /// 考试开始日期
    var examDate: Date
    /// 考试结束日期（多日考试，nil 表示与开始日期相同）
    var examEndDate: Date?
    /// 重要程度（1-5 星）
    var importance: Int
    /// 科目名称
    var subject: String
    /// 考试别称（如 "期中考试"）
    var examName: String
    /// 掌握程度（0-100）
    var masteryDegree: Int

	/// 考试具体时间（用于日历同步，nil 时表示全天事件）
	var timeSlot: ExamTimeSlot?
    
    init(name: String, date: Date, importance: Int, subject: String, examName: String, masteryDegree: Int, timeSlot: ExamTimeSlot? = nil, examEndDate: Date? = nil) {
        self.name = name
        self.examDate = date
        self.importance = importance
        self.subject = subject
        self.examName = examName
        self.masteryDegree = masteryDegree
		self.timeSlot = timeSlot
        self.examEndDate = examEndDate
    }
}

/// 多科目综合考试
nonisolated struct comprehensiveExam: Identifiable, Codable, Hashable {
    var id = UUID()
    /// 考试名称
    var name: String
    /// 考试开始日期
    var examDate: Date
    /// 考试结束日期（多日考试，nil 表示与开始日期相同）
    var examEndDate: Date?
    /// 重要程度（1-5 星）
    var importance: Int
    /// 科目列表
    var subject: [String]
    /// 考试别称
    var examName: String
    /// 掌握程度（0-100）
    var masteryDegree: Int

	/// 各科目具体时间（用于日历同步，nil 时表示全天事件）
	var subjectTimeSlots: [String: ExamTimeSlot]?
    
    init(name: String, date: Date, importance: Int, subject: [String],examName: String, masteryDegree: Int, examEndDate: Date? = nil, subjectTimeSlots: [String: ExamTimeSlot]? = nil) {
        self.name = name
        self.examDate = date
        self.examEndDate = examEndDate
        self.importance = importance
        self.subject = subject
        self.examName = examName
        self.masteryDegree = masteryDegree
		self.subjectTimeSlots = subjectTimeSlots
    }
}
