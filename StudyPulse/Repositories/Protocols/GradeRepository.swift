//
//  GradeRepository.swift
//  StudyPulse
//
//  成绩 (Grade) 域 Repository 协议。
//  Grade domain repository protocol.
//

import Foundation
import SwiftData

/// 成绩 Repository 协议。
/// Grade repository protocol.
/// 负责 [Grade] 增删改查、SwiftData 持久化、filtered 缓存(imageFileName / phaseId 过滤)。
/// Owns [Grade] CRUD, SwiftData persistence, and the filtered cache
/// (by `imageFileName` and `phaseId`).
/// 所有实现必须为 @MainActor class,以便通过 @Environment(GradeRepository.self) 注入。
/// All implementations must be `@MainActor` classes so they can be
/// injected via `@Environment(GradeRepository.self)`.
@MainActor
protocol GradeRepository: AnyObject, Sendable {
    /// 全量成绩(按 date desc 排序)
    /// All grades, sorted by date desc.
    var grades: [Grade] { get }
    /// 按 active phase 过滤后的成绩缓存
    /// Cached grades filtered by the active phase.
    var filteredGrades: [Grade] { get }

    // MARK: - Lifecycle
    // MARK: - 生命周期 / Lifecycle

    /// 从 ModelContext 加载所有 GradeRecord 到 @Published 数组
    /// Load all `GradeRecord` from the ModelContext into the published array.
    func loadAll(context: ModelContext) async
    /// 仅重读 grades(用于 imageFileName 更新后刷新)
    /// Re-read grades only (used to refresh after an `imageFileName` update).
    func reloadFromSwiftData() async
    /// 把内嵌图片迁移到文件系统,返回迁移条数
    /// Migrate inline image data to filesystem-backed files; returns the count.
    @discardableResult
    func migrateInlineImagesIfNeeded() -> Int

    // MARK: - CRUD
    // MARK: - 增删改查 / CRUD

    /// 新增一条
    /// Add one grade.
    func add(_ grade: Grade)
    /// 批量新增
    /// Batch add.
    func add(_ newGrades: [Grade])
    /// 更新
    /// Update.
    func update(_ grade: Grade)
    /// 删除
    /// Delete.
    func delete(_ grade: Grade)
    /// 清空所有
    /// Clear all.
    func clearAll() -> Int

    // MARK: - Query helpers
    // MARK: - 查询工具 / Query helpers
    // 注意:fullScore / displayName 在 SubjectRepository 上。容器做 pass-through。
    // Note: fullScore/displayName live on SubjectRepository; the container exposes them as pass-throughs.
}
