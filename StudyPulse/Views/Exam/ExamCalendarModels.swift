//
//  ExamCalendarModels.swift
//  StudyPulse
//
//  考试日历页的所有数据模型 + Calendar 扩展:
//  - CalendarItem                视图层统一的日历条目(包装 Exam / comprehensiveExam / TaskItem)
//  - CalendarItemKind            条目类型 enum(.exam / .comprehensiveExam / .homework / .reading)
//  - CalendarItemKindFilter      类型过滤器(enum,多选由 caller 用 Set 实现)
//  - `Calendar.startOfMonth(...)` 标准化日期到月初
//  - `Calendar.monthGridDays(...)` 给定月份的 7×6 网格
//
//  Phase 3 拆分 (2026-07-14):原 `ExamCalendarView.swift` 抽出,所有数据层独立可单测。
//

import Foundation
import SwiftUI

// MARK: - Calendar Item / 日历条目

/// 视图层统一的"日历条目",把考试 / 作业 / 阅读都装进同一个 view model。
/// View-layer unified "calendar item" that wraps exams, homework, and reading.
struct CalendarItem: Identifiable, Hashable {
    let id: UUID
    let kind: CalendarItemKind
    let title: String
    let subject: String
    let importance: Int
    let isCompleted: Bool
    let start: Date
    let end: Date
    /// 显式标记是否多日(只有考试会用;任务强制 false 节省判断)
    /// Explicit multi-day flag (only exams use it; tasks always `false`).
    let isMultiDay: Bool
    let exam: Exam?
    let comprehensiveExam: comprehensiveExam?
    let taskItem: TaskItem?

    /// 该条目是否单日(起止同一天)
    /// Whether this item is single-day (start == end).
    var isSingleDay: Bool {
        Calendar.current.isDate(start, inSameDayAs: end)
    }

    /// 不同类型用不同颜色
    /// Different colors per kind.
    var accentColor: Color {
        kind.accentColor
    }

    /// 某天是否落在这条目的时间区间内(含起止)
    /// Whether a given day falls within this item's range (inclusive).
    func contains(day: Date) -> Bool {
        let target = Calendar.current.startOfDay(for: day)
        return target >= start && target <= end
    }

    static func == (lhs: CalendarItem, rhs: CalendarItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Kind / 类型

/// 日历条目类型:与 TodoEntryKind 类似但只用于日历视图层
/// Calendar item kind — similar to TodoEntryKind but only used by the calendar view.
enum CalendarItemKind: Hashable, Sendable, CaseIterable {
    case exam
    case comprehensiveExam
    case homework
    case reading

    var accentColor: Color {
        switch self {
        case .exam:              return Color(.systemBlue)
        case .comprehensiveExam: return Color(.systemPurple)
        case .homework:          return Color(.systemGreen)
        case .reading:           return Color(.systemIndigo)
        }
    }

    var systemImage: String {
        switch self {
        case .exam:              return "calendar"
        case .comprehensiveExam: return "square.stack.3d.up.fill"
        case .homework:          return "pencil.and.list.clipboard"
        case .reading:           return "book.fill"
        }
    }

    var displayName: String {
        switch self {
        case .exam:              return "Exam".localized()
        case .comprehensiveExam: return "Comprehensive".localized()
        case .homework:          return "Homework".localized()
        case .reading:           return "Reading".localized()
        }
    }

    /// 排序优先级(数值越小越靠前)
    /// Sort priority (smaller value ranks first).
    var sortPriority: Int {
        switch self {
        case .comprehensiveExam: return 0
        case .exam:              return 1
        case .homework:          return 2
        case .reading:           return 3
        }
    }
}

/// 月历视图的类型过滤器(与 TodoTypeFilter 平行)
/// Type filter for the monthly calendar view (parallel to TodoTypeFilter).
enum CalendarItemKindFilter: Hashable {
    case all
    case exam
    case homework
    case reading
}

// MARK: - Calendar Extension / Calendar 扩展

extension Calendar {
    /// 标准化到月初(00:00:00)/ Normalize to the first day of the month (00:00:00).
    func startOfMonth(for date: Date) -> Date {
        var components = dateComponents([.year, .month], from: date)
        components.day = 1
        components.hour = 0
        components.minute = 0
        components.second = 0
        return self.date(from: components) ?? date
    }

    /// 给定月份的 7×6 网格(42 天,从月头所在周的第一天开始)
    /// 7×6 grid (42 days, starting from the first day of the week the
    /// month's first day falls in).
    func monthGridDays(for monthAnchor: Date) -> [Date] {
        let monthStart = startOfMonth(for: monthAnchor)
        let weekdayIndex = component(.weekday, from: monthStart) - 1
        guard let gridStart = self.date(byAdding: .day, value: -weekdayIndex, to: monthStart) else {
            return []
        }
        return (0..<42).compactMap { offset in
            self.date(byAdding: .day, value: offset, to: gridStart)
        }
    }
}
