//
//  WidgetDataSyncManager.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/6/6.
//

import Foundation
import WidgetKit

/// 将主 App 的考试数据同步到 Widget 共享容器
@MainActor
enum WidgetDataSyncManager {
    /// 从 DataManager 获取即将到来的考试（未来 14 天内）
    static func syncUpcomingExams(
        examSets: [Exam],
        comprehensiveExamSets: [comprehensiveExam]
    ) {
        let now = Date()
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: 14, to: now) ?? now
        
        var widgetExams: [ExamWidgetData] = []
        
        // 单科考试
        for exam in examSets {
            if exam.examDate >= now && exam.examDate <= cutoff {
                let days = calendar.dateComponents([.day], from: now, to: exam.examDate).day ?? 0
                widgetExams.append(ExamWidgetData(
                    name: exam.name,
                    subject: exam.subject,
                    examDate: exam.examDate,
                    daysRemaining: days
                ))
            }
        }
        
        // 综合考试
        for exam in comprehensiveExamSets {
            if exam.examDate >= now && exam.examDate <= cutoff {
                let days = calendar.dateComponents([.day], from: now, to: exam.examDate).day ?? 0
                let subjectString = exam.subject.joined(separator: ", ")
                widgetExams.append(ExamWidgetData(
                    name: exam.name,
                    subject: subjectString,
                    examDate: exam.examDate,
                    daysRemaining: days
                ))
            }
        }
        
        // 按日期排序
        widgetExams.sort { $0.examDate < $1.examDate }
        
        // 保存到 App Group 共享容器
        WidgetDataStore.save(exams: widgetExams)
        
        // 刷新 Widget
        WidgetCenter.shared.reloadAllTimelines()
    }
}
