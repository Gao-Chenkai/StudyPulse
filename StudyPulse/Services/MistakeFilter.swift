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
/// Mistake grouping result.
struct MistakeGroups {
    /// 按 subject 分组(空 subject 归到 "Uncategorized")
    /// Grouped by subject (empty subject → "Uncategorized").
    let bySubject: [String: [MistakeNote]]
    /// 科目列表,按错题数降序、同数按字母升序
    /// Subject list, sorted by mistake count desc (ties alphabetical asc).
    let sortedSubjects: [String]
    /// 应用搜索词后的科目列表
    /// Subject list after applying the search text.
    let filteredSubjects: [String]
    /// 总数
    /// Total mistake count.
    let totalCount: Int
}

/// 错题筛选/分组服务。纯函数。
/// Mistake filter / grouping. Pure functions.
enum MistakeFilter {

    /// 一次性产出 5 个聚合结果(分组 + 排序 + 搜索过滤 + 总数)。
    /// Produce the 5 aggregate outputs in one pass (group + sort + search filter + total).
    /// - Parameters:
    ///   - mistakes: 输入错题
    ///     Input mistake notes.
    ///   - searchText: 搜索词,支持 `#tag1 #tag2` 多标签 AND + 自由文本子串匹配
    ///     Search text: supports `#tag1 #tag2` (AND across tags) and free text substring match.
    ///   - uncategorizedKey: 空 subject 归到哪个桶(默认 "Uncategorized")
    ///     Bucket name for empty subject (default "Uncategorized").
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

        // 3. 搜索过滤:复用 parser
        let parsed = parseSearchQuery(searchText)
        let filteredSubjects: [String] = (parsed.tags.isEmpty && parsed.text.isEmpty)
            ? sortedSubjects
            : sortedSubjects.filter { subject in
                // subject 命中 OR 该组下任一错题命中
                if parsed.tags.isEmpty && parsed.text.isEmpty { return true }
                // subject 名称本身命中(仅在自由文本模式下)
                if parsed.tags.isEmpty,
                   subject.localizedCaseInsensitiveContains(parsed.text) {
                    return true
                }
                return (groups[subject] ?? []).contains { matches($0, parsed: parsed) }
            }

        return MistakeGroups(
            bySubject: groups,
            sortedSubjects: sortedSubjects,
            filteredSubjects: filteredSubjects,
            totalCount: mistakes.count
        )
    }

    // MARK: - 单科目内的搜索/排序/复习建议
    // MARK: - 单科目内的搜索/排序/复习建议 / Per-subject search/sort/review

    // MARK: - 搜索词解析
    // MARK: - 搜索词解析 / Search query parser

    /// 把搜索词拆成 (1) 标签过滤(精确大小写不敏感,AND 多标签) + (2) 自由文本(子串匹配)。
    /// Split the query into (1) tag filter (case-insensitive exact match,
    /// AND across tags) + (2) free text (substring match).
    /// 约定:
    /// Conventions:
    ///   - `#tag` 视为标签精确过滤(忽略大小写、忽略前后空白)
    ///     `#tag` = exact tag filter (case-insensitive, trim whitespace).
    ///   - 多个 `#tag` token → AND(必须全部命中)
    ///     Multiple `#tag` tokens → AND.
    ///   - 标签之间允许用空格 / `,` / `, ` 分隔
    ///     Tags can be separated by space / `,` / `, `.
    ///   - 剩余非 `#` 文本走 title / subject / originalQuestion / source / tags 子串匹配
    ///     Remaining non-`#` text substring-matches against title / subject /
    ///     originalQuestion / source / tags.
    static func parseSearchQuery(_ searchText: String) -> (tags: [String], text: String) {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ([], "") }

        // 提取所有 #tag 标记(支持中英文 tag)
        let pattern = #"#([^\s#,]+)"#
        var tagFilters: [String] = []
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(trimmed.startIndex..., in: trimmed)
            for match in regex.matches(in: trimmed, range: range) {
                guard match.numberOfRanges >= 2,
                      let r = Range(match.range(at: 1), in: trimmed) else { continue }
                let tag = String(trimmed[r]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !tag.isEmpty { tagFilters.append(tag.lowercased()) }
            }
        }

        // 去掉所有 #tag 标记 → 剩余自由文本
        let remaining = trimmed
            .replacingOccurrences(of: pattern, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            // 顺手把 , 改成空格(避免误把","当子串匹配)
            .replacingOccurrences(of: ",", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return (tagFilters, remaining)
    }

    /// 判定某错题是否命中解析后的搜索条件
    /// Test whether a mistake matches the parsed search query.
    static func matches(_ mistake: MistakeNote, parsed: (tags: [String], text: String)) -> Bool {
        let (tags, text) = parsed
        // 1) 标签必须全部命中(AND)
        let mistakeTagsLower = Set(mistake.tags.map { $0.lowercased() })
        for t in tags {
            if !mistakeTagsLower.contains(t) { return false }
        }
        // 2) 自由文本子串匹配(空就跳过)
        guard !text.isEmpty else { return true }
        let lower = text.lowercased()
        if mistake.subject.localized().lowercased().contains(lower) { return true }
        if mistake.title.localized().lowercased().contains(lower) { return true }
        if mistake.originalQuestion.localizedCaseInsensitiveContains(text) { return true }
        if mistake.source.localizedCaseInsensitiveContains(text) { return true }
        if mistake.tags.contains(where: { $0.lowercased().contains(lower) }) { return true }
        return false
    }
}

