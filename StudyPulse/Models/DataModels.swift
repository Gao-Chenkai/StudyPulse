//
//  DataModels.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import Foundation

// MARK: - Study Phase (学期 / 假期阶段)

/// 学期 / 假期阶段 / 考试冲刺等用户自定义时间段。
/// 用来给历史数据划定边界,避免多年错题混在一起。
/// Study phase: a user-defined time window (semester / break / sprint) used
/// to scope grades / mistakes / exams / tasks so historical data stays bounded.
nonisolated struct StudyPhase: Identifiable, Codable, Hashable {
    var id: UUID
    /// 阶段名称,如 "2026 春季学期" / "2026 暑假" / "高考冲刺"
    var name: String
    /// 阶段开始日期
    var startDate: Date
    /// 阶段结束日期
    var endDate: Date
    /// 是否已归档(已归档的阶段在主列表默认折叠,但仍可查看历史数据)
    var isArchived: Bool
    /// 归档时间
    var archivedAt: Date?
    /// 阶段内目标(科目 + 目标分 + 文字备注)
    var goals: [PhaseGoal]
    /// 创建时间
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        startDate: Date,
        endDate: Date,
        isArchived: Bool = false,
        archivedAt: Date? = nil,
        goals: [PhaseGoal] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.isArchived = isArchived
        self.archivedAt = archivedAt
        self.goals = goals
        self.createdAt = createdAt
    }
}

/// 阶段内目标:绑定一个科目 + 目标分 + 自由文字备注。
/// Phase goal: subject + target score + free-form note.
nonisolated struct PhaseGoal: Identifiable, Codable, Hashable {
    var id: UUID
    /// 关联的科目名称(对应 Subject.name)
    var subject: String
    /// 目标分数(可以为 0,表示仅备注)
    var targetScore: Double
    /// 备注,例如 "期末数学 ≥ 120"
    var notes: String

    init(
        id: UUID = UUID(),
        subject: String,
        targetScore: Double = 0,
        notes: String = ""
    ) {
        self.id = id
        self.subject = subject
        self.targetScore = targetScore
        self.notes = notes
    }
}

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
    init(id: UUID = UUID(), name: String, displayName: String? = nil, enabled: Bool = true, fullScore: Double = 100) {
        self.id = id
        self.name = name
        self.displayName = displayName ?? name
        self.enabled = enabled
        self.fullScore = fullScore
    }
}

// MARK: - Grade Records (成绩记录)

