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
/// 负责 [Subject] 增删改查、按教育阶段 + 地区智能推荐、SwiftData 持久化。
@MainActor
protocol SubjectRepository: AnyObject, Sendable {
    var subjects: [Subject] { get set }

    // MARK: - Lifecycle
    func loadAll(context: ModelContext) async

    // MARK: - CRUD
    /// 同步 subjects 到 SwiftData(增量 upsert,按 name 匹配)
    func saveSubjects()
    /// 根据 profile 初始化默认科目(仅在空时调用)
    func initializeDefaultSubjects()
    /// 根据教育阶段 + 地区智能推荐科目(保留已有 enabled 状态)
    func applySmartSubjectRecommendation(stage: EducationStage, regionCode: String)

    // MARK: - Query helpers
    func fullScore(for subjectName: String) -> Double
    func displayName(for subjectName: String) -> String
}
