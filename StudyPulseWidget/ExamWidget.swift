//
//  ExamWidget.swift
//  StudyPulseWidget
//
//  Created by Chenkai Gao on 2026/6/6.
//

import WidgetKit
import SwiftUI

struct ExamWidget: Widget {
    let kind: String = "ExamWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ExamWidgetProvider()) { entry in
            ExamWidgetContent(entry: entry)
        }
        .configurationDisplayName("Upcoming Exams")
        .description("See your next exams at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct ExamWidgetContent: View {
    let entry: ExamWidgetEntry
    
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            ExamWidgetSmallView(entry: entry)
        case .systemMedium:
            ExamWidgetMediumView(entry: entry)
        case .systemLarge:
            ExamWidgetLargeView(entry: entry)
        default:
            ExamWidgetSmallView(entry: entry)
        }
    }
}
