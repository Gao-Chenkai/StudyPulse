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
/// 负责 [Grade] 增删改查、SwiftData 持久化、filtered 缓存(imageFileName / phaseId 过滤)。
/// 所有实现必须为 @MainActor class,以便通过 @Environment(GradeRepository.self) 注入。
@MainActor
protocol GradeRepository: AnyObject, Sendable {
    /// 全量成绩(按 date desc 排序)
    var grades: [Grade] { get }
    /// 按 active phase 过滤后的成绩缓存
    var filteredGrades: [Grade] { get }

    // MARK: - Lifecycle
    /// 从 ModelContext 加载所有 GradeRecord 到 @Published 数组
    func loadAll(context: ModelContext) async
    /// 仅重读 grades(用于 imageFileName 更新后刷新)
    func reloadFromSwiftData() async
    /// 把内嵌图片迁移到文件系统,返回迁移条数
    @discardableResult
    func migrateInlineImagesIfNeeded() -> Int

    // MARK: - CRUD
    func add(_ grade: Grade)
    func add(_ newGrades: [Grade])
    func update(_ grade: Grade)
    func delete(_ grade: Grade)
    func clearAll() -> Int

    // MARK: - Query helpers
    // 注意:fullScore / displayName 在 SubjectRepository 上。容器做 pass-through。
    // Note: fullScore/displayName live on SubjectRepository; the container exposes them as pass-throughs.
}
