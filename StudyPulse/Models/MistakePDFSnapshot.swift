//
//  MistakePDFSnapshot.swift
//  StudyPulse
//
//  不可变快照：把错题模块当前数据按用户选择的模式过滤并拷贝出来，
//  供 PDF 渲染器使用。沿用 StudyReport 的 Sendable 模式，
//  让 PDF 渲染阶段不直接持有 @EnvironmentObject。
//
//  Immutable snapshot used by the Mistake PDF renderer. It filters
//  and copies the current mistake data based on the user's selection
//  mode (subject / date / explicit IDs), so the renderer doesn't
//  need a live `DataManager`.
//

import Foundation

// MARK: - 错题 PDF 选择模式

/// 错题 PDF 导出的筛选模式。互斥使用，由 UI 上的 Picker 决定。
/// Selection mode used to filter mistakes before PDF generation.
/// The UI presents these as mutually-exclusive options.
nonisolated enum MistakePDFSelection: Sendable, Equatable {
    /// 按所选科目（多选）筛选。
    case bySubjects(Set<String>)
    /// 按时间范围筛选（start...end，含两端）。
    case byDateRange(start: Date, end: Date)
    /// 按手动勾选的错题 ID 集合筛选。
    case byIDs(Set<UUID>)
}

// MARK: - 错题 PDF 快照

/// 不可变快照：导出时一次性拷贝，避免渲染过程中持有 ObservableObject。
/// Immutable snapshot, copied once at generation time.
nonisolated struct MistakePDFSnapshot: Identifiable, Sendable {
    /// 用 generatedAt 作为 id 即可（每次生成都是新值）。
    /// Use generatedAt as id (always unique per generation).
    var id: Date { generatedAt }

    let generatedAt: Date
    let profile: UserProfile
    let subjects: [Subject]
    let mistakes: [MistakeNote]
    let selection: MistakePDFSelection
    let includeImages: Bool

    /// 显示名（沿用 DataManager 的语义：displayName > subject.name）。
    func displayName(for subject: String) -> String {
        guard let match = subjects.first(where: { $0.name == subject }) else {
            return subject
        }
        return match.displayName.isEmpty ? subject : match.displayName
    }
}

// MARK: - 派生

extension MistakePDFSnapshot {
    /// 错题数（封面/副标题使用）。
    var mistakeCount: Int { mistakes.count }

    /// 按科目分组的错题数（封面统计使用）。
    /// Mistake counts grouped by subject (used on the cover).
    var mistakeCountBySubject: [(subject: String, count: Int)] {
        let groups = Dictionary(grouping: mistakes) { $0.subject.isEmpty ? "Uncategorized" : $0.subject }
        return groups
            .map { ($0.key, $0.value.count) }
            .sorted { $0.0 < $1.0 }
    }

    /// 时间范围描述。
    var dateRangeDescription: String? {
        guard case let .byDateRange(start, end) = selection else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "\(formatter.string(from: start)) → \(formatter.string(from: end))"
    }

    /// 选择模式的人类可读描述（用于封面副标题）。
    var selectionDescription: String {
        switch selection {
        case .bySubjects:
            return NSLocalizedString("By Subjects", comment: "Mistake PDF selection mode")
        case .byDateRange:
            return NSLocalizedString("By Date Range", comment: "Mistake PDF selection mode")
        case .byIDs:
            return NSLocalizedString("By Mistakes", comment: "Mistake PDF selection mode")
        }
    }
}

// MARK: - 工厂

extension MistakePDFSnapshot {
    /// 在主线程上从 DataManager 拷贝快照。
    /// - Returns: 当无错题可导出时返回 nil。
    @MainActor
    static func make(
        from dataManager: DataManager,
        selection: MistakePDFSelection,
        includeImages: Bool
    ) -> MistakePDFSnapshot? {
        let all = dataManager.mistakeSets
        let filtered = filter(all, with: selection)
        guard !filtered.isEmpty else { return nil }

        // 排序：按科目，再按日期倒序
        let sorted = filtered.sorted { lhs, rhs in
            if lhs.subject != rhs.subject {
                return lhs.subject.localizedCompare(rhs.subject) == .orderedAscending
            }
            return lhs.date > rhs.date
        }

        return MistakePDFSnapshot(
            generatedAt: Date(),
            profile: dataManager.profile,
            subjects: dataManager.subjects,
            mistakes: sorted,
            selection: selection,
            includeImages: includeImages
        )
    }

    /// 纯函数：在 selection 下过滤错题。
    /// Pure filter function (no DataManager dependency).
    static func filter(_ mistakes: [MistakeNote], with selection: MistakePDFSelection) -> [MistakeNote] {
        switch selection {
        case .bySubjects(let subjects):
            guard !subjects.isEmpty else { return [] }
            return mistakes.filter { subjects.contains($0.subject) }
        case .byDateRange(let start, let end):
            return mistakes.filter { mistake in
                mistake.date >= start && mistake.date <= end
            }
        case .byIDs(let ids):
            guard !ids.isEmpty else { return [] }
            return mistakes.filter { ids.contains($0.id) }
        }
    }

    /// 不创建快照也能快速预览错题数（用于 sheet 实时计数）。
    /// Preview the count without instantiating a snapshot.
    @MainActor
    static func previewCount(
        from dataManager: DataManager,
        selection: MistakePDFSelection
    ) -> Int {
        filter(dataManager.mistakeSets, with: selection).count
    }
}
