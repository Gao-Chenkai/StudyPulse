//
//  StudyPulseModels.swift
//  StudyPulse
//
//  SwiftData @Model 实体层。
//  SwiftData @Model entity layer.
//
//  设计：
//  - 每个业务模型都有一个对应的 @Model 实体（SubjectEntity / GradeEntity / ...）
//  - 实体字段对应原 struct 的字段；嵌套类型（ExamTimeSlot / ReviewState / [Data]）
//    被拍平为基本类型字段（[String] / Date / @Attribute(.externalStorage) Data）
//  - 实体与 struct 互转用 toSnapshot() / init(from:)
//  - 视图层继续用原 struct（DataManager @Published 暴露 [struct]），不需要改 view
//
//  Design:
//  - Each domain model has a corresponding @Model entity (SubjectEntity / GradeEntity / ...)
//  - Entity fields mirror the struct's; nested types (ExamTimeSlot / ReviewState / [Data])
//    are flattened to primitive fields ([String] / Date / @Attribute(.externalStorage) Data)
//  - Use toSnapshot() / init(from:) to convert
//  - Views keep using the struct types via DataManager's @Published arrays — no view changes
//

import Foundation
import SwiftData

// MARK: - Subject

@Model
final class SubjectRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var enabled: Bool
    var fullScore: Double
    var displayName: String

    init(id: UUID, name: String, enabled: Bool, fullScore: Double, displayName: String) {
        self.id = id
        self.name = name
        self.enabled = enabled
        self.fullScore = fullScore
        self.displayName = displayName
    }

    convenience init(from subject: Subject) {
        self.init(
            id: subject.id,
            name: subject.name,
            enabled: subject.enabled,
            fullScore: subject.fullScore,
            displayName: subject.displayName
        )
    }

    func toSnapshot() -> Subject {
        Subject(
            id: id,
            name: name,
            displayName: displayName,
            enabled: enabled,
            fullScore: fullScore
        )
    }
}

// MARK: - Grade

@Model
final class GradeRecord {
    // 索引: 业务高频过滤字段;SwiftData 编译器会为这些字段建 B-Tree
    // 让 SortDescriptor(\.date, order: .reverse) / subject == X 等谓词走索引
    #Index<GradeRecord>([\.subject, \.date], [\.phaseId], [\.date])

    @Attribute(.unique) var id: UUID
    var subject: String
    var score: Double
    var rawScore: Double?
    var ranking: Int?
    var importance: Int
    /// 卷面图片（兼容旧数据，外部存储避免占内存）
    @Attribute(.externalStorage) var image: Data?
    var imageFileName: String?
    var date: Date
    var examName: String
    var fullScore: Double?
    /// 归属阶段 ID（关联 StudyPhaseRecord.id），nil = 未归类
    var phaseId: UUID?

    init(
        id: UUID,
        subject: String,
        score: Double,
        rawScore: Double?,
        ranking: Int?,
        importance: Int,
        image: Data?,
        imageFileName: String?,
        date: Date,
        examName: String,
        fullScore: Double?,
        phaseId: UUID? = nil
    ) {
        self.id = id
        self.subject = subject
        self.score = score
        self.rawScore = rawScore
        self.ranking = ranking
        self.importance = importance
        self.image = image
        self.imageFileName = imageFileName
        self.date = date
        self.examName = examName
        self.fullScore = fullScore
        self.phaseId = phaseId
    }

    convenience init(from grade: Grade) {
        self.init(
            id: grade.id,
            subject: grade.subject,
            score: grade.score,
            rawScore: grade.rawScore,
            ranking: grade.ranking,
            importance: grade.importance,
            image: grade.image,
            imageFileName: grade.imageFileName,
            date: grade.date,
            examName: grade.examName,
            fullScore: grade.fullScore,
            phaseId: grade.phaseId
        )
    }

    func toSnapshot() -> Grade {
        Grade(
            id: id,
            subject: subject,
            score: score,
            rawScore: rawScore,
            ranking: ranking,
            importance: importance,
            image: image,
            imageFileName: imageFileName,
            date: date,
            examName: examName,
            fullScore: fullScore,
            phaseId: phaseId
        )
    }
}

// MARK: - MistakeNote

