//
//  HRVWidget.swift
//  StudyPulseWidget
//
//  HRV readiness widget — same style as HomeView HRVStatusCard
//

import SwiftUI
import WidgetKit
import Charts

// MARK: - Widget Definition
struct HRVWidget: Widget {
    let kind: String = "HRVWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HRVWidgetProvider()) { entry in
            HRVWidgetContent(entry: entry)
        }
        .configurationDisplayName("HRV Readiness")
        .description("See your daily study readiness based on HRV.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Provider
struct HRVWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> HRVWidgetEntry {
        HRVWidgetEntry(date: Date(), data: sampleData)
    }

    func getSnapshot(in context: Context, completion: @escaping (HRVWidgetEntry) -> Void) {
        let data = HRVWidgetDataStore.load()
        completion(HRVWidgetEntry(date: Date(), data: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HRVWidgetEntry>) -> Void) {
        let data = HRVWidgetDataStore.load()
        let entry = HRVWidgetEntry(date: Date(), data: data)
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private var sampleData: HRVWidgetData {
        HRVWidgetData(
            todayHRV: 58,
            baselineMean: 52,
            zScore: 1.2,
            category: "excellent",
            suggestion: "Your HRV is above baseline. You're well recovered and ready for focused study.",
            dailyHistory: [
                HRVDailyPoint(date: Date().addingTimeInterval(-86400 * 6), value: 48),
                HRVDailyPoint(date: Date().addingTimeInterval(-86400 * 5), value: 52),
                HRVDailyPoint(date: Date().addingTimeInterval(-86400 * 4), value: 50),
                HRVDailyPoint(date: Date().addingTimeInterval(-86400 * 3), value: 55),
                HRVDailyPoint(date: Date().addingTimeInterval(-86400 * 2), value: 53),
                HRVDailyPoint(date: Date().addingTimeInterval(-86400), value: 56),
                HRVDailyPoint(date: Date(), value: 58),
            ]
        )
    }
}

// MARK: - Entry
struct HRVWidgetEntry: TimelineEntry {
    let date: Date
    let data: HRVWidgetData?
}

// MARK: - Content
struct HRVWidgetContent: View {
    let entry: HRVWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if let data = entry.data, data.category != "noAuthorization", data.category != "queryFailed" {
            switch family {
            case .systemSmall:
                HRVSmallView(data: data)
            case .systemMedium:
                HRVMediumView(data: data)
            case .systemLarge:
                HRVLargeView(data: data)
            default:
                HRVMediumView(data: data)
            }
        } else {
            HRVEmptyView()
        }
    }
}

// MARK: - Helpers
private func readinessColor(_ category: String) -> Color {
    switch category {
    case "excellent": return .green
    case "normal": return .blue
    case "low": return .orange
    default: return .secondary
    }
}

private func badgeLabel(_ category: String) -> String {
    switch category {
    case "excellent": return String(localized: "Excellent")
    case "normal": return String(localized: "Normal")
    case "low": return String(localized: "Low")
    case "loading": return String(localized: "Loading...")
    case "insufficient": return String(localized: "Collecting")
    default: return "-"
    }
}

private func todayHRVText(_ data: HRVWidgetData) -> String {
    guard let v = data.todayHRV else { return "--" }
    return String(format: "%.0f ms", v)
}

private func baselineText(_ data: HRVWidgetData) -> String {
    guard let m = data.baselineMean else { return "--" }
    return String(format: "%.0f ms", m)
}

// MARK: - Small (suggestion only)
struct HRVSmallView: View {
    let data: HRVWidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "heart.text.square.fill")
                    .foregroundStyle(readinessColor(data.category).gradient)
                    .font(.title3)
                Spacer()
                Text(badgeLabel(data.category))
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(readinessColor(data.category).opacity(0.15)))
                    .foregroundColor(readinessColor(data.category))
            }
            if !data.suggestion.isEmpty {
                Text(data.suggestion)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(4)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Medium (data + suggestion)
struct HRVMediumView: View {
    let data: HRVWidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "heart.text.square.fill")
                    .foregroundStyle(readinessColor(data.category).gradient)
                    .font(.title3)
                Text("HRV Readiness")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Text(badgeLabel(data.category))
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(readinessColor(data.category).opacity(0.15)))
                    .foregroundColor(readinessColor(data.category))
            }

            if data.category != "insufficient" {
                HStack(spacing: 16) {
                    statItem(label: "Today", value: todayHRVText(data), color: readinessColor(data.category))
                    Divider().frame(height: 28)
                    statItem(label: "Baseline", value: baselineText(data), color: .secondary)
                    if let z = data.zScore {
                        Divider().frame(height: 28)
                        statItem(label: "Z-Score", value: String(format: "%+.1f\u{03C3}", z), color: readinessColor(data.category))
                    }
                }
            }

            if !data.suggestion.isEmpty {
                Text(data.suggestion)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func statItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(color == .secondary ? .primary : color)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Large (chart + data + suggestion)
struct HRVLargeView: View {
    let data: HRVWidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "heart.text.square.fill")
                    .foregroundStyle(readinessColor(data.category).gradient)
                    .font(.title3)
                Text("HRV Readiness")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Text(badgeLabel(data.category))
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(readinessColor(data.category).opacity(0.15)))
                    .foregroundColor(readinessColor(data.category))
            }

            if !data.dailyHistory.isEmpty {
                HRVBarChart(data: data)
            }

            if data.category != "insufficient" {
                HStack(spacing: 16) {
                    statItem(label: "Today", value: todayHRVText(data), color: readinessColor(data.category))
                    Divider().frame(height: 28)
                    statItem(label: "Baseline", value: baselineText(data), color: .secondary)
                    if let z = data.zScore {
                        Divider().frame(height: 28)
                        statItem(label: "Z-Score", value: String(format: "%+.1f\u{03C3}", z), color: readinessColor(data.category))
                    }
                }
            }

            if !data.suggestion.isEmpty {
                Text(data.suggestion)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func statItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(color == .secondary ? .primary : color)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - HRV Bar Chart
private struct HRVBarChart: View {
    let data: HRVWidgetData

    var body: some View {
        Chart {
            if let baseline = data.baselineMean {
                RuleMark(y: .value("Baseline", baseline))
                    .foregroundStyle(.secondary.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            ForEach(data.dailyHistory.sorted(by: { $0.date < $1.date }), id: \.date) { point in
                BarMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("HRV", point.value)
                )
                .foregroundStyle(barColor(for: point.value).gradient)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 2)) { _ in
                AxisValueLabel(format: .dateTime.month(.twoDigits).day(.twoDigits))
                    .font(.system(size: 8))
            }
        }
        .chartYAxis(.hidden)
        .frame(height: 100)
    }

    private func barColor(for value: Double) -> Color {
        let mean = data.baselineMean ?? (data.dailyHistory.map(\.value).reduce(0, +) / max(Double(data.dailyHistory.count), 1))
        if value > mean * 1.1 { return .green }
        if value < mean * 0.9 { return .orange }
        return .blue
    }
}

// MARK: - Empty
struct HRVEmptyView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "heart.slash")
                .font(.system(size: 24))
                .foregroundColor(.secondary)
            Text("HRV not available")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}