//
//  MistakeFilter.swift
//  StudyPulse
//
//  错题搜索/分组/复习建议的纯函数。
// 抽取自 MistakeView.recomputeAll / SubjectMistakesView 的 3 个 computed properties。
//
//  Created for MVVM refactor (2026-07-05).
//

import Foundation

/// 错题分组结果
struct MistakeGroups {
    /// 按 subject 分组(空 subject 归到 "Uncategorized")
    let bySubject: [String: [MistakeNote]]
    /// 科目列表,按错题数降序、同数按字母升序
    let sortedSubjects: [String]
    /// 应用搜索词后的科目列表
    let filteredSubjects: [String]
    /// 总数
    let totalCount: Int
}

/// 错题筛选/分组服务。纯函数。
enum MistakeFilter {

    /// 一次性产出 5 个聚合结果(分组 + 排序 + 搜索过滤 + 总数)。
    /// - Parameters:
    ///   - mistakes: 输入错题
    ///   - searchText: 搜索词(空 = 不过滤)
    ///   - uncategorizedKey: 空 subject 归到哪个桶(默认 "Uncategorized")
    static func group(
        mistakes: [MistakeNote],
        searchText: String,
        uncategorizedKey: String = "Uncategorized"
    ) -> MistakeGroups {
        // 1. 按 subject 分组
        var groups: [String: [MistakeNote]] = [:]
        for m in mistakes {
            let key = m.subject.isEmpty ? uncategorizedKey : m.subject
            groups[key, default: []].append(m)
        }

        // 2. 排序:按错题数降序,同数按字母升序
        let sortedSubjects = groups.keys.sorted { a, b in
            let ca = groups[a]?.count ?? 0
            let cb = groups[b]?.count ?? 0
            if ca != cb { return ca > cb }
            return a.localizedCompare(b) == .orderedAscending
        }

        // 3. 搜索过滤
        let filteredSubjects: [String]
        if searchText.isEmpty {
            filteredSubjects = sortedSubjects
        } else {
            filteredSubjects = sortedSubjects.filter { subject in
                if subject.localizedCaseInsensitiveContains(searchText) { return true }
                return groups[subject]?.contains {
                    $0.title.localizedCaseInsensitiveContains(searchText) ||
                    $0.originalQuestion.localizedCaseInsensitiveContains(searchText)
                } ?? false
            }
        }

        return MistakeGroups(
            bySubject: groups,
            sortedSubjects: sortedSubjects,
            filteredSubjects: filteredSubjects,
            totalCount: mistakes.count
        )
    }

    // MARK: - 单科目内的搜索/排序/复习建议

    /// 在指定 subject 的错题上做搜索过滤 + 按日期降序排序。
    static func searchInSubject(
        _ mistakes: [MistakeNote],
        searchText: String
    ) -> [MistakeNote] {
        if searchText.isEmpty {
            return mistakes.sorted { $0.date > $1.date }
        }
        return mistakes.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.originalQuestion.localizedCaseInsensitiveContains(searchText) ||
            $0.source.localizedCaseInsensitiveContains(searchText)
        }.sorted { $0.date > $1.date }
    }

    /// 取最近一段时间录入的错题 + 按"复习紧急度"排序。
    /// 排序规则:
    /// - 1 周内录入 → 优先级 2(最紧急)
    /// - 1 个月前录入 → 优先级 1(中)
    /// - 其它 → 优先级 0
    /// 同优先级按日期倒序。返回前 4 条。
    static func suggestedForReview(
        _ mistakes: [MistakeNote],
        now: Date = Date(),
        limit: Int = 4
    ) -> [MistakeNote] {
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: now) ?? now
        return mistakes.sorted { a, b in
            let pa = (a.date > oneWeekAgo ? 2 : a.date < oneMonthAgo ? 1 : 0)
            let pb = (b.date > oneWeekAgo ? 2 : b.date < oneMonthAgo ? 1 : 0)
            if pa != pb { return pa > pb }
            return a.date > b.date
        }.prefix(limit).map { $0 }
    }
}
