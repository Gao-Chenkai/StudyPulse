//
//  StudyReport.swift
//  StudyPulse
//
//  Immutable snapshot used by the report renderer. Holds copies of
//  the data needed to draw a self-contained "Learning Report" view,
//  so the SwiftUI renderer can stay free of `@EnvironmentObject`
//  lookups and the page can be rendered off the main actor if needed.
//

import Foundation

/// 不可变快照：把 DataManager / HealthKitManager 的关键数据在生成报告时
/// 拷贝一份，供后续 SwiftUI 渲染使用，避免直接持有 ObservableObject。
/// Immutable snapshot: copies the fields needed by the report renderer.
nonisolated struct StudyReport: Sendable {
    let generatedAt: Date
    let startDate: Date
    let endDate: Date

    let profile: UserProfile
    let grades: [Grade]
    let mistakeSets: [MistakeNote]
    let examSets: [Exam]
    let comprehensiveExamSets: [comprehensiveExam]
    let subjects: [Subject]

    let hrvEnabled: Bool
    let hrvOnboardingCompleted: Bool
    let hrv: HRVReadiness?
    let bodyStatus: BodyStatus?
    let baselines: PersonalBaselines?
}

// MARK: - Derived summary

extension StudyReport {
    /// 报告时间窗内的成绩。
    /// Grades that fall inside [startDate, endDate].
    var periodGrades: [Grade] {
        grades.filter { $0.date >= startDate && $0.date <= endDate }
    }

    /// 报告时间窗内的错题。
    /// Mistakes created inside the report window.
    var periodMistakes: [MistakeNote] {
        mistakeSets.filter { $0.date >= startDate && $0.date <= endDate }
    }

    /// 未来 14 天内的考试。
    /// Upcoming exams within the next 14 days.
    var upcomingExams: [Exam] {
        let now = Date()
        let cutoff = Calendar.current.date(byAdding: .day, value: 14, to: now) ?? now
        let subjectExams: [Exam] = examSets.filter { $0.examDate >= now && $0.examDate <= cutoff }
        let compExams: [Exam] = comprehensiveExamSets
            .filter { $0.examDate >= now && $0.examDate <= cutoff }
            .map { comprehensiveExamBridge($0) }
        return (subjectExams + compExams).sorted { $0.examDate < $1.examDate }
    }

    /// 综合考试适配为 Exam 类型，subject 取第一个。
    /// Bridge a `comprehensiveExam` to a uniform `Exam` for listing.
    private func comprehensiveExamBridge(_ comp: comprehensiveExam) -> Exam {
        let firstSubject = comp.subject.first ?? ""
        var exam = Exam(
            name: comp.name,
            date: comp.examDate,
            importance: comp.importance,
            subject: firstSubject,
            examName: comp.examName,
            masteryDegree: comp.masteryDegree
        )
        exam.examEndDate = comp.examEndDate
        // 综合考试取第一个科目的时间段（如果有）。
        if let slots = comp.subjectTimeSlots, let first = slots[firstSubject] {
            exam.timeSlot = first
        }
        return exam
    }

    /// 每科目平均得分率（0-1）。仅含窗口内成绩。
    /// Per-subject average score rate in the window.
    var subjectAverages: [(subject: String, avg: Double)] {
        let groups = Dictionary(grouping: periodGrades) { $0.subject }
        return groups
            .map { subject, items -> (String, Double) in
                let full = fullScore(for: subject)
                guard full > 0 else { return (subject, 0) }
                let avg = items.reduce(0.0) { $0 + $1.scoreRate(subjectFullScore: full) }
                return (subject, avg / Double(items.count))
            }
            .sorted { $0.0 < $1.0 }
    }

    /// 时间窗内最高分。
    /// Highest score in the window.
    var topGrades: [Grade] {
        periodGrades.sorted { $0.score > $1.score }.prefix(5).map { $0 }
    }

    /// 错题按科目分布。
    /// Mistake counts by subject.
    var mistakeBySubject: [(subject: String, count: Int)] {
        let groups = Dictionary(grouping: periodMistakes) { $0.subject }
        return groups.map { ($0.key, $0.value.count) }.sorted { $0.0 < $1.0 }
    }

    /// 待复习的错题数（SRS 状态非 nil）。
    /// Number of mistakes enrolled in the SRS review queue.
    var dueReviewCount: Int {
        mistakeSets.filter { $0.reviewState != nil }.count
    }

    /// 即将到来的考试数（未来 14 天）。
    var upcomingExamCount: Int {
        upcomingExams.count
    }

    /// 平均得分率（窗口内所有成绩）。
    var averageScoreRate: Double {
        let items = periodGrades
        guard !items.isEmpty else { return 0 }
        let total = items.reduce(0.0) { sum, g in
            sum + g.scoreRate(subjectFullScore: fullScore(for: g.subject))
        }
        return total / Double(items.count)
    }

    /// 显示名（沿用 DataManager 的语义）。
    func displayName(for subject: String) -> String {
        guard let match = subjects.first(where: { $0.name == subject }) else {
            return subject
        }
        return match.displayName.isEmpty ? subject : match.displayName
    }

    /// 科目满分（沿用 DataManager 的语义）。
    func fullScore(for subject: String) -> Double {
        subjects.first(where: { $0.name == subject })?.fullScore ?? 100
    }

    /// 是否含 HRV 数据（用于控制 ReportContentView 中的雷达段）。
    var hasHRVSection: Bool {
        hrvEnabled && hrvOnboardingCompleted
    }
}

// MARK: - Factory

extension StudyReport {
    /// 在主线程上从 DataManager / HealthKitManager 拷贝快照。
    /// Make a snapshot from the live managers.
    @MainActor
    static func make(
        from dataManager: DataManager,
        hrvManager: HealthKitManager,
        start: Date,
        end: Date
    ) -> StudyReport {
        StudyReport(
            generatedAt: Date(),
            startDate: start,
            endDate: end,
            profile: dataManager.profile,
            grades: dataManager.grades,
            mistakeSets: dataManager.mistakeSets,
            examSets: dataManager.examSets,
            comprehensiveExamSets: dataManager.comprehensiveExamSets,
            subjects: dataManager.subjects,
            hrvEnabled: hrvManager.hrvEnabled,
            hrvOnboardingCompleted: hrvManager.hrvOnboardingCompleted,
            hrv: hrvManager.readiness,
            bodyStatus: hrvManager.bodyStatus,
            baselines: hrvManager.personalBaselines
        )
    }
}
