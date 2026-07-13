//
//  SubjectAggregator.swift
//  StudyPulse
//
//  按科目分组并预计算平均分 / 计数 / 最近 N 天 / 排序后数组的纯函数服务。
// 之前在 HomeView 和 StudySuggestionsCard 各有一份重复实现,合并到这里。
//
//  Created for MVVM refactor (2026-07-05).
//

import Foundation

/// 单个科目的聚合结果(只读 value type)。
/// Per-subject aggregate (read-only value type).
struct SubjectAggregate: Equatable {
    /// 科目名称
    /// Subject name.
    let subject: String
    /// 全部样本的平均分
    /// Average score across all samples.
    let average: Double
    /// 样本数
    /// Sample count.
    let count: Int
    /// 最近 N 天内的样本数(默认 30 天)
    /// Sample count inside the recent-N-days window (default 30).
    let recentCount: Int
    /// 按日期升序排序的 Grade 列表(便于连续观察趋势)
    /// Grades sorted by date asc (convenient for trend observation).
    let sortedAsc: [Grade]
}

/// 科目聚合服务。纯函数,无副作用,无 SwiftUI 依赖。
/// Subject aggregation. Pure, side-effect-free, no SwiftUI deps.
enum SubjectAggregator {

    /// 一次扫描所有 grades,按 subject 分组并预计算 avg / count / recent / sorted。
    /// One scan over grades, grouped by subject with avg / count / recent / sorted.
    /// - Parameters:
    ///   - grades: 输入成绩列表
    ///     Input grades.
    ///   - subjects: 限定只聚合这些科目(空 = 聚合所有)
    ///     Restrict to these subjects (empty = all).
    ///   - recentDays: "最近 N 天"窗口,默认 30
    ///     Recent-N-days window (default 30).
    ///   - referenceDate: 当前时间(用于计算最近窗口,默认 Date())
    ///     Reference date for the recent window (default `Date()`).
    ///   - includeRecentCount: 是否计算 recentCount(StudySuggestionsCard 用不到,跳过省时间)
    ///     Whether to compute `recentCount` (skipped in
    ///     `StudySuggestionsCard` for performance).
    /// - Returns: subject → SubjectAggregate
    ///   subject → SubjectAggregate map.
    static func aggregate(
        grades: [Grade],
        subjects: Set<String> = [],
        recentDays: Int = 30,
        referenceDate: Date = Date(),
        includeRecentCount: Bool = true
    ) -> [String: SubjectAggregate] {
        guard !grades.isEmpty else { return [:] }

        let recentThreshold: Date? = includeRecentCount
            ? Calendar.current.date(byAdding: .day, value: -recentDays, to: referenceDate)
            : nil

        // 单次 group by subject
        var groups: [String: [Grade]] = [:]
        for g in grades {
            groups[g.subject, default: []].append(g)
        }

        var result: [String: SubjectAggregate] = [:]
        for (subject, arr) in groups where !arr.isEmpty {
            // 限定到指定 subjects(若给定)
            if !subjects.isEmpty, !subjects.contains(subject) { continue }

            let sortedAsc = arr.sorted { $0.date < $1.date }
            let total = sortedAsc.reduce(0.0) { $0 + $1.score }
            let average = total / Double(sortedAsc.count)
            let recentCount: Int = {
                guard let threshold = recentThreshold else { return 0 }
                return sortedAsc.reduce(0) { $0 + ($1.date >= threshold ? 1 : 0) }
            }()
            result[subject] = SubjectAggregate(
                subject: subject,
                average: average,
                count: sortedAsc.count,
                recentCount: recentCount,
                sortedAsc: sortedAsc
            )
        }
        return result
    }

    /// 排除样本数不足 minCount 的科目(避免 1 条数据定全局)。
    /// Drop subjects with fewer than `minCount` samples (avoids
    /// single-sample dominance).
    static func qualifiedAggregates(
        _ aggregates: [String: SubjectAggregate],
        minCount: Int = 2
    ) -> [String: SubjectAggregate] {
        aggregates.filter { $0.value.count >= minCount }
    }

    // MARK: - Statistics over a single subject's grades
    // MARK: - 单科目统计 / Per-subject statistics

    /// 单科平均分(无样本返回 0)
    /// Average score (0 if no samples).
    static func averageScore(for grades: [Grade]) -> Double {
        guard !grades.isEmpty else { return 0 }
        return grades.reduce(0) { $0 + $1.score } / Double(grades.count)
    }

    /// 单科最高分
    /// Highest score.
    static func highestScore(for grades: [Grade]) -> Double {
        grades.max { $0.score < $1.score }?.score ?? 0
    }

    /// 单科最低分
    /// Lowest score.
    static func lowestScore(for grades: [Grade]) -> Double {
        grades.min { $0.score < $1.score }?.score ?? 0
    }
}
