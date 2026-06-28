//
//  WidgetDataSyncManager.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/6/6.
//

import Foundation
import WidgetKit
import os

/// 将主 App 的考试数据同步到 Widget 共享容器
@MainActor
enum WidgetDataSyncManager {
    /// 从 DataManager 获取即将到来的考试（未来 14 天内）
    /// Build the upcoming-exams payload from DataManager (next 14 days) and push it to widgets.
    static func syncUpcomingExams(
        examSets: [Exam],
        comprehensiveExamSets: [comprehensiveExam]
    ) {
        Log.widget.info("开始同步即将到来的考试 / Syncing upcoming exams: single=\(examSets.count, privacy: .public) comprehensive=\(comprehensiveExamSets.count, privacy: .public)")
        let now = Date()
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: 14, to: now) ?? now

        var widgetExams: [ExamWidgetData] = []
        var singleInWindow = 0
        var compInWindow = 0

        // 单科考试 / Single-subject exams
        for exam in examSets {
            if exam.examDate >= now && exam.examDate <= cutoff {
                let days = calendar.dateComponents([.day], from: now, to: exam.examDate).day ?? 0
                widgetExams.append(ExamWidgetData(
                    name: exam.name,
                    subject: exam.subject.localized(),
                    examDate: exam.examDate,
                    daysRemaining: days
                ))
                singleInWindow += 1
            }
        }

        // 综合考试 / Comprehensive exams
        for exam in comprehensiveExamSets {
            if exam.examDate >= now && exam.examDate <= cutoff {
                let days = calendar.dateComponents([.day], from: now, to: exam.examDate).day ?? 0
                let subjectString = exam.subject.map { $0.localized() }.joined(separator: ", ")
                widgetExams.append(ExamWidgetData(
                    name: exam.name,
                    subject: subjectString,
                    examDate: exam.examDate,
                    daysRemaining: days
                ))
                compInWindow += 1
            }
        }

        // 按日期排序 / Sort by date
        widgetExams.sort { $0.examDate < $1.examDate }

        // 保存到 App Group 共享容器 / Save to App Group shared container
        WidgetDataStore.save(exams: widgetExams)

        // 刷新 Widget / Reload widget timelines
        WidgetCenter.shared.reloadAllTimelines()
        Log.widget.info("考试同步完成 / Exam sync done: windowSingle=\(singleInWindow, privacy: .public) windowComprehensive=\(compInWindow, privacy: .public) pushed=\(widgetExams.count, privacy: .public) cutoff=\(cutoff, privacy: .public)")
    }
}
