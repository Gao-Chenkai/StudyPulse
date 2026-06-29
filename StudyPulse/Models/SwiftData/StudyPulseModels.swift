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
        fullScore: Double?
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
            fullScore: grade.fullScore
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
            fullScore: fullScore
        )
    }
}

// MARK: - MistakeNote

@Model
final class MistakeNoteRecord {
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
        correctSolutionImagesData: [Data]
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
    }

    convenience init(from note: MistakeNote) {
        let srs = note.reviewState
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
            correctSolutionImagesData: note.correctSolutionImages
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
            reviewState: reviewState
        )
    }
}

// MARK: - Exam (单科)

@Model
final class ExamRecord {
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
        timeSlotEnd: Date?
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
    }

    convenience init(from exam: Exam) {
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
            timeSlotEnd: exam.timeSlot?.endTime
        )
    }

    func toSnapshot() -> Exam {
        let timeSlot: ExamTimeSlot? = {
            if let s = timeSlotStart, let e = timeSlotEnd {
                return ExamTimeSlot(startTime: s, endTime: e)
            }
            return nil
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
            examEndDate: examEndDate
        )
    }
}

// MARK: - ComprehensiveExam (综合)

@Model
final class ComprehensiveExamRecord {
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

    init(
        id: UUID,
        name: String,
        examDate: Date,
        examEndDate: Date?,
        importance: Int,
        subjects: [String],
        examName: String,
        masteryDegree: Int,
        subjectTimeSlotsData: Data?
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
            subjectTimeSlotsData: slotsData
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
            subjectTimeSlots: slots
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
