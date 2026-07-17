//
//  DiaryRepository.swift
//  StudyPulse
//
//  学习日记 (DiaryEntry) 域 Repository 协议。
//  Diary entry domain repository protocol.
//

import Foundation
import SwiftData

/// 学习日记 Repository 协议。
/// Diary repository protocol.
/// 负责 [DiaryEntry] 增删改查、按时间范围检索、SwiftData 持久化。
/// Owns [DiaryEntry] CRUD, date-range queries, and SwiftData persistence.
@MainActor
protocol DiaryRepository: AnyObject, Sendable {
    /// 全部日记(按 date desc 排序)
    /// All diary entries, sorted by date desc.
    var diaryEntries: [DiaryEntry] { get }
    /// 按 active phase 过滤后的日记缓存
    /// Cached diary entries filtered by the active phase.
    var filteredDiaryEntries: [DiaryEntry] { get }

    // MARK: - Lifecycle
    // MARK: - 生命周期 / Lifecycle

    /// 加载所有日记
    /// Load all diary entries.
    func loadAll(context: ModelContext) async

    // MARK: - CRUD
    // MARK: - 增删改查 / CRUD

    /// 新增一条日记
    /// Add one diary entry.
    func add(_ entry: DiaryEntry)
    /// 更新
    /// Update.
    func update(_ entry: DiaryEntry)
    /// 删除
    /// Delete.
    func delete(_ entry: DiaryEntry)
    /// 清空
    /// Clear all.
    func clearAll() -> Int

    // MARK: - Query
    // MARK: - 查询 / Query

    /// 取指定时间范围内的日记(按日期升序)
    /// Entries in the given [start, end) range, sorted ascending by date.
    func entriesInRange(_ start: Date, _ end: Date) -> [DiaryEntry]
    /// 今天的日记(若有;按 date 去重,取最新一条)
    /// Today's diary entry if any (latest one when multiple share the same day).
    func todayEntry() -> DiaryEntry?
}
