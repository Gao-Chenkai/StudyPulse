//
//  SubjectRepository.swift
//  StudyPulse
//
//  科目 (Subject) 域 Repository 协议。
//  Subject domain repository protocol.
//

import Foundation
import SwiftData

/// 科目 Repository 协议。
/// Subject repository protocol.
/// 负责 [Subject] 增删改查、按教育阶段 + 地区智能推荐、SwiftData 持久化。
/// Owns [Subject] CRUD, smart recommendations by education stage /
/// region, and SwiftData persistence.
@MainActor
protocol SubjectRepository: AnyObject, Sendable {
    /// 全部科目
    /// All subjects.
    var subjects: [Subject] { get set }

    // MARK: - Lifecycle
    // MARK: - 生命周期 / Lifecycle

    /// 加载全部科目
    /// Load all subjects.
    func loadAll(context: ModelContext) async

    // MARK: - CRUD
    // MARK: - 增删改查 / CRUD

    /// 同步 subjects 到 SwiftData(增量 upsert,按 name 匹配)
    /// Sync `subjects` to SwiftData (incremental upsert, matched by name).
    func saveSubjects()
    /// 根据 profile 初始化默认科目(仅在空时调用)
    /// Initialize default subjects from profile (no-op if non-empty).
    func initializeDefaultSubjects()
    /// 根据教育阶段 + 地区智能推荐科目(保留已有 enabled 状态)
    /// Apply smart recommendations; preserves existing `enabled` flags.
    func applySmartSubjectRecommendation(stage: EducationStage, regionCode: String)

    // MARK: - Query helpers
    // MARK: - 查询工具 / Query helpers

    /// 获取某科目的满分
    /// Get the full score for a subject.
    func fullScore(for subjectName: String) -> Double
    /// 获取某科目的本地化显示名
    /// Get the localized display name for a subject.
    func displayName(for subjectName: String) -> String
}
