//
//  ExamFilter.swift
//  StudyPulse
//
//  考试列表/分桶相关的纯函数。
// 抽取自 ExamView.allExamsSorted / upcomingExams / pastExams / groupedExams
// 以及 TodoView.recomputeEntries 的 upcomingEntries 分桶逻辑。
//
//  Created for MVVM refactor (2026-07-05).
//

import Foundation

/// 考试分桶后的一段(时间窗口 + 窗口内所有考试项)
struct ExamBucket {
    /// 区间标题(本地化)
    let title: String
    /// 区间内的考试项
    let items: [ExamItem]
}

/// 用于跨视图复用的"考试项"统一类型。
/// 既能装单科 Exam 也能装综合 comprehensiveExam。
enum ExamItem: Hashable {
    case single(Exam)
    case comprehensive(comprehensiveExam)

    var date: Date {
        switch self {
        case .single(let e): return e.examDate
        case .comprehensive(let e): return e.examDate
        }
    }

    var id: UUID {
        switch self {
        case .single(let e): return e.id
        case .comprehensive(let e): return e.id
        }
    }
}

/// 考试筛选/分桶服务。纯函数。
enum ExamFilter {

    // MARK: - 合并排序

    /// 把单科和综合考试合并,按 examDate 升序。
    static func mergeAndSort(
        single: [Exam],
        comprehensive: [comprehensiveExam]
    ) -> [ExamItem] {
        var items: [ExamItem] = []
        items.reserveCapacity(single.count + comprehensive.count)
        items.append(contentsOf: single.map(ExamItem.single))
        items.append(contentsOf: comprehensive.map(ExamItem.comprehensive))
        return items.sorted { $0.date < $1.date }
    }

    // MARK: - past / upcoming 拆分

    /// 已过期考试(日期 < 今天 0 点)
    static func pastItems(from items: [ExamItem], now: Date = Date()) -> [ExamItem] {
        let todayStart = Calendar.current.startOfDay(for: now)
        return items.filter { $0.date < todayStart }
    }

    /// 即将到来(日期 >= 今天 0 点)
    static func upcomingItems(from items: [ExamItem], now: Date = Date()) -> [ExamItem] {
        let todayStart = Calendar.current.startOfDay(for: now)
        return items.filter { $0.date >= todayStart }
    }

    // MARK: - 未来考试按时间窗口分桶(Week / Month / Later)

    /// 未来考试按 "1 Week / 1 Month / Later" 分桶。
    /// - Returns: 非空桶的列表,顺序: Week → Month → Later
    static func bucketUpcomingItems(
        from items: [ExamItem],
        now: Date = Date()
    ) -> [ExamBucket] {
        let upcoming = upcomingItems(from: items, now: now)
        guard let oneWeekLater = Calendar.current.date(byAdding: .day, value: 7, to: now),
              let oneMonthLater = Calendar.current.date(byAdding: .month, value: 1, to: now) else {
            return []
        }
        var week: [ExamItem] = []
        var month: [ExamItem] = []
        var later: [ExamItem] = []
        week.reserveCapacity(upcoming.count)
        for item in upcoming {
            if item.date <= oneWeekLater {
                week.append(item)
            } else if item.date <= oneMonthLater {
                month.append(item)
            } else {
                later.append(item)
            }
        }
        var result: [ExamBucket] = []
        if !week.isEmpty { result.append(ExamBucket(title: "Within 1 Week".localized(), items: week)) }
        if !month.isEmpty { result.append(ExamBucket(title: "Within 1 Month".localized(), items: month)) }
        if !later.isEmpty { result.append(ExamBucket(title: "Later".localized(), items: later)) }
        return result
    }

    // MARK: - N 天内 / 已过 N 天 但未登记

    /// 未来 N 天内的考试(14 = 14 天,0 = 全部未来)
    static func examsWithinDays(
        _ days: Int,
        exams: [Exam],
        now: Date = Date()
    ) -> [Exam] {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: days, to: now) else {
            return []
        }
        return exams
            .filter { $0.examDate > now && $0.examDate <= cutoff }
            .sorted { $0.examDate < $1.examDate }
    }

    /// 已过 startDays ~ endDays 之间、但未在 grades 中登记的考试。
    /// - Parameters:
    ///   - startDaysAgo: 时间窗口起点(负数,例如 -3 = 3 天前)
    ///   - endDaysAgo: 时间窗口终点(负数,例如 -7 = 7 天前)
    ///   - grades: 已登记成绩
    ///   - exams: 待查的考试列表
    static func unregisteredExams(
        startDaysAgo: Int,
        endDaysAgo: Int,
        grades: [Grade],
        exams: [Exam],
        now: Date = Date()
    ) -> [Exam] {
        let startOfToday = Calendar.current.startOfDay(for: now)
        guard let windowStart = Calendar.current.date(byAdding: .day, value: startDaysAgo, to: startOfToday),
              let windowEnd = Calendar.current.date(byAdding: .day, value: endDaysAgo, to: startOfToday) else {
            return []
        }
        let dayInterval: TimeInterval = 86_400
        // 预建 key 集合(subject+examName+dateBucket)
        var registeredKeys = Set<String>()
        registeredKeys.reserveCapacity(grades.count)
        for g in grades {
            let dayBucket = Int(g.date.timeIntervalSince1970 / dayInterval)
            registeredKeys.insert("\(g.subject)|\(g.examName)|\(dayBucket)")
        }
        return exams.filter { exam in
            guard exam.examDate < windowStart && exam.examDate >= windowEnd else { return false }
            let dayBucket = Int(exam.examDate.timeIntervalSince1970 / dayInterval)
            return !registeredKeys.contains("\(exam.subject)|\(exam.examName)|\(dayBucket)")
        }.sorted { $0.examDate < $1.examDate }
    }
}
