//
//  ExamWidgetProvider.swift
//  StudyPulseWidget
//
//  Created by Chenkai Gao on 2026/6/6.
//

import WidgetKit

/// Widget timeline provider — reads exam data from shared App Group UserDefaults
struct ExamWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> ExamWidgetEntry {
        ExamWidgetEntry(
            date: Date(),
            exams: [
                ExamWidgetData(
                    name: "Midterm Exam",
                    subject: "Mathematics",
                    examDate: Date().addingTimeInterval(86400 * 3),
                    daysRemaining: 3
                )
            ]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ExamWidgetEntry) -> Void) {
        let entry = ExamWidgetEntry(date: Date(), exams: WidgetDataStore.load())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ExamWidgetEntry>) -> Void) {
        let exams = WidgetDataStore.load()
        
        let currentDate = Date()
        let nextUpdateDate = Calendar.current.date(
            bySettingHour: 0, minute: 0, second: 0,
            of: Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
        )!
        
        let entry = ExamWidgetEntry(date: currentDate, exams: exams)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdateDate))
        completion(timeline)
    }
}