extension MistakeFilter {

    /// 在指定 subject 的错题上做搜索过滤 + 按日期降序排序。
    /// Filter a subject's mistakes by search text + sort by date desc.
    /// 多标签:用空格或逗号分隔的 `#tag1 #tag2` 视为 AND 过滤。
    /// Multi-tag: `#tag1 #tag2` (space- or comma-separated) = AND filter.
    /// Plain 文本(无 `#`)走 title / originalQuestion / source / tags 子串匹配(向后兼容)。
    /// Plain text (no `#`) substring-matches title / originalQuestion /
    /// source / tags (backwards compatible).
    static func searchInSubject(
        _ mistakes: [MistakeNote],
        searchText: String
    ) -> [MistakeNote] {
        let parsed = parseSearchQuery(searchText)
        // 搜索词为空 → 全部返回(原行为)
        if parsed.tags.isEmpty && parsed.text.isEmpty {
            return mistakes.sorted { $0.date > $1.date }
        }
        return mistakes
            .filter { matches($0, parsed: parsed) }
            .sorted { $0.date > $1.date }
    }

    /// 按标签过滤(大小写不敏感,任一 tag 完全匹配)
    /// Filter by tag (case-insensitive; any tag exact-matches).
    static func tagged(_ mistakes: [MistakeNote], tag: String) -> [MistakeNote] {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return mistakes }
        let lower = trimmed.lowercased()
        return mistakes.filter { m in
            m.tags.contains { $0.lowercased() == lower }
        }
    }

    /// 收集所有错题中出现过的 tag(去重 + 保持首次出现顺序,过滤空字符串)
    /// Collect all tags ever used in any mistake (deduped, first-seen order, blanks removed).
    static func allTags(_ mistakes: [MistakeNote]) -> [String] {
        var seenLower: Set<String> = []
        var ordered: [String] = []
        for m in mistakes {
            for tag in m.tags {
                let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                let lower = trimmed.lowercased()
                if seenLower.insert(lower).inserted {
                    ordered.append(trimmed)
                }
            }
        }
        return ordered
    }

    /// 按标签计数(返回 [(tag, count)],已按 count desc 排序;平局按字母升序)
    /// Tag counts as `[(tag, count)]`, sorted by count desc (ties alphabetical asc).
    static func tagCounts(_ mistakes: [MistakeNote]) -> [(tag: String, count: Int)] {
        var counts: [String: Int] = [:]
        var firstAppearance: [String: String] = [:]
        for m in mistakes {
            for raw in m.tags {
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                let key = trimmed.lowercased()
                counts[key, default: 0] += 1
                if firstAppearance[key] == nil {
                    firstAppearance[key] = trimmed
                }
            }
        }
        return counts
            .map { (key, c) in (tag: firstAppearance[key] ?? key, count: c) }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                return lhs.tag.localizedCaseInsensitiveCompare(rhs.tag) == .orderedAscending
            }
    }

    /// 取最近一段时间录入的错题 + 按"复习紧急度"排序。
    /// Most-recent mistakes ranked by review urgency.
    /// 排序规则:
    /// Sort rules:
    /// - 1 周内录入 → 优先级 2(最紧急)
    ///   Recorded within 1 week → priority 2 (most urgent)
    /// - 1 个月前录入 → 优先级 1(中)
    ///   Recorded 1+ month ago → priority 1 (mid)
    /// - 其它 → 优先级 0
    ///   Other → priority 0
    /// 同优先级按日期倒序。返回前 4 条。
    /// Within the same priority, sorted by date desc. Returns the top `limit` items.
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
