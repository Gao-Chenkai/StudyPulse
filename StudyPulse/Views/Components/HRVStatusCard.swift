//
//  HRVStatusCard.swift
//  StudyPulse
//
//  Dashboard card showing HRV readiness status with configurable detail level.
//
import SwiftUI
import Charts

struct HRVStatusCard: View {
    @ObservedObject var hrvManager = HealthKitManager.shared
    @State private var animateIn = false

    var body: some View {
        if hrvManager.hrvEnabled && hrvManager.hrvOnboardingCompleted {
            VStack(alignment: .leading, spacing: 14) {
                // Header row
                HStack {
                    Image(systemName: "heart.text.square.fill")
                        .foregroundStyle(readinessColor.gradient)
                        .font(.title3)
                    Text("HRV Readiness".localized())
                        .font(.headline)
                        .fontWeight(.bold)
                    Spacer()
                    readinessBadge
                }

                // Level 3: trend chart
                if hrvManager.hrvDetailLevel == .chartAndData {
                    HRVTrendChart(dailyData: hrvManager.dailyHRVHistory,
                                  baselineMean: hrvManager.readiness.baselineMean)
                }

                // Level 2+3: stats row
                if hrvManager.hrvDetailLevel != .suggestionOnly {
                    statsRow
                }

                // All levels: suggestion
                suggestionRow

                // Insufficient data prompt
                if hrvManager.readiness.category == .insufficient {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text(hrvManager.readiness.suggestion)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(16)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(.secondarySystemGroupedBackground))
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(readinessColor.opacity(0.25), lineWidth: 1)
                }
            )
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
            .opacity(animateIn ? 1 : 0)
            .offset(y: animateIn ? 0 : 10)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    animateIn = true
                }
            }
        }
    }

    // MARK: - Subviews
    private var statsRow: some View {
        Group {
            if hrvManager.readiness.category != .insufficient
                && hrvManager.readiness.category != .noAuthorization
                && hrvManager.readiness.category != .queryFailed {
                HStack(spacing: 20) {
                    statItem(label: "Today".localized(), value: todayHRVText, color: readinessColor)
                    Divider().frame(height: 32)
                    statItem(label: "Baseline".localized(), value: baselineText, color: .secondary)
                    if let z = hrvManager.readiness.zScore {
                        Divider().frame(height: 32)
                        statItem(label: "Z-Score".localized(), value: String(format: "%+.1f\u{03C3}", z), color: readinessColor)
                    }
                }
            }
        }
    }

    private var suggestionRow: some View {
        Group {
            if !hrvManager.readiness.suggestion.isEmpty {
                Text(hrvManager.readiness.suggestion)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Computed Properties
    private var readinessColor: Color {
        switch hrvManager.readiness.category {
        case .excellent: return .green
        case .normal: return .blue
        case .low: return .orange
        case .insufficient, .noAuthorization, .queryFailed: return .secondary
        }
    }

    private var readinessBadge: some View {
        Text(badgeLabel)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(readinessColor.opacity(0.15)))
            .foregroundColor(readinessColor)
    }

    private var badgeLabel: String {
        switch hrvManager.readiness.category {
        case .excellent: return "Excellent".localized()
        case .normal: return "Normal".localized()
        case .low: return "Low".localized()
        case .insufficient: return "Collecting".localized()
        case .noAuthorization: return "-"
        case .queryFailed: return "Error".localized()
        }
    }

    private var todayHRVText: String {
        guard let v = hrvManager.readiness.todayHRV else { return "--" }
        return String(format: "%.0f ms", v)
    }

    private var baselineText: String {
        guard let m = hrvManager.readiness.baselineMean else { return "--" }
        return String(format: "%.0f ms", m)
    }

    private func statItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(color == .secondary ? .primary : color)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - HRV Trend Chart (Level 3)
private struct HRVTrendChart: View {
    let dailyData: [HealthKitManager.DailyHRV]
    let baselineMean: Double?

    var body: some View {
        if dailyData.isEmpty {
            EmptyView()
        } else {
            Chart {
                if let baseline = baselineMean {
                    RuleMark(y: .value("Baseline", baseline))
                        .foregroundStyle(.secondary.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
                ForEach(chartData, id: \.date) { point in
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
                        .font(.system(size: 9))
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 120)
            .padding(.bottom, 2)
        }
    }

    private var chartData: [(date: Date, value: Double)] {
        dailyData.map { (date: $0.date, value: $0.value) }
            .sorted { $0.date < $1.date }
    }

    private func barColor(for value: Double) -> Color {
        let mean = baselineMean ?? (chartData.map(\.value).reduce(0, +) / max(Double(chartData.count), 1))
        if value > mean * 1.1 { return .green }
        if value < mean * 0.9 { return .orange }
        return .blue
    }
}