@Model
final class MistakeNoteRecord {
    // 索引: SRS 队列 / 科目过滤 / 日期排序
    #Index<MistakeNoteRecord>([\.subject], [\.date], [\.phaseId], [\.srsNextReviewDate])

    @Attribute(.unique) var id: UUID
    var title: String
    var subject: String
    var originalQuestion: String
    var source: String
    var date: Date
    var errorReason: String
    var wrongSolution: String
    var correctSolution: String

    // SRS 状态（拍平为基本字段）
    var srsRepetitions: Int
    var srsEaseFactor: Double
    var srsIntervalDays: Int
    var srsNextReviewDate: Date?
    var srsLastReviewDate: Date?
    var srsLapses: Int

    // 4 段图片（拍平为 [Data]）
    @Attribute(.externalStorage) var questionImagesData: [Data]
    @Attribute(.externalStorage) var reasonImagesData: [Data]
    @Attribute(.externalStorage) var wrongSolutionImagesData: [Data]
    @Attribute(.externalStorage) var correctSolutionImagesData: [Data]
    /// 归属阶段 ID（关联 StudyPhaseRecord.id），nil = 未归类
    var phaseId: UUID?
    /// 曝光次数：详情页 / 闪卡被打开的累计次数
    var exposureCount: Int = 0
    /// 当前掌握度（0-1）
    var masteryScore: Double = 0.0
    /// 掌握度历史（JSON 编码 [MasteryHistoryEntry]）
    var masteryHistoryData: Data?

    init(
        id: UUID,
        title: String,
        subject: String,
        originalQuestion: String,
        source: String,
        date: Date,
        errorReason: String,
        wrongSolution: String,
        correctSolution: String,
        srsRepetitions: Int,
        srsEaseFactor: Double,
        srsIntervalDays: Int,
        srsNextReviewDate: Date?,
        srsLastReviewDate: Date?,
        srsLapses: Int,
        questionImagesData: [Data],
        reasonImagesData: [Data],
        wrongSolutionImagesData: [Data],
        correctSolutionImagesData: [Data],
        phaseId: UUID? = nil,
        exposureCount: Int = 0,
        masteryScore: Double = 0.0,
        masteryHistoryData: Data? = nil
    ) {
        self.id = id
        self.title = title
        self.subject = subject
        self.originalQuestion = originalQuestion
        self.source = source
        self.date = date
        self.errorReason = errorReason
        self.wrongSolution = wrongSolution
        self.correctSolution = correctSolution
        self.srsRepetitions = srsRepetitions
        self.srsEaseFactor = srsEaseFactor
        self.srsIntervalDays = srsIntervalDays
        self.srsNextReviewDate = srsNextReviewDate
        self.srsLastReviewDate = srsLastReviewDate
        self.srsLapses = srsLapses
        self.questionImagesData = questionImagesData
        self.reasonImagesData = reasonImagesData
        self.wrongSolutionImagesData = wrongSolutionImagesData
        self.correctSolutionImagesData = correctSolutionImagesData
        self.phaseId = phaseId
        self.exposureCount = exposureCount
        self.masteryScore = masteryScore
        self.masteryHistoryData = masteryHistoryData
    }

    convenience init(from note: MistakeNote) {
        let srs = note.reviewState
        let historyData: Data? = note.masteryHistory.isEmpty
            ? nil
            : try? JSONEncoder().encode(note.masteryHistory)
        self.init(
            id: note.id,
            title: note.title,
            subject: note.subject,
            originalQuestion: note.originalQuestion,
            source: note.source,
            date: note.date,
            errorReason: note.errorReason,
            wrongSolution: note.wrongSolution,
            correctSolution: note.correctSolution,
            srsRepetitions: srs?.repetitions ?? 0,
            srsEaseFactor: srs?.easeFactor ?? 2.5,
            srsIntervalDays: srs?.intervalDays ?? 0,
            srsNextReviewDate: srs?.nextReviewDate,
            srsLastReviewDate: srs?.lastReviewDate,
            srsLapses: srs?.lapses ?? 0,
            questionImagesData: note.questionImages,
            reasonImagesData: note.reasonImages,
            wrongSolutionImagesData: note.wrongSolutionImages,
            correctSolutionImagesData: note.correctSolutionImages,
            phaseId: note.phaseId,
            exposureCount: note.exposureCount,
            masteryScore: note.masteryScore,
            masteryHistoryData: historyData
        )
    }

