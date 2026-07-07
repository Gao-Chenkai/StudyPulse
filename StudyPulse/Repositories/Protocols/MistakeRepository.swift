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
/// 负责 [MistakeNote] 增删改查、SRS 复习状态管理、掌握度更新、SwiftData 持久化。
@MainActor
protocol MistakeRepository: AnyObject, Sendable {
    var mistakeSets: [MistakeNote] { get }
    /// 按 active phase 过滤后的错题缓存
    var filteredMistakeSets: [MistakeNote] { get }

    // MARK: - Lifecycle
    func loadAll(context: ModelContext) async

    // MARK: - CRUD
    func add(_ mistake: MistakeNote)
    func add(_ newMistakes: [MistakeNote])
    func update(_ mistake: MistakeNote)
    func delete(_ mistake: MistakeNote)
    func delete(at offsets: IndexSet, in set: inout [MistakeNote])
    func clearAll() -> Int

    // MARK: - SRS & Mastery
    /// 仅更新 SRS 复习状态(不影响其它字段)
    func updateReviewState(_ mistakeId: UUID, newState: ReviewState?)
    /// 详情页 / 闪卡被打开:exposure +1
    func recordExposure(_ mistakeId: UUID)
    /// 闪卡自评:exposure +1,EMA 调整 masteryScore,追加 history
    func recordReview(_ mistakeId: UUID, quality: ReviewQuality, now: Date)
    /// 闪卡手写答题:追加一条 HandwritingAnswerEntry 到 handwritingHistory
    /// Flashcard handwriting answer: append one `HandwritingAnswerEntry` to
    /// `handwritingHistory`. `quality` is `nil` if the user wrote but skipped rating.
    func recordHandwriting(_ mistakeId: UUID, pngData: Data, quality: ReviewQuality?, now: Date)
}
