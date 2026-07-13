//
//  MistakeRepository.swift
//  StudyPulse
//
//  错题 (MistakeNote) 域 Repository 协议。
//  Mistake note domain repository protocol.
//

import Foundation
import SwiftData

/// 错题 Repository 协议。
/// Mistake repository protocol.
/// 负责 [MistakeNote] 增删改查、SRS 复习状态管理、掌握度更新、SwiftData 持久化。
/// Owns [MistakeNote] CRUD, SRS review state, mastery updates, and SwiftData persistence.
@MainActor
protocol MistakeRepository: AnyObject, Sendable {
    /// 全部错题
    /// All mistake notes.
    var mistakeSets: [MistakeNote] { get }
    /// 按 active phase 过滤后的错题缓存
    /// Cached mistakes filtered by the active phase.
    var filteredMistakeSets: [MistakeNote] { get }

    // MARK: - Lifecycle
    // MARK: - 生命周期 / Lifecycle

    /// 加载所有错题
    /// Load all mistake notes.
    func loadAll(context: ModelContext) async

    // MARK: - CRUD
    // MARK: - 增删改查 / CRUD

    /// 新增一条
    /// Add one mistake.
    func add(_ mistake: MistakeNote)
    /// 批量新增
    /// Batch add.
    func add(_ newMistakes: [MistakeNote])
    /// 更新
    /// Update.
    func update(_ mistake: MistakeNote)
    /// 删除
    /// Delete.
    func delete(_ mistake: MistakeNote)
    /// 按下标删除（用于 List onDelete）
    /// Delete by index offsets (used by `List` onDelete).
    func delete(at offsets: IndexSet, in set: inout [MistakeNote])
    /// 清空
    /// Clear all.
    func clearAll() -> Int

    // MARK: - SRS & Mastery
    // MARK: - SRS & 掌握度 / SRS & Mastery

    /// 仅更新 SRS 复习状态(不影响其它字段)
    /// Update SRS state only (other fields untouched).
    func updateReviewState(_ mistakeId: UUID, newState: ReviewState?)
    /// 详情页 / 闪卡被打开:exposure +1
    /// Detail page / flashcard opened: increment exposure by 1.
    func recordExposure(_ mistakeId: UUID)
    /// 闪卡自评:exposure +1,EMA 调整 masteryScore,追加 history
    /// Flashcard self-rating: exposure +1, EMA-adjust masteryScore, append history.
    func recordReview(_ mistakeId: UUID, quality: ReviewQuality, now: Date)
    /// 闪卡手写答题:追加一条 HandwritingAnswerEntry 到 handwritingHistory
    /// Flashcard handwriting answer: append one `HandwritingAnswerEntry` to
    /// `handwritingHistory`. `quality` is `nil` if the user wrote but skipped rating.
    func recordHandwriting(_ mistakeId: UUID, pngData: Data, quality: ReviewQuality?, now: Date)

    // MARK: - Tags
    // MARK: - 标签 / Tags

    /// 收集所有错题中出现过的 tag(去重、保序)
    /// Collect all tags ever used in any mistake (deduped, ordered).
    func allTags() -> [String]
    /// 按标签计数(降序)
    /// Tag counts, sorted descending.
    func tagCounts() -> [(tag: String, count: Int)]
}