    func toSnapshot() -> MistakeNote {
        let reviewState: ReviewState? = {
            guard let next = srsNextReviewDate else { return nil }
            return ReviewState(
                repetitions: srsRepetitions,
                easeFactor: srsEaseFactor,
                intervalDays: srsIntervalDays,
                nextReviewDate: next,
                lastReviewDate: srsLastReviewDate,
                lapses: srsLapses
            )
        }()

        let history: [MasteryHistoryEntry] = {
            guard let data = masteryHistoryData else { return [] }
            return (try? JSONDecoder().decode([MasteryHistoryEntry].self, from: data)) ?? []
        }()

        return MistakeNote(
            id: id,
            title: title,
            subject: subject,
            originalQuestion: originalQuestion,
            source: source,
            date: date,
            errorReason: errorReason,
            wrongSolution: wrongSolution,
            correctSolution: correctSolution,
            questionImages: questionImagesData,
            reasonImages: reasonImagesData,
            wrongSolutionImages: wrongSolutionImagesData,
            correctSolutionImages: correctSolutionImagesData,
            reviewState: reviewState,
            phaseId: phaseId,
            exposureCount: exposureCount,
            masteryScore: masteryScore,
            masteryHistory: history
        )
    }
}

// MARK: - Exam (单科)

@Model
final class ExamRecord {
    // 索引: examDate 用于"未来 N 天的考试"查询排序
    #Index<ExamRecord>([\.examDate], [\.phaseId])

    @Attribute(.unique) var id: UUID
    var name: String
    var examDate: Date
    var examEndDate: Date?
    var importance: Int
    var subject: String
    var examName: String
    var masteryDegree: Int
    /// 拍平 timeSlot
    var timeSlotStart: Date?
    var timeSlotEnd: Date?
    /// 归属阶段 ID（关联 StudyPhaseRecord.id），nil = 未归类
    var phaseId: UUID?
    /// 考前待办清单（JSON 编码 [ExamChecklistItem]）
    var checklistData: Data?
    /// 考场学校（SwiftData 轻量迁移需要 inline 默认值,否则老 store 打不开）
    var locationSchool: String = ""
    /// 教室 / 考场号
    var locationClassroom: String = ""
    /// 座位号
    var locationSeat: String = ""
    /// 考前 N 天倒计时通知（JSON 编码 [Int]）；nil = 字段未写入（默认计划）
    var countdownNotifyDaysData: Data?
    /// 考后复盘内容（JSON 编码 ExamReview）；nil = 尚未复盘
    /// Post-exam review content (JSON-encoded ExamReview). nil = not yet reviewed.
    var reviewData: Data?

    init(
        id: UUID,
        name: String,
        examDate: Date,
        examEndDate: Date?,
        importance: Int,
        subject: String,
        examName: String,
        masteryDegree: Int,
        timeSlotStart: Date?,
        timeSlotEnd: Date?,
        phaseId: UUID? = nil,
        checklistData: Data? = nil,
        locationSchool: String = "",
        locationClassroom: String = "",
        locationSeat: String = "",
        countdownNotifyDaysData: Data? = nil,
        reviewData: Data? = nil
    ) {
        self.id = id
        self.name = name
        self.examDate = examDate
        self.examEndDate = examEndDate
        self.importance = importance
        self.subject = subject
        self.examName = examName
        self.masteryDegree = masteryDegree
        self.timeSlotStart = timeSlotStart
        self.timeSlotEnd = timeSlotEnd
        self.phaseId = phaseId
        self.checklistData = checklistData
        self.locationSchool = locationSchool
        self.locationClassroom = locationClassroom
        self.locationSeat = locationSeat
        self.countdownNotifyDaysData = countdownNotifyDaysData
        self.reviewData = reviewData
    }

