//
//  TrendWidget.swift
//  StudyPulseWidget
//
//  Subject grade trend line chart widget — copied from HomeView GradeChartView
//

import SwiftUI
import WidgetKit
import Charts

// MARK: - Widget Definition
struct TrendWidget: Widget {
    let kind: String = "TrendWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TrendWidgetProvider()) { entry in
            TrendWidgetContent(entry: entry)
        }
        .configurationDisplayName("Grade Trends")
        .description("Track your grade trends over time.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Provider
struct TrendWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> TrendWidgetEntry {
        TrendWidgetEntry(date: Date(), points: samplePoints)
    }

    func getSnapshot(in context: Context, completion: @escaping (TrendWidgetEntry) -> Void) {
        let points = TrendWidgetDataStore.load()
        completion(TrendWidgetEntry(date: Date(), points: points))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TrendWidgetEntry>) -> Void) {
        let points = TrendWidgetDataStore.load()
        let entry = TrendWidgetEntry(date: Date(), points: points)
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private var samplePoints: [TrendPoint] {
        let today = Date()
        return [
            TrendPoint(date: today.addingTimeInterval(-86400 * 6), score: 72, subject: "Mathematics", fullScore: 100),
            TrendPoint(date: today.addingTimeInterval(-86400 * 5), score: 78, subject: "Mathematics", fullScore: 100),
            TrendPoint(date: today.addingTimeInterval(-86400 * 4), score: 75, subject: "Mathematics", fullScore: 100),
            TrendPoint(date: today.addingTimeInterval(-86400 * 3), score: 82, subject: "Mathematics", fullScore: 100),
            TrendPoint(date: today.addingTimeInterval(-86400 * 2), score: 85, subject: "Mathematics", fullScore: 100),
            TrendPoint(date: today.addingTimeInterval(-86400), score: 90, subject: "Mathematics", fullScore: 100),
        ]
    }
}

// MARK: - Entry
struct TrendWidgetEntry: TimelineEntry {
    let date: Date
    let points: [TrendPoint]
}

// MARK: - Score Color (copied from ScoreColor.swift, using SwiftUI native colors)
private func scoreColor(_ score: Double, fullScore: Double) -> Color {
    guard fullScore > 0 else { return .secondary }
    let rate = score / fullScore
    if rate >= 0.9 {
        return .green
    } else if rate >= 0.75 {
        return .blue
    } else if rate >= 0.6 {
        return .orange
    } else {
        return .red
    }
}

// MARK: - Content (copied from GradeChartView)
struct TrendWidgetContent: View {
    let entry: TrendWidgetEntry
    @Environment(\.widgetFamily) var family

    private var fullScore: Double { entry.points.first?.fullScore ?? 100 }
    private var subject: String { entry.points.first?.subject ?? "" }

    var body: some View {
        if !entry.points.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text(subject)
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                Chart(entry.points, id: \.date) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Score", point.score)
                    )
                    .foregroundStyle(.blue)

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Score", point.score)
                    )
                    .symbol {
                        Circle()
                            .fill(Color(.secondarySystemGroupedBackground))
                            .frame(width: 10, height: 10)
                            .overlay {
                                Circle()
                                    .stroke(scoreColor(point.score, fullScore: fullScore), lineWidth: 2)
                            }
                    }
                }
            }
            .padding()
//            .containerBackground(.fill.tertiary, for: .widget)
        } else {
            VStack(spacing: 6) {
                Image(systemName: "chart.line.downtrend.xyaxis")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
                Text("No grades yet")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}
