//
//  ExamWidgetViews.swift
//  StudyPulseWidget
//
//  Created by Chenkai Gao on 2026/6/6.
//

import SwiftUI
import WidgetKit

// MARK: - Single exam row view
struct ExamRowView: View {
    let exam: ExamWidgetData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(exam.name)
                .font(.headline)
                .lineLimit(1)
            
            HStack(spacing: 6) {
                Text(exam.subject)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(daysLabel)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(daysColor)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
    
    private var daysLabel: String {
        switch exam.daysRemaining {
        case ...0:
            return String(localized: "Today")
        case 1:
            return String(localized: "Tomorrow")
        default:
            return String(format: String(localized: "%d days left"), exam.daysRemaining)
        }
    }
    
    private var daysColor: Color {
        if exam.daysRemaining <= 0 {
            return .red
        } else if exam.daysRemaining == 1 {
            return .orange
        } else if exam.daysRemaining <= 3 {
            return .yellow
        } else {
            return .green
        }
    }
}

// MARK: - Empty state view
struct EmptyExamWidgetView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("No upcoming exams", comment: "Widget empty state message")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Widget size views
struct ExamWidgetSmallView: View {
    let entry: ExamWidgetEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let exam = entry.exams.first {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exam.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(exam.subject)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    HStack {
                        Image(systemName: "clock.fill")
                            .font(.caption2)
                            .foregroundColor(daysColor)
                        
                        Text(daysLabel(exam))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(daysColor)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                EmptyExamWidgetView()
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
    
    private func daysLabel(_ exam: ExamWidgetData) -> String {
        switch exam.daysRemaining {
        case ...0:
            return String(localized: "Today")
        case 1:
            return String(localized: "Tomorrow")
        default:
            return String(format: String(localized: "%d days left"), exam.daysRemaining)
        }
    }
    
    private var daysColor: Color {
        guard let exam = entry.exams.first else { return .secondary }
        if exam.daysRemaining <= 0 {
            return .red
        } else if exam.daysRemaining == 1 {
            return .orange
        } else if exam.daysRemaining <= 3 {
            return .yellow
        } else {
            return .green
        }
    }
}

struct ExamWidgetMediumView: View {
    let entry: ExamWidgetEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
                
                Text("Upcoming Exams", comment: "Widget section title")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            Divider()
            
            if entry.exams.isEmpty {
                EmptyExamWidgetView()
            } else {
                ForEach(entry.exams.prefix(3), id: \.name) { exam in
                    ExamRowView(exam: exam)
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct ExamWidgetLargeView: View {
    let entry: ExamWidgetEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.title3)
                    .foregroundColor(.accentColor)
                
                Text("Upcoming Exams", comment: "Widget section title")
                    .font(.headline)
            }
            
            if entry.exams.isEmpty {
                Spacer()
                EmptyExamWidgetView()
                Spacer()
            } else {
                ForEach(entry.exams.prefix(5), id: \.name) { exam in
                    ExamRowView(exam: exam)
                }
                
                Spacer()
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
