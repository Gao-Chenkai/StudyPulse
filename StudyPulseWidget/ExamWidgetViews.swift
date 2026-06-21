//
//  ExamWidgetViews.swift
//  StudyPulseWidget
//
//  Created by Chenkai Gao on 2026/6/6.
//

import SwiftUI
import WidgetKit

// MARK: - Single exam card
struct ExamCardView: View {
    let exam: ExamWidgetData

    private var timeProgress: Double {
        min(Double(exam.daysRemaining) / 30.0, 1.0)
    }

    private var timeLeftColor: Color {
        if exam.daysRemaining <= 3 { return .red }
        if exam.daysRemaining <= 7 { return .orange }
        return .green
    }

    private var daysText: String {
        if exam.daysRemaining <= 0 { return String(localized: "Today!") }
        return "\(exam.daysRemaining) " + String(localized: "days")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(exam.name)
                    .font(.headline)
                Spacer()
                Text(exam.subject)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.15))
                    )
                    .foregroundColor(.blue)
            }

            Text(exam.examDate, style: .date)
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 3) {
                Text("Time Left")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                ProgressView(value: timeProgress, total: 1.0)
                    .tint(timeLeftColor)
                    .scaleEffect(x: 1, y: 1.2, anchor: .center)
                Text(daysText)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(exam.daysRemaining <= 2 ? .red : .secondary)
            }
        }
        .padding(12)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.thinMaterial)
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.25),
                                Color.blue.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Empty state
struct EmptyExamWidgetView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 24))
                .foregroundColor(.secondary)
            Text("No upcoming exams")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Small widget
struct ExamWidgetSmallView: View {
    let entry: ExamWidgetEntry

    var body: some View {
        if let exam = entry.exams.first {
            ExamCardView(exam: exam)
        } else {
            EmptyExamWidgetView()
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}

// MARK: - Medium widget
struct ExamWidgetMediumView: View {
    let entry: ExamWidgetEntry

    var body: some View {
        if entry.exams.isEmpty {
            EmptyExamWidgetView()
                .containerBackground(.fill.tertiary, for: .widget)
        } else {
            HStack(spacing: 10) {
                ForEach(entry.exams.prefix(2), id: \.name) { exam in
                    ExamCardView(exam: exam)
                }
            }
            .padding(.horizontal, 2)
            .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}

// MARK: - Large widget
struct ExamWidgetLargeView: View {
    let entry: ExamWidgetEntry

    var body: some View {
        if entry.exams.isEmpty {
            EmptyExamWidgetView()
                .containerBackground(.fill.tertiary, for: .widget)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    Text("Upcoming Exams")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                ForEach(entry.exams.prefix(2), id: \.name) { exam in
                    ExamCardView(exam: exam)
                }

                Spacer()
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}