//
//  ExamWidgetEntry.swift
//  StudyPulseWidget
//
//  Created by Chenkai Gao on 2026/6/6.
//

import Foundation
import WidgetKit

/// Widget 时间线条目
struct ExamWidgetEntry: TimelineEntry {
    let date: Date
    let exams: [ExamWidgetData]
}
