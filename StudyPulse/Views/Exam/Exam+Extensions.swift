//
//  Exam+Extensions.swift
//  StudyPulse
//
//  `Exam` / `ExamReview` 的便利扩展 + 缺失的辅助视图 stub。
//  Convenience extensions on `Exam` / `ExamReview` + stubs for missing
//  auxiliary views.
//
//  Phase 3 后,部分 API 尚未迁移到 DataModels;此处提供最小实现以让
//  `ExamDetailView` 编译通过,同时保留后续替换为正式实现的入口。
//
//

import SwiftUI
import EventKit
import os

// MARK: - Exam 文字 / 时间便捷属性

extension Exam {
    /// 考试具体时间(可读文本)。无 timeSlot 时为"全天"。
    var examTimeText: String {
        if let slot = timeSlot {
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            return "\(f.string(from: slot.startTime))–\(f.string(from: slot.endTime))"
        }
        return "All-day".localized()
    }

    /// 距离考试还有多少天(向上取整)。已考完返回 0。
    var examDurationDays: Int {
        let now = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.startOfDay(for: examEndDate ?? examDate)
        let comps = Calendar.current.dateComponents([.day], from: now, to: end)
        return max(comps.day ?? 0, 0)
    }

    /// 是否尚未考试(开考时间在将来)。
    var isUpcoming: Bool {
        examDate > Date()
    }

    /// 距离开考剩余时间的人类可读文本。
    ///  - 已结束:"Finished"
    ///  - 当天:"<H> 小时 / <M> 分钟"
    ///  - 未来:"<D> 天"
    var timeLeftText: String {
        if examReview != nil { return "Finished".localized() }
        let now = Date()
        let interval = examDate.timeIntervalSince(now)
        if interval <= 0 {
            return "Started".localized()
        }
        let totalMinutes = Int(interval / 60)
        let days = totalMinutes / (60 * 24)
        let hours = (totalMinutes % (60 * 24)) / 60
        let minutes = totalMinutes % 60
        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    /// 考试分享文本(单行 + 关键字段)。
    var shareableText: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        let timePart = timeSlot.map { f.string(from: $0.startTime) } ?? "All-day"
        var lines = [
            "📚 \(name)",
            "Subject: \(subject)",
            "Exam Alias: \(examName.isEmpty ? "-" : examName)",
            "Date: \(f.string(from: examDate)) (\(timePart))",
            "Importance: \(importance)/5"
        ]
        if !locationSchool.isEmpty {
            lines.append("Location: \(locationSchool) \(locationClassroom) \(locationSeat)".trimmingCharacters(in: .whitespaces))
        }
        return lines.joined(separator: "\n")
    }

    /// 调度考前倒计时通知(stub,委托给 ExamPrepareNotifications)。
    func scheduleNotifications() async throws {
        let effectiveDays = countdownNotifyDays ?? [1, 3, 5, 10, 30]
        ExamPrepareNotifications.shared.scheduleNotifications(
            for: name,
            date: examDate,
            days: effectiveDays
        )
    }

    /// 添加到系统日历(stub,使用 EventKit 写入一条事件)。
    @MainActor
    func addToSystemCalendar() async -> Bool {
        let store = EKEventStore()
        do {
            let granted: Bool
            if #available(iOS 17.0, *) {
                granted = try await store.requestWriteOnlyAccessToEvents()
            } else {
                granted = try await store.requestAccess(to: .event)
            }
            guard granted else { return false }

            let event = EKEvent(eventStore: store)
            event.title = name
            event.notes = "Subject: \(subject)\nAlias: \(examName)\nImportance: \(importance)/5"
            if let slot = timeSlot {
                event.startDate = slot.startTime
                event.endDate = slot.endTime
            } else {
                event.isAllDay = true
                event.startDate = examDate
                event.endDate = examEndDate ?? examDate
            }
            event.calendar = store.defaultCalendarForNewEvents
            let alarm = EKAlarm(relativeOffset: -86_400)  // 1 day before
            event.addAlarm(alarm)
            try store.save(event, span: .thisEvent, commit: true)
            return true
        } catch {
            Log.data.error("addToSystemCalendar failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}

// MARK: - ExamReview 便捷属性

extension ExamReview {
    /// 4 段拼成的 1-2 句概要(供"复制摘要"使用)。
    /// nil/空段会被过滤。
    var summary: String {
        [whatWasTested, whatWentWrong, whatLearned, nextStrategy]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}

// MARK: - 缺失的辅助视图 stub

/// 复盘编辑视图(stub)
/// 4 段 Markdown 编辑 + 关联错题多选。
struct ExamReviewEditView: View {
    let exam: Exam
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Text("Exam review editor (stub for \(exam.name))")
                .padding()
                .navigationTitle("Edit Review".localized())
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close".localized()) { dismiss() }
                    }
                }
        }
    }
}

/// 考前清单编辑视图(stub)
struct ExamChecklistEditView: View {
    let exam: Exam
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Text("Checklist editor (stub for \(exam.name))")
                .padding()
                .navigationTitle("Edit Checklist".localized())
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close".localized()) { dismiss() }
                    }
                }
        }
    }
}

/// 成绩预测视图(stub)
struct ScorePredictionView: View {
    let exam: Exam
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Text("Score prediction (stub for \(exam.name))")
                .padding()
                .navigationTitle("AI Score Prediction".localized())
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close".localized()) { dismiss() }
                    }
                }
        }
    }
}

/// 分享 sheet(UIKit UIActivityViewController 的 SwiftUI 包装)
struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No-op
    }
}
