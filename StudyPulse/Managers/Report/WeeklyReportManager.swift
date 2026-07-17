//
//  WeeklyReportManager.swift
//  StudyPulse
//
//  Generates weekly/monthly learning reports with charts and text summary.
//  Supports scheduling via local notifications.
//

import Foundation
import SwiftUI
import UIKit
import UserNotifications
import os

/// Manages generation and scheduling of periodic learning reports.
@MainActor
enum WeeklyReportManager {

    // MARK: - Report Period

    enum ReportPeriod: String, CaseIterable, Identifiable, Sendable {
        case weekly
        case monthly

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .weekly: return "Weekly Report".localized()
            case .monthly: return "Monthly Report".localized()
            }
        }

        var days: Int {
            switch self {
            case .weekly: return 7
            case .monthly: return 30
            }
        }
    }

    // MARK: - Report Data

    /// Aggregated data for a report period.
    struct ReportData: Sendable {
        let period: ReportPeriod
        let startDate: Date
        let endDate: Date
        let totalStudyMinutes: Int
        let sessionCount: Int
        let averageSessionMinutes: Double
        let subjectDistribution: [(subject: String, mistakeCount: Int, percentage: Double)]
        let intensityDistribution: [(intensity: StudySession.SessionIntensity, count: Int)]
        let gradeCount: Int
        let averageScoreRate: Double
        let mistakeCount: Int
        let examCount: Int
        let topSubject: String?
        let weakestSubject: String?
        let dailyStudyMinutes: [(date: Date, minutes: Int)]

        // 日记 / 心情维度(2026-07-17 新增)。diaryCount == 0 表示本周期无日记数据,
        // 此时 averageMoodScore / averageEnergyScore 为 nil,moodDistribution 为空。
        // Diary / mood dimension (added 2026-07-17). diaryCount == 0 means no diary
        // data this period — averages are nil, distribution is empty.
        let diaryCount: Int
        let averageMoodScore: Double?
        let averageEnergyScore: Double?
        let moodDistribution: [(emoji: String, count: Int)]
        let lowEnergyTagCount: Int
    }

    // MARK: - 数据聚合 / Data Aggregation
    // MARK: - Data Aggregation

    /// 聚合指定时间窗内的学习数据(成绩 / 错题 / 考试 / sessions / 学科 / 日记)。
    /// Aggregate study data for the given period (grades, mistakes, exams, sessions, subjects, diary).
    static func aggregateData(
        period: ReportPeriod,
        sessions: [StudySession],
        grades: [Grade],
        mistakes: [MistakeNote],
        exams: [Exam],
        subjects: [Subject],
        diaryEntries: [DiaryEntry] = [],
        now: Date = Date()
    ) -> ReportData {
        let calendar = Calendar.current
        let endDate = now
        let startDate = calendar.date(byAdding: .day, value: -period.days, to: endDate) ?? endDate

        // Filter sessions within period
        let periodSessions = sessions.filter {
            $0.completed && $0.startDate >= startDate && $0.startDate <= endDate
        }

        // Total study time
        let totalSeconds = periodSessions.reduce(0) { $0 + $1.durationSeconds }
        let totalMinutes = totalSeconds / 60

        // Average session length
        let avgSessionMinutes = periodSessions.isEmpty
            ? 0.0
            : Double(totalMinutes) / Double(periodSessions.count)

        // Subject distribution (approximate from session intensity as proxy)
        // Since StudySession doesn't have subject, we use grades/mistakes for subject stats
        let subjectStats = computeSubjectStats(
            grades: grades.filter { $0.date >= startDate && $0.date <= endDate },
            mistakes: mistakes.filter { $0.date >= startDate && $0.date <= endDate },
            subjects: subjects
        )

        // Intensity distribution
        let intensityGroups = Dictionary(grouping: periodSessions) { $0.intensity }
        let intensityDist = StudySession.SessionIntensity.allCases.map { intensity in
            (intensity: intensity, count: intensityGroups[intensity]?.count ?? 0)
        }

        // Daily study minutes (for chart)
        let dailyMinutes = computeDailyMinutes(sessions: periodSessions, startDate: startDate, endDate: endDate)

        // Grade stats
        let periodGrades = grades.filter { $0.date >= startDate && $0.date <= endDate }
        let avgScoreRate = periodGrades.isEmpty
            ? 0.0
            : periodGrades.reduce(0.0) { sum, g in
                let full = subjects.first(where: { $0.name == g.subject })?.fullScore ?? 100
                return sum + g.scoreRate(subjectFullScore: full)
            } / Double(periodGrades.count)

        // Exams in period
        let periodExams = exams.filter { $0.examDate >= startDate && $0.examDate <= endDate }

        // Top/weakest subjects
        let topSubject = subjectStats.sorted { $0.avgRate > $1.avgRate }.first?.subject
        let weakestSubject = subjectStats.sorted { $0.avgRate < $1.avgRate }.first?.subject

        // 日记聚合(按日期范围过滤后计算 mood/energy 均值 + 分布)
        // Diary aggregation (filter by date range, then compute mood/energy averages + distribution)
        let periodDiary = diaryEntries.filter { $0.date >= startDate && $0.date <= endDate }
        let diaryCount = periodDiary.count
        let avgMood: Double? = diaryCount > 0
            ? periodDiary.map { Double($0.moodScore) }.reduce(0, +) / Double(diaryCount)
            : nil
        let avgEnergy: Double? = diaryCount > 0
            ? periodDiary.map { Double($0.energyScore) }.reduce(0, +) / Double(diaryCount)
            : nil
        // 心情 emoji 分布(top 3,按出现次数降序)
        // Mood emoji distribution (top 3, sorted by count desc)
        let moodGroups = Dictionary(grouping: periodDiary) { $0.moodEmoji }
        let moodDist = moodGroups.map { (emoji: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
            .prefix(3)
            .map { ($0.emoji, $0.count) }
        // 低能量标签出现次数(焦虑/疲惫/烦躁/迷茫)
        // Low-energy tag occurrence count (anxious/tired/irritable/confused)
        let lowEnergyCount = periodDiary.filter { DiaryEntry.lowEnergyTags.contains($0.energyTag) }.count

        return ReportData(
            period: period,
            startDate: startDate,
            endDate: endDate,
            totalStudyMinutes: totalMinutes,
            sessionCount: periodSessions.count,
            averageSessionMinutes: avgSessionMinutes,
            subjectDistribution: subjectStats.map { ($0.subject, $0.mistakeCount, $0.percentage) },
            intensityDistribution: intensityDist,
            gradeCount: periodGrades.count,
            averageScoreRate: avgScoreRate,
            mistakeCount: mistakes.filter { $0.date >= startDate && $0.date <= endDate }.count,
            examCount: periodExams.count,
            topSubject: topSubject,
            weakestSubject: weakestSubject,
            dailyStudyMinutes: dailyMinutes,
            diaryCount: diaryCount,
            averageMoodScore: avgMood,
            averageEnergyScore: avgEnergy,
            moodDistribution: moodDist,
            lowEnergyTagCount: lowEnergyCount
        )
    }

    private struct SubjectStat {
        let subject: String
        let avgRate: Double
        let mistakeCount: Int
        let percentage: Double
    }

    private static func computeSubjectStats(
        grades: [Grade],
        mistakes: [MistakeNote],
        subjects: [Subject]
    ) -> [SubjectStat] {
        let gradeGroups = Dictionary(grouping: grades) { $0.subject }
        let mistakeGroups = Dictionary(grouping: mistakes) { $0.subject }
        let totalMistakes = mistakes.count

        return subjects.map { subject in
            let subjectGrades = gradeGroups[subject.name] ?? []
            let avgRate = subjectGrades.isEmpty
                ? 0.0
                : subjectGrades.reduce(0.0) { $0 + $1.scoreRate(subjectFullScore: subject.fullScore) } / Double(subjectGrades.count)
            let mistakeCount = mistakeGroups[subject.name]?.count ?? 0
            let percentage = totalMistakes > 0 ? Double(mistakeCount) / Double(totalMistakes) : 0
            return SubjectStat(subject: subject.displayName, avgRate: avgRate, mistakeCount: mistakeCount, percentage: percentage)
        }
    }

    private static func computeDailyMinutes(
        sessions: [StudySession],
        startDate: Date,
        endDate: Date
    ) -> [(date: Date, minutes: Int)] {
        let calendar = Calendar.current
        var result: [(Date, Int)] = []
        var current = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: endDate)

        while current <= endDay {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: current) ?? current
            let daySessions = sessions.filter { $0.startDate >= current && $0.startDate < nextDay }
            let minutes = daySessions.reduce(0) { $0 + $1.durationSeconds / 60 }
            result.append((current, minutes))
            current = nextDay
        }
        return result
    }

    // MARK: - 文字摘要 / Text Summary
    // MARK: - Text Summary

    /// 根据 ReportData + 用户 profile 生成多行可读文字摘要。
    /// Generate a text summary for the report.
    static func generateSummary(data: ReportData, profile: UserProfile) -> String {
        var lines: [String] = []

        // Header
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        lines.append(String(format: "📊 %@ (%@ ~ %@)",
            data.period.displayName,
            dateFormatter.string(from: data.startDate),
            dateFormatter.string(from: data.endDate)))
        lines.append("")

        // Study time
        let hours = data.totalStudyMinutes / 60
        let mins = data.totalStudyMinutes % 60
        if hours > 0 {
            lines.append(String(format: "⏱ %@".localized(), "\(hours)h \(mins)m"))
        } else {
            lines.append(String(format: "⏱ %@".localized(), "\(mins)m"))
        }

        // Sessions
        lines.append(String(format: "📝 %@: %d".localized(), "Sessions".localized(), data.sessionCount))
        lines.append(String(format: "📈 %@: %.0f min".localized(), "Avg Session".localized(), data.averageSessionMinutes))
        lines.append("")

        // Grades
        if data.gradeCount > 0 {
            lines.append(String(format: "📚 %@: %d".localized(), "Grades Recorded".localized(), data.gradeCount))
            lines.append(String(format: "💯 %@: %.0f%%".localized(), "Avg Score Rate".localized(), data.averageScoreRate * 100))
        }

        // Mistakes
        if data.mistakeCount > 0 {
            lines.append(String(format: "✏️ %@: %d".localized(), "Mistakes Added".localized(), data.mistakeCount))
        }

        // Exams
        if data.examCount > 0 {
            lines.append(String(format: "📋 %@: %d".localized(), "Exams".localized(), data.examCount))
        }
        lines.append("")

        // Top/Weakest subjects
        if let top = data.topSubject {
            lines.append(String(format: "🏆 %@: %@".localized(), "Best Subject".localized(), top))
        }
        if let weak = data.weakestSubject {
            lines.append(String(format: "💪 %@: %@".localized(), "Needs Improvement".localized(), weak))
        }

        // Encouragement
        lines.append("")
        lines.append(generateEncouragement(data: data))

        return lines.joined(separator: "\n")
    }

    private static func generateEncouragement(data: ReportData) -> String {
        // 多级鼓励文案:无学习时间 / 优秀 / 良好 / 高频 / 默认
        // Tiered encouragement: no data / outstanding / good / high-frequency / default.
        if data.totalStudyMinutes == 0 {
            return "💡 " + "Start tracking your study sessions to see insights!".localized()
        }
        if data.averageScoreRate >= 0.9 {
            return "🌟 " + "Outstanding performance! Keep up the excellent work!".localized()
        }
        if data.averageScoreRate >= 0.75 {
            return "👍 " + "Good progress! A little more effort will take you even further.".localized()
        }
        if data.sessionCount >= 10 {
            return "🔥 " + "Great consistency! Your dedication is paying off.".localized()
        }
        return "💪 " + "Every session counts. Keep going!".localized()
    }

    // MARK: - 报告生成 / Report Generation
    // MARK: - Report Generation

    /// 生成完整的报告图片。
    /// `aiSummary` 可选 LLM 生成的 AI 总结;非空时渲染在 Summary 之上。
    /// Generate a complete report image.
    /// `aiSummary` (optional) is rendered above the local Summary if non-empty.
    static func generateReportImage(
        data: ReportData,
        profile: UserProfile,
        subjects: [Subject],
        aiSummary: String? = nil
    ) -> UIImage? {
        let summary = generateSummary(data: data, profile: profile)
        let view = WeeklyReportView(
            reportData: data,
            summary: summary,
            subjects: subjects,
            aiSummary: aiSummary
        )
        return ReportRenderer.render(view)
    }

    // MARK: - 通知调度 / Notification Scheduling
    // MARK: - Notification Scheduling

    /// 调度周报/月报的本地通知(可重复触发)。
    /// Schedule a weekly or monthly report notification.
    static func scheduleNotification(period: ReportPeriod, enabled: Bool) async {
        let center = UNUserNotificationCenter.current()

        // Remove existing report notifications
        center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier(for: period)])

        guard enabled else { return }

        // Request authorization
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else {
                Log.report.warning("Notification authorization denied")
                return
            }
        } catch {
            Log.report.error("Notification authorization failed: \(error.localizedDescription)")
            return
        }

        // Schedule notification
        let content = UNMutableNotificationContent()
        content.title = period.displayName
        content.body = "Your learning report is ready! Tap to view.".localized()
        content.sound = .default

        let trigger: UNNotificationTrigger
        let identifier = notificationIdentifier(for: period)

        switch period {
        case .weekly:
            // 每周一 9:00 重复触发
            // Every Monday at 9:00 AM.
            var dateComponents = DateComponents()
            dateComponents.weekday = 2 // Monday
            dateComponents.hour = 9
            dateComponents.minute = 0
            trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        case .monthly:
            // 每月 1 日 9:00 重复触发
            // First day of each month at 9:00 AM.
            var dateComponents = DateComponents()
            dateComponents.day = 1
            dateComponents.hour = 9
            dateComponents.minute = 0
            trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        }

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
            Log.report.info("Scheduled \(period.rawValue) report notification")
        } catch {
            Log.report.error("Failed to schedule notification: \(error.localizedDescription)")
        }
    }

    private static func notificationIdentifier(for period: ReportPeriod) -> String {
        "studyPulse.\(period.rawValue)Report"
    }

    // MARK: - Preferences

    private static let weeklyEnabledKey = "weeklyReportEnabled"
    private static let monthlyEnabledKey = "monthlyReportEnabled"

    static var isWeeklyEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: weeklyEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: weeklyEnabledKey) }
    }

    static var isMonthlyEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: monthlyEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: monthlyEnabledKey) }
    }
}

// MARK: - Log Extension

extension Log {
    static let report = Logger(subsystem: Bundle.main.bundleIdentifier ?? "StudyPulse", category: "Report")
}
