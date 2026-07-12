//
//  TestDataFixtures.swift
//  StudyPulseTests
//
//  提供标准化测试数据生成工厂（Builder 模式），快速创建带默认值的各类业务模型。
//  Provides builder helpers for quickly creating domain entities with sensible defaults for unit tests.
//

import Foundation
@testable import StudyPulse

/// 测试数据快速生成工厂
enum TestDataFixtures {

    // MARK: - Grade

    static func makeGrade(
        id: UUID = UUID(),
        subject: String = "Math",
        score: Double = 85.0,
        rawScore: Double? = nil,
        ranking: Int? = nil,
        importance: Int = 3,
        image: Data? = nil,
        imageFileName: String? = nil,
        date: Date = Date(),
        examName: String = "Midterm Exam",
        fullScore: Double? = 100.0,
        phaseId: UUID? = nil
    ) -> Grade {
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

    // MARK: - Exam & comprehensiveExam

    static func makeExam(
        id: UUID = UUID(),
        name: String = "Final Exam",
        date: Date = Date().addingTimeInterval(86400 * 5),
        importance: Int = 4,
        subject: String = "Math",
        examName: String = "Finals",
        masteryDegree: Int = 70,
        timeSlot: ExamTimeSlot? = nil,
        examEndDate: Date? = nil,
        phaseId: UUID? = nil,
        checklist: [ExamChecklistItem] = [],
        locationSchool: String = "High School #1",
        locationClassroom: String = "Room 302",
        locationSeat: String = "15",
        countdownNotifyDays: [Int]? = [1, 3, 5],
        examReview: ExamReview? = nil
    ) -> Exam {
        Exam(
            id: id,
            name: name,
            date: date,
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
            countdownNotifyDays: countdownNotifyDays,
            examReview: examReview
        )
    }

    static func makeComprehensiveExam(
        id: UUID = UUID(),
        name: String = "Midterm Comprehensive",
        date: Date = Date().addingTimeInterval(86400 * 7),
        importance: Int = 5,
        subjects: [String] = ["Physics", "Chemistry", "Biology"],
        examName: String = "Science Comprehensive",
        masteryDegree: Int = 65,
        phaseId: UUID? = nil
    ) -> comprehensiveExam {
        comprehensiveExam(
            id: id,
            name: name,
            date: date,
            importance: importance,
            subject: subjects,
            examName: examName,
            masteryDegree: masteryDegree,
            phaseId: phaseId
        )
    }

    // MARK: - MistakeNote

    static func makeMistakeNote(
        id: UUID = UUID(),
        title: String = "Calculus Integration Error",
        subject: String = "Math",
        originalQuestion: String = "Find the integral of x^2 dx",
        source: String = "Homework #3",
        date: Date = Date(),
        errorReason: String = "Forgot + C",
        wrongSolution: String = "x^3 / 3",
        correctSolution: String = "x^3 / 3 + C",
        reviewState: ReviewState? = nil,
        phaseId: UUID? = nil,
        difficulty: Int = 3,
        tags: [String] = ["Calculus", "Integral"]
    ) -> MistakeNote {
        MistakeNote(
            id: id,
            title: title,
            subject: subject,
            originalQuestion: originalQuestion,
            source: source,
            date: date,
            errorReason: errorReason,
            wrongSolution: wrongSolution,
            correctSolution: correctSolution,
            reviewState: reviewState,
            phaseId: phaseId,
            difficulty: difficulty,
            tags: tags
        )
    }

    // MARK: - TaskItem

    static func makeTaskItem(
        id: UUID = UUID(),
        title: String = "Complete Chapter 4 Exercises",
        type: TaskType = .homework,
        dueDate: Date = Date().addingTimeInterval(86400 * 2),
        reminderDate: Date = Date().addingTimeInterval(86400 * 1.5),
        subject: String = "Physics",
        importance: Int = 3,
        notes: String = "Page 102, #1-10",
        isCompleted: Bool = false,
        phaseId: UUID? = nil
    ) -> TaskItem {
        TaskItem(
            id: id,
            title: title,
            type: type,
            dueDate: dueDate,
            reminderDate: reminderDate,
            subject: subject,
            importance: importance,
            notes: notes,
            isCompleted: isCompleted,
            phaseId: phaseId
        )
    }

    // MARK: - StudyPhase

    static func makeStudyPhase(
        id: UUID = UUID(),
        name: String = "2026 Spring Semester",
        startDate: Date = Date().addingTimeInterval(-86400 * 30),
        endDate: Date = Date().addingTimeInterval(86400 * 90),
        isArchived: Bool = false,
        goals: [PhaseGoal] = []
    ) -> StudyPhase {
        StudyPhase(
            id: id,
            name: name,
            startDate: startDate,
            endDate: endDate,
            isArchived: isArchived,
            goals: goals
        )
    }

    // MARK: - Subject

    static func makeSubject(
        id: UUID = UUID(),
        name: String = "Mathematics",
        displayName: String = "Math",
        enabled: Bool = true,
        fullScore: Double = 150.0
    ) -> Subject {
        Subject(
            id: id,
            name: name,
            displayName: displayName,
            enabled: enabled,
            fullScore: fullScore
        )
    }

    // MARK: - Routine & RoutineInstance

    static func makeRoutine(
        id: UUID = UUID(),
        title: String = "Morning Math Review",
        type: RoutineType = .mistakeReview,
        subject: String? = "Math",
        weekdays: [Int] = [2, 3, 4, 5, 6],
        startTime: Date = Date(),
        endTime: Date = Date().addingTimeInterval(3600),
        enabled: Bool = true,
        phaseId: UUID? = nil
    ) -> Routine {
        Routine(
            id: id,
            title: title,
            type: type,
            subject: subject,
            weekdays: weekdays,
            startTime: startTime,
            endTime: endTime,
            enabled: enabled,
            phaseId: phaseId
        )
    }

    static func makeRoutineInstance(
        id: UUID = UUID(),
        routineId: UUID = UUID(),
        title: String = "Morning Math Review",
        type: RoutineType = .mistakeReview,
        subject: String? = "Math",
        startTime: Date = Date(),
        endTime: Date = Date().addingTimeInterval(3600),
        date: Date = Date(),
        isCompleted: Bool = false,
        spawnedMistakeCount: Int = 5
    ) -> RoutineInstance {
        RoutineInstance(
            id: id,
            routineId: routineId,
            title: title,
            type: type,
            subject: subject,
            startTime: startTime,
            endTime: endTime,
            date: date,
            isCompleted: isCompleted,
            spawnedMistakeCount: spawnedMistakeCount
        )
    }
}