    convenience init(from exam: Exam) {
        let checklistData: Data? = exam.checklist.isEmpty ? nil : try? JSONEncoder().encode(exam.checklist)
        // 把 nil 和 [] 都当作 "未指定",用 nil 存；显式空数组也用 nil 存(语义上等价)
        let countdownData: Data?
        if let days = exam.countdownNotifyDays {
            countdownData = (try? JSONEncoder().encode(days)) ?? nil
        } else {
            countdownData = nil
        }
        let reviewData: Data? = exam.examReview.flatMap { try? JSONEncoder().encode($0) }
        self.init(
            id: exam.id,
            name: exam.name,
            examDate: exam.examDate,
            examEndDate: exam.examEndDate,
            importance: exam.importance,
            subject: exam.subject,
            examName: exam.examName,
            masteryDegree: exam.masteryDegree,
            timeSlotStart: exam.timeSlot?.startTime,
            timeSlotEnd: exam.timeSlot?.endTime,
            phaseId: exam.phaseId,
            checklistData: checklistData,
            locationSchool: exam.locationSchool,
            locationClassroom: exam.locationClassroom,
            locationSeat: exam.locationSeat,
            countdownNotifyDaysData: countdownData,
            reviewData: reviewData
        )
    }

    func toSnapshot() -> Exam {
        let timeSlot: ExamTimeSlot? = {
            if let s = timeSlotStart, let e = timeSlotEnd {
                return ExamTimeSlot(startTime: s, endTime: e)
            }
            return nil
        }()
        let checklist: [ExamChecklistItem] = {
            guard let data = checklistData else { return [] }
            return (try? JSONDecoder().decode([ExamChecklistItem].self, from: data)) ?? []
        }()
        let countdownDays: [Int]? = {
            guard let data = countdownNotifyDaysData else { return nil }
            return try? JSONDecoder().decode([Int].self, from: data)
        }()
        let examReview: ExamReview? = {
            guard let data = reviewData else { return nil }
            return try? JSONDecoder().decode(ExamReview.self, from: data)
        }()
        return Exam(
            id: id,
            name: name,
            date: examDate,
            importance: importance,
            subject: subject,
            examName: examName,
            masteryDegree: masteryDegree,
            timeSlot: timeSlot,
            examEndDate: examEndDate,
            phaseId: phaseId,
            checklist: checklist,
            locationSchool: locationSchool,
            locationClassroom: locationClassroom,
            locationSeat: locationSeat,
            countdownNotifyDays: countdownDays,
            examReview: examReview
        )
    }
}

// MARK: - ComprehensiveExam (综合)

@Model
final class ComprehensiveExamRecord {
    // 索引: examDate 用于"未来 N 天的综合考试"查询排序
    #Index<ComprehensiveExamRecord>([\.examDate], [\.phaseId])

    @Attribute(.unique) var id: UUID
    var name: String
    var examDate: Date
    var examEndDate: Date?
    var importance: Int
    /// 拍平 [String]
    var subjects: [String]
    var examName: String
    var masteryDegree: Int
    /// 拍平 subjectTimeSlots：JSON 编码后存
    var subjectTimeSlotsData: Data?
    /// 归属阶段 ID（关联 StudyPhaseRecord.id），nil = 未归类
    var phaseId: UUID?

    init(
        id: UUID,
        name: String,
        examDate: Date,
        examEndDate: Date?,
        importance: Int,
        subjects: [String],
        examName: String,
        masteryDegree: Int,
        subjectTimeSlotsData: Data?,
        phaseId: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.examDate = examDate
        self.examEndDate = examEndDate
        self.importance = importance
        self.subjects = subjects
        self.examName = examName
        self.masteryDegree = masteryDegree
        self.subjectTimeSlotsData = subjectTimeSlotsData
        self.phaseId = phaseId
    }

    convenience init(from exam: comprehensiveExam) {
        let slotsData: Data?
        if let slots = exam.subjectTimeSlots,
           let data = try? JSONEncoder().encode(slots) {
            slotsData = data
        } else {
            slotsData = nil
        }
        self.init(
            id: exam.id,
            name: exam.name,
            examDate: exam.examDate,
            examEndDate: exam.examEndDate,
            importance: exam.importance,
            subjects: exam.subject,
            examName: exam.examName,
            masteryDegree: exam.masteryDegree,
            subjectTimeSlotsData: slotsData,
            phaseId: exam.phaseId
        )
    }