/// 单条成绩记录，包含科目、分数、排名等信息
nonisolated struct Grade: Identifiable, Codable, Hashable {
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
    /// 归属阶段(学期/假期),nil = 未归类 / 全部数据视图
    var phaseId: UUID? = nil

    /// 计算得分率
    /// - Parameter subjectFullScore: 科目默认满分（可选，优先使用成绩自带的满分）
    /// - Returns: 得分率（0.0 - 1.0）
    func scoreRate(subjectFullScore: Double = 100) -> Double {
        let totalFullScore = fullScore ?? subjectFullScore
        guard totalFullScore > 0 else { return 0 }
        return score / totalFullScore
    }
    
    /// 创建成绩记录
    init(id: UUID = UUID(), subject: String, score: Double, rawScore: Double? = nil, ranking: Int? = nil,
         importance: Int = 3, image: Data? = nil, imageFileName: String? = nil,
         date: Date = Date(), examName: String = "", fullScore: Double? = nil, phaseId: UUID? = nil) {
        self.id = id
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
        self.phaseId = phaseId
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
nonisolated struct MistakeNote: Identifiable, Codable, Hashable {
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
    /// 归属阶段(学期/假期),nil = 未归类 / 全部数据视图
    var phaseId: UUID? = nil
    /// 曝光次数：被翻看（详情页）或复习（闪卡）的累计次数
    /// Total times this mistake has been viewed (detail) or reviewed (flashcard).
    var exposureCount: Int = 0
    /// 当前掌握度（0-1）。每次答对/答错/评分后由 EMA 算法动态调整。
    /// Current mastery score (0-1), updated by EMA after each review.
    var masteryScore: Double = 0.0
    /// 掌握度历史轨迹：每次复习后追加一个点，画折线图用
    /// Mastery history (timestamp + score + quality). Drives the line chart.
    var masteryHistory: [MasteryHistoryEntry] = []

    init(id: UUID = UUID(), title: String, subject: String = "", originalQuestion: String, source: String, date: Date = Date(),
         errorReason: String, wrongSolution: String, correctSolution: String,
         questionImages: [Data] = [], reasonImages: [Data] = [],
         wrongSolutionImages: [Data] = [], correctSolutionImages: [Data] = [],
         reviewState: ReviewState? = nil, phaseId: UUID? = nil,
         exposureCount: Int = 0, masteryScore: Double = 0.0,
         masteryHistory: [MasteryHistoryEntry] = []) {
        self.id = id
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
        self.phaseId = phaseId
        self.exposureCount = exposureCount
        self.masteryScore = masteryScore
        self.masteryHistory = masteryHistory
    }

    // 自定义解码器：缺字段时使用默认值，兼容老版本 JSON / SwiftData 数据
    // Custom decoder: fall back to defaults so older serialized mistakes
    // (without exposureCount / masteryScore / masteryHistory) still decode.
    enum CodingKeys: String, CodingKey {
        case id, title, subject, originalQuestion, source, date
        case errorReason, wrongSolution, correctSolution
        case questionImages, reasonImages, wrongSolutionImages, correctSolutionImages
        case reviewState, phaseId
        case exposureCount, masteryScore, masteryHistory
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.title = try c.decode(String.self, forKey: .title)
        self.subject = try c.decodeIfPresent(String.self, forKey: .subject) ?? ""
        self.originalQuestion = try c.decode(String.self, forKey: .originalQuestion)
        self.source = try c.decodeIfPresent(String.self, forKey: .source) ?? ""
        self.date = try c.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        self.errorReason = try c.decode(String.self, forKey: .errorReason)
        self.wrongSolution = try c.decode(String.self, forKey: .wrongSolution)
        self.correctSolution = try c.decode(String.self, forKey: .correctSolution)
        self.questionImages = try c.decodeIfPresent([Data].self, forKey: .questionImages) ?? []
        self.reasonImages = try c.decodeIfPresent([Data].self, forKey: .reasonImages) ?? []
        self.wrongSolutionImages = try c.decodeIfPresent([Data].self, forKey: .wrongSolutionImages) ?? []
        self.correctSolutionImages = try c.decodeIfPresent([Data].self, forKey: .correctSolutionImages) ?? []
        self.reviewState = try c.decodeIfPresent(ReviewState.self, forKey: .reviewState)
        self.phaseId = try c.decodeIfPresent(UUID.self, forKey: .phaseId)
        self.exposureCount = try c.decodeIfPresent(Int.self, forKey: .exposureCount) ?? 0
        self.masteryScore = try c.decodeIfPresent(Double.self, forKey: .masteryScore) ?? 0.0
        self.masteryHistory = try c.decodeIfPresent([MasteryHistoryEntry].self, forKey: .masteryHistory) ?? []
    }
}

// MARK: - Mastery History Entry (掌握度历史)

/// 掌握度历史的一个点：某次复习后记录的 (时间, 掌握度, 自评档位)。
/// One point in the mastery history: (timestamp, score, quality) recorded after each review.
nonisolated struct MasteryHistoryEntry: Identifiable, Codable, Hashable {
    var id: UUID
    /// 记录时间
    var timestamp: Date
    /// 当时点的掌握度（0-1）
    var score: Double
    /// 自评档位（ReviewQuality.rawValue：1 / 3 / 4 / 5）
    /// 0 = 仅查看详情（不评分）
    var quality: Int

    init(id: UUID = UUID(), timestamp: Date = Date(), score: Double, quality: Int) {
        self.id = id
        self.timestamp = timestamp
        self.score = score
        self.quality = quality
    }

    /// 自评档位的人类可读名（用于 chart tooltip）
    /// Human-readable label for the review quality.
    var qualityLabel: String {
        switch quality {
        case 0:  return "View".localized()
        case 1:  return "Again".localized()
        case 3:  return "Hard".localized()
        case 4:  return "Good".localized()
        case 5:  return "Easy".localized()
        default: return "\(quality)"
        }
    }
}

// MARK: - Mastery Algorithm (掌握度算法)

/// 掌握度动态调整算法（pure Swift，nonisolated）。
/// Mastery score update algorithm.
///
/// 用 EMA（指数移动平均）做平滑更新：
///   newScore = oldScore * (1 - α) + target * α
///   α = 基础学习率 / (1 + 复习次数 × 0.15)
///
/// 含义：前几次复习影响大（α 接近 0.3），之后学习率衰减，
/// 防止一次失误把已经很稳的掌握度拉垮；也防止一次蒙对就误判已掌握。
enum MasteryAlgorithm {
    /// 基础学习率（首次复习时的权重）
    static let baseLearningRate: Double = 0.30
    /// 学习率衰减系数
    static let learningRateDecay: Double = 0.15

    /// 把 4 档自评映射为 0-1 之间的「目标掌握度」
    /// Map the 4 review qualities to a 0-1 target mastery.
    /// - again=0.05（基本不会）
    /// - hard=0.40（勉强）
    /// - good=0.70（掌握）
    /// - easy=0.95（精通）
    static func targetScore(for quality: ReviewQuality) -> Double {
        switch quality {
        case .again: return 0.05
        case .hard:  return 0.40
        case .good:  return 0.70
        case .easy:  return 0.95
        }
    }

    /// 计算当前学习率 α。
    /// Learning rate shrinks as exposure count grows so the curve stabilizes.
    static func learningRate(exposureCount: Int) -> Double {
        let n = max(0, exposureCount)
        let alpha = baseLearningRate / (1.0 + Double(n) * learningRateDecay)
        return min(baseLearningRate, max(0.05, alpha))
    }

    /// 一次性算出新的 (score, historyEntry) 元组。
    /// Compute the new score and the history entry to append in one pass.
    /// - Parameters:
    ///   - oldScore: 当前掌握度
    ///   - exposureCount: 当前曝光次数（review 前）
    ///   - quality: 这次的自评档位
    ///   - now: 时间戳
    /// - Returns: (newScore, historyEntry)
    static func apply(
        oldScore: Double,
        exposureCount: Int,
        quality: ReviewQuality,
        now: Date = Date()
    ) -> (score: Double, entry: MasteryHistoryEntry) {
        let target = targetScore(for: quality)
        let alpha = learningRate(exposureCount: exposureCount)
        let newScore = max(0.0, min(1.0, oldScore * (1.0 - alpha) + target * alpha))
        let entry = MasteryHistoryEntry(timestamp: now, score: newScore, quality: quality.rawValue)
        return (newScore, entry)
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

// MARK: - Task Models (作业 / 阅读材料)

/// 任务类型：日常作业 / 阅读材料
/// Task type: daily homework or reading material
nonisolated enum TaskType: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    /// 日常作业 / Daily homework
    case homework
    /// 阅读材料 / Reading material
    case reading

    var id: String { rawValue }
}

/// 统一待办条目（视图层把考试 / 作业 / 阅读统一渲染为同一张列表）
/// Unified todo entry used by the view layer to render exams / homework / reading in one list.
nonisolated enum TodoEntryKind: String, Codable, Hashable, Sendable {
    /// 单科目考试 / Single-subject exam
    case exam
    /// 综合考试 / Comprehensive exam
    case comprehensiveExam
    /// 日常作业 / Daily homework
    case homework
    /// 阅读材料 / Reading material
    case reading
}

/// 待办列表统一渲染的条目结构
/// A unified row item used by the Todo page.
nonisolated struct TodoEntry: Identifiable, Hashable, Sendable {
    let id: UUID
    let kind: TodoEntryKind
    let title: String
    let subject: String
    /// 截止 / 起始时间（按 kind 不同：考试 = 考试开始；作业 / 阅读 = 截止日期）
    let date: Date
    /// 结束时间（仅多日考试使用，其它 kind 为 nil）
    let endDate: Date?
    let importance: Int
    let isCompleted: Bool
    /// 关联的源数据（仅一个非空）
    let exam: Exam?
    let comprehensiveExam: comprehensiveExam?
    let taskItem: TaskItem?
}

/// 作业 / 阅读材料任务项
/// Homework or reading material task item.
nonisolated struct TaskItem: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    /// 任务标题
    /// Task title
    var title: String
    /// 任务类型（homework / reading）
    /// Task type (homework / reading)
    var type: TaskType
    /// 截止日期
    /// Due date
    var dueDate: Date
    /// 提醒时间（通常早于 dueDate，驱动 EKReminder alarm）
    /// Reminder time (usually earlier than dueDate, drives EKReminder alarm)
    var reminderDate: Date
    /// 关联科目名称（可空）
    /// Related subject name (optional)
    var subject: String
    /// 重要程度（1-5 星）
    /// Importance (1-5 stars)
    var importance: Int
    /// 备注
    /// Notes
    var notes: String
    /// 是否已完成
    /// Whether the task is completed
    var isCompleted: Bool
    /// 关联到系统 Reminders 后的 calendarItemIdentifier
    /// Linked EKReminder calendarItemIdentifier after syncing to Reminders
    var reminderEventId: String?
    /// 关联到系统 Reminders 使用的 calendar identifier（用于更新）
    /// Linked EKReminder calendar identifier (for updating)
    var reminderCalendarId: String?
    /// 创建时间
    /// Created at
    var createdAt: Date
    /// 归属阶段(学期/假期),nil = 未归类 / 全部数据视图
    var phaseId: UUID? = nil

    init(
        id: UUID = UUID(),
        title: String,
        type: TaskType,
        dueDate: Date,
        reminderDate: Date,
        subject: String = "",
        importance: Int = 3,
        notes: String = "",
        isCompleted: Bool = false,
        reminderEventId: String? = nil,
        reminderCalendarId: String? = nil,
        createdAt: Date = Date(),
        phaseId: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.dueDate = dueDate
        self.reminderDate = reminderDate
        self.subject = subject
        self.importance = min(max(importance, 1), 5)
        self.notes = notes
        self.isCompleted = isCompleted
        self.reminderEventId = reminderEventId
        self.reminderCalendarId = reminderCalendarId
        self.createdAt = createdAt
        self.phaseId = phaseId
    }
}

// MARK: - Exam Checklist Item (考前待办)

/// 考前待办条目:身份证 / 准考证 / 文具 / 复习清单等,可勾选。
/// Pre-exam checklist item (ID, admission ticket, stationery, review list, etc).
nonisolated struct ExamChecklistItem: Identifiable, Codable, Hashable {
    var id: UUID
    /// 待办标题（如 "身份证"、"2B 铅笔"）
    var title: String
    /// 是否已勾选
    var isChecked: Bool
    /// 排序顺序,值越小越靠前
    var sortOrder: Int

    init(id: UUID = UUID(), title: String, isChecked: Bool = false, sortOrder: Int = 0) {
        self.id = id
        self.title = title
        self.isChecked = isChecked
        self.sortOrder = sortOrder
    }
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
    /// 归属阶段(学期/假期),nil = 未归类 / 全部数据视图
    var phaseId: UUID? = nil
    /// 考前待办清单（身份证、准考证、文具、复习清单等）
    /// Pre-exam checklist (ID, admission ticket, stationery, review list...)
    var checklist: [ExamChecklistItem] = []
    /// 考场学校
    var locationSchool: String = ""
    /// 教室 / 考场号
    var locationClassroom: String = ""
    /// 座位号
    var locationSeat: String = ""
    /// 考前 N 天倒计时通知；nil = 使用默认 [1, 3, 5, 10, 30]
    /// 空数组 = 关闭通知
    var countdownNotifyDays: [Int]? = nil

    init(id: UUID = UUID(), name: String, date: Date, importance: Int, subject: String, examName: String, masteryDegree: Int, timeSlot: ExamTimeSlot? = nil, examEndDate: Date? = nil, phaseId: UUID? = nil, checklist: [ExamChecklistItem] = [], locationSchool: String = "", locationClassroom: String = "", locationSeat: String = "", countdownNotifyDays: [Int]? = nil) {
        self.id = id
        self.name = name
        self.examDate = date
        self.importance = importance
        self.subject = subject
        self.examName = examName
        self.masteryDegree = masteryDegree
		self.timeSlot = timeSlot
        self.examEndDate = examEndDate
        self.phaseId = phaseId
        self.checklist = checklist
        self.locationSchool = locationSchool
        self.locationClassroom = locationClassroom
        self.locationSeat = locationSeat
        self.countdownNotifyDays = countdownNotifyDays
    }

    // 自定义解码器：缺字段时使用默认值，兼容老版本 JSON / SwiftData 数据
    // Custom decoder: fall back to defaults for missing fields so older
    // serialized exams (without checklist / location / countdownNotifyDays)
    // continue to decode instead of throwing.
    enum CodingKeys: String, CodingKey {
        case id, name, examDate, examEndDate, importance, subject, examName, masteryDegree, timeSlot, phaseId, checklist, locationSchool, locationClassroom, locationSeat, countdownNotifyDays
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try c.decode(String.self, forKey: .name)
        self.examDate = try c.decode(Date.self, forKey: .examDate)
        self.examEndDate = try c.decodeIfPresent(Date.self, forKey: .examEndDate)
        self.importance = try c.decodeIfPresent(Int.self, forKey: .importance) ?? 3
        self.subject = try c.decodeIfPresent(String.self, forKey: .subject) ?? ""
        self.examName = try c.decodeIfPresent(String.self, forKey: .examName) ?? ""
        self.masteryDegree = try c.decodeIfPresent(Int.self, forKey: .masteryDegree) ?? 0
        self.timeSlot = try c.decodeIfPresent(ExamTimeSlot.self, forKey: .timeSlot)
        self.phaseId = try c.decodeIfPresent(UUID.self, forKey: .phaseId)
        self.checklist = try c.decodeIfPresent([ExamChecklistItem].self, forKey: .checklist) ?? []
        self.locationSchool = try c.decodeIfPresent(String.self, forKey: .locationSchool) ?? ""
        self.locationClassroom = try c.decodeIfPresent(String.self, forKey: .locationClassroom) ?? ""
        self.locationSeat = try c.decodeIfPresent(String.self, forKey: .locationSeat) ?? ""
        self.countdownNotifyDays = try c.decodeIfPresent([Int].self, forKey: .countdownNotifyDays)
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
    /// 归属阶段(学期/假期),nil = 未归类 / 全部数据视图
    var phaseId: UUID? = nil

    init(id: UUID = UUID(), name: String, date: Date, importance: Int, subject: [String],examName: String, masteryDegree: Int, examEndDate: Date? = nil, subjectTimeSlots: [String: ExamTimeSlot]? = nil, phaseId: UUID? = nil) {
        self.id = id
        self.name = name
        self.examDate = date
        self.importance = importance
        self.subject = subject
        self.examName = examName
        self.masteryDegree = masteryDegree
		self.subjectTimeSlots = subjectTimeSlots
        self.phaseId = phaseId
    }
}
