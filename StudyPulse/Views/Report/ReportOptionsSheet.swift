//
//  ReportOptionsSheet.swift
//  StudyPulse
//
//  Bottom sheet that lets the user pick a time range + output format
//  before generating the report. Designed to be presented from any
//  view via `.sheet(isPresented:) { ReportOptionsSheet(...) }`.
//

import SwiftUI

/// 用户在分享报告前选择的选项。
/// Report options chosen by the user before rendering.
struct ReportOptions: Sendable {
    let startDate: Date
    let endDate: Date
    let format: ReportImageFormat
    let jpegQuality: Double

    /// Convert to a `(StudyReport, Data?)` pair at the call site.
    @MainActor
    func resolve(start: Date, end: Date) -> (start: Date, end: Date) {
        (start, end)
    }
}

enum ReportTimeRange: String, CaseIterable, Identifiable, Sendable {
    case last7
    case last30
    case last90
    case all
    case custom

    var id: String { rawValue }

    /// 友好显示名
    var displayName: String {
        switch self {
        case .last7: return "Last 7 Days".localized()
        case .last30: return "Last 30 Days".localized()
        case .last90: return "Last 90 Days".localized()
        case .all: return "All Time".localized()
        case .custom: return "Custom".localized()
        }
    }

    /// 默认起止时间（custom 时此值无效，由 binding 控制）。
    func resolve(now: Date = Date()) -> (Date, Date) {
        let calendar = Calendar.current
        switch self {
        case .last7:
            return (calendar.date(byAdding: .day, value: -7, to: now)!, now)
        case .last30:
            return (calendar.date(byAdding: .day, value: -30, to: now)!, now)
        case .last90:
            return (calendar.date(byAdding: .day, value: -90, to: now)!, now)
        case .all:
            // 10 年前 → 现在，覆盖所有历史。
            return (calendar.date(byAdding: .year, value: -10, to: now)!, now)
        case .custom:
            return (now, now)
        }
    }
}

struct ReportOptionsSheet: View {
    let onGenerate: (ReportOptions) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var range: ReportTimeRange = .last30
    @State private var customStart: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var customEnd: Date = Date()
    @State private var format: ReportImageFormat = .png
    @State private var jpegQuality: Double = 0.9

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Time Range".localized(), selection: $range) {
                        ForEach(ReportTimeRange.allCases) { r in
                            Text(r.displayName).tag(r)
                        }
                    }
                    if range == .custom {
                        DatePicker("Start".localized(), selection: $customStart, displayedComponents: .date)
                        DatePicker("End".localized(), selection: $customEnd, in: ...Date(), displayedComponents: .date)
                    }
                } header: {
                    Text("Time Range".localized())
                }

                Section {
                    Picker("Output Format".localized(), selection: $format) {
                        Text("PNG").tag(ReportImageFormat.png)
                        Text("JPEG").tag(ReportImageFormat.jpeg)
                    }
                    if format == .jpeg {
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Image Quality".localized())
                                Spacer()
                                Text(percentString(jpegQuality))
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $jpegQuality, in: 0.6...1.0, step: 0.05)
                        }
                    }
                } header: {
                    Text("Output Format".localized())
                }
            }
            .navigationTitle("Report Options".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel".localized()) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Generate Report".localized()) {
                        let resolved = effectiveRange()
                        let options = ReportOptions(
                            startDate: resolved.start,
                            endDate: resolved.end,
                            format: format,
                            jpegQuality: jpegQuality
                        )
                        dismiss()
                        // 等 sheet 关闭动画开始后再触发回调，避免与 dismiss 冲突。
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            onGenerate(options)
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func effectiveRange() -> (start: Date, end: Date) {
        switch range {
        case .custom:
            // 保证 start <= end
            if customStart <= customEnd {
                return (customStart, customEnd)
            } else {
                return (customEnd, customStart)
            }
        default:
            return range.resolve()
        }
    }

    private func percentString(_ value: Double) -> String {
        String(format: "%.0f%%", value * 100)
    }
}