    func toSnapshot() -> comprehensiveExam {
        let slots: [String: ExamTimeSlot]? = {
            guard let data = subjectTimeSlotsData else { return nil }
            return try? JSONDecoder().decode([String: ExamTimeSlot].self, from: data)
        }()
        return comprehensiveExam(
            id: id,
            name: name,
            date: examDate,
            importance: importance,
            subject: subjects,
            examName: examName,
            masteryDegree: masteryDegree,
            examEndDate: examEndDate,
            subjectTimeSlots: slots,
            phaseId: phaseId
        )
    }
}

// MARK: - TaskItem (作业 / 阅读材料)

@Model
final class TaskItemRecord {
    // 索引: dueDate 用于按时间排序;isCompleted 用于过滤未完成任务
    #Index<TaskItemRecord>([\.dueDate], [\.phaseId], [\.isCompleted])

    @Attribute(.unique) var id: UUID
    /// 任务标题
    var title: String
    /// TaskType 拍平为 rawValue
    var typeRaw: String
    /// 截止日期
    var dueDate: Date
    /// 提醒时间
    var reminderDate: Date
    /// 关联科目
    var subject: String
    /// 重要程度 1-5
    var importance: Int
    /// 备注
    var notes: String
    /// 是否已完成
    var isCompleted: Bool
    /// 关联 EKReminder 标识
    var reminderEventId: String?
    /// 关联 EKReminder 所在 calendar
    var reminderCalendarId: String?
    /// 创建时间
    var createdAt: Date
    /// 归属阶段 ID（关联 StudyPhaseRecord.id），nil = 未归类
    var phaseId: UUID?

    init(
        id: UUID,
        title: String,
        typeRaw: String,
        dueDate: Date,
        reminderDate: Date,
        subject: String,
        importance: Int,
        notes: String,
        isCompleted: Bool,
        reminderEventId: String?,
        reminderCalendarId: String?,
        createdAt: Date,
        phaseId: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.typeRaw = typeRaw
        self.dueDate = dueDate
        self.reminderDate = reminderDate
        self.subject = subject
        self.importance = importance
        self.notes = notes
        self.isCompleted = isCompleted
        self.reminderEventId = reminderEventId
        self.reminderCalendarId = reminderCalendarId
        self.createdAt = createdAt
        self.phaseId = phaseId
    }

    convenience init(from task: TaskItem) {
        self.init(
            id: task.id,
            title: task.title,
            typeRaw: task.type.rawValue,
            dueDate: task.dueDate,
            reminderDate: task.reminderDate,
            subject: task.subject,
            importance: task.importance,
            notes: task.notes,
            isCompleted: task.isCompleted,
            reminderEventId: task.reminderEventId,
            reminderCalendarId: task.reminderCalendarId,
            createdAt: task.createdAt,
            phaseId: task.phaseId
        )
    }

    func toSnapshot() -> TaskItem {
        let type = TaskType(rawValue: typeRaw) ?? .homework
        return TaskItem(
            id: id,
            title: title,
            type: type,
            dueDate: dueDate,
            reminderDate: reminderDate,
            subject: subject,
            importance: importance,
            notes: notes,
            isCompleted: isCompleted,
            reminderEventId: reminderEventId,
            reminderCalendarId: reminderCalendarId,
            createdAt: createdAt,
            phaseId: phaseId
        )
    }
}

// MARK: - UserProfile (单例)

@Model
final class UserProfileRecord {
    @Attribute(.unique) var id: UUID
    var username: String
    var age: Int
    var educationLevel: String
    var educationSystem: String
    var region: String
    /// 拍平 [Subject]
    var selectedSubjectsData: Data?
    var theme: String
    var avatarFileName: String?
    var realName: String
    var grade: String
    var className: String
    var schoolName: String
    var studentId: String
    var enrollmentYear: Int
    var examYear: Int
    var educationStage: String
    var regionCode: String
    var gender: String
    var targetSchool: String
    var targetScore: Double

    init(
        id: UUID,
        username: String,
        age: Int,
        educationLevel: String,
        educationSystem: String,
        region: String,
        selectedSubjectsData: Data?,
        theme: String,
        avatarFileName: String?,
        realName: String,
        grade: String,
        className: String,
        schoolName: String,
        studentId: String,
        enrollmentYear: Int,
        examYear: Int,
        educationStage: String,
        regionCode: String,
        gender: String,
        targetSchool: String,
        targetScore: Double
    ) {
        self.id = id
        self.username = username
        self.age = age
        self.educationLevel = educationLevel
        self.educationSystem = educationSystem
        self.region = region
        self.selectedSubjectsData = selectedSubjectsData
        self.theme = theme
        self.avatarFileName = avatarFileName
        self.realName = realName
        self.grade = grade
        self.className = className
        self.schoolName = schoolName
        self.studentId = studentId
        self.enrollmentYear = enrollmentYear
        self.examYear = examYear
        self.educationStage = educationStage
        self.regionCode = regionCode
        self.gender = gender
        self.targetSchool = targetSchool
        self.targetScore = targetScore
    }

    convenience init(from profile: UserProfile) {
        let subjectsData = try? JSONEncoder().encode(profile.selectedSubjects)
        self.init(
            id: UUID(),
            username: profile.username,
            age: profile.age,
            educationLevel: profile.educationLevel,
            educationSystem: profile.educationSystem,
            region: profile.region,
            selectedSubjectsData: subjectsData,
            theme: profile.theme,
            avatarFileName: profile.avatarFileName,
            realName: profile.realName,
            grade: profile.grade,
            className: profile.className,
            schoolName: profile.schoolName,
            studentId: profile.studentId,
            enrollmentYear: profile.enrollmentYear,
            examYear: profile.examYear,
            educationStage: profile.educationStage,
            regionCode: profile.regionCode,
            gender: profile.gender,
            targetSchool: profile.targetSchool,
            targetScore: profile.targetScore
        )
    }

    func toSnapshot() -> UserProfile {
        var profile = UserProfile()
        profile.username = username
        profile.age = age
        profile.educationLevel = educationLevel
        profile.educationSystem = educationSystem
        profile.region = region
        if let data = selectedSubjectsData,
           let subjects = try? JSONDecoder().decode([Subject].self, from: data) {
            profile.selectedSubjects = subjects
        }
        profile.theme = theme
        profile.avatarFileName = avatarFileName
        profile.realName = realName
        profile.grade = grade
        profile.className = className
        profile.schoolName = schoolName
        profile.studentId = studentId
        profile.enrollmentYear = enrollmentYear
        profile.examYear = examYear
        profile.educationStage = educationStage
        profile.regionCode = regionCode
        profile.gender = gender
        profile.targetSchool = targetSchool
        profile.targetScore = targetScore
        return profile
    }
}

// MARK: - Study Phase (学期 / 假期阶段)

@Model
final class StudyPhaseRecord {
    @Attribute(.unique) var id: UUID
    /// 阶段名称,如 "2026 春季学期" / "2026 暑假" / "高考冲刺"
    var name: String
    /// 阶段开始日期
    var startDate: Date
    /// 阶段结束日期
    var endDate: Date
    /// 是否已归档
    var isArchived: Bool
    /// 归档时间
    var archivedAt: Date?
    /// 目标列表(JSON 编码 [PhaseGoal],以 [Data] 形式存)
    var goalsData: Data?
    /// 创建时间
    var createdAt: Date

    init(
        id: UUID,
        name: String,
        startDate: Date,
        endDate: Date,
        isArchived: Bool,
        archivedAt: Date?,
        goalsData: Data?,
        createdAt: Date
    ) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.isArchived = isArchived
        self.archivedAt = archivedAt
        self.goalsData = goalsData
        self.createdAt = createdAt
    }

    convenience init(from phase: StudyPhase) {
        let data: Data? = try? JSONEncoder().encode(phase.goals)
        self.init(
            id: phase.id,
            name: phase.name,
            startDate: phase.startDate,
            endDate: phase.endDate,
            isArchived: phase.isArchived,
            archivedAt: phase.archivedAt,
            goalsData: data,
            createdAt: phase.createdAt
        )
    }

    func toSnapshot() -> StudyPhase {
        let goals: [PhaseGoal] = {
            guard let data = goalsData else { return [] }
            return (try? JSONDecoder().decode([PhaseGoal].self, from: data)) ?? []
        }()
        return StudyPhase(
            id: id,
            name: name,
            startDate: startDate,
            endDate: endDate,
            isArchived: isArchived,
            archivedAt: archivedAt,
            goals: goals,
            createdAt: createdAt
        )
    }
}
