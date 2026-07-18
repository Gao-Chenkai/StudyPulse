//
//  DefaultSubjectRepository.swift
//  StudyPulse
//
//  科目 (Subject) Repository 默认实现。
//  Default SubjectRepository implementation backed by SwiftData.
//

import Foundation
import SwiftData
import os

@Observable @MainActor
final class DefaultSubjectRepository: SubjectRepository {
    /// 全部科目（按 name asc）
    /// All subjects, sorted by name asc.
    var subjects: [Subject] = []

    @ObservationIgnored
    private var modelContext: ModelContext?

    /// SubjectRecord by name 缓存;首次 saveSubjects 时填充,后续复用,避免每次 fetch 全表。
    /// Cached SubjectRecord by name; populated on first saveSubjects, reused afterwards
    /// to avoid fetching the full table on every save.
    @ObservationIgnored
    private var subjectEntitiesByName: [String: SubjectRecord] = [:]

    /// 跨域引用:initializeDefaultSubjects 依赖 profile 字段
    /// Cross-domain ref: initializeDefaultSubjects reads profile fields.
    @ObservationIgnored
    weak var profileRef: (any ProfileRepository)?

    init() {}

    /// 容器在 init 时调用,注入 ProfileRepository weak 引用。
    /// Called by the container on init; injects ProfileRepository weak ref.
    func setProfileRef(_ repo: any ProfileRepository) {
        self.profileRef = repo
    }

    // MARK: - Lifecycle
    // MARK: - 生命周期 / Lifecycle

    /// 加载全部科目
    /// Load all subjects.
    ///
    /// 保持在主 actor 同步 fetch:subjectEntitiesByName 缓存持有 @Model SubjectRecord,
    /// 必须绑定到主 context 才能在 saveSubjects() 中修改。数据量小(~10-15 条),
    /// detached 化收益 < 5ms,不值得改造缓存层。
    /// Keep sync on main actor: subjectEntitiesByName holds @Model SubjectRecord
    /// refs that must be bound to the main context for saveSubjects() mutations.
    /// Data is tiny (~10-15 records); detached fetch saves < 5ms — not worth a
    /// cache refactor.
    func loadAll(context: ModelContext) async {
        self.modelContext = context
        do {
            let entities = try context.fetch(FetchDescriptor<SubjectRecord>())
            self.subjects = entities.map { $0.toSnapshot() }
            // 填充 entities 缓存
            var cache: [String: SubjectRecord] = [:]
            for e in entities { cache[e.name] = e }
            self.subjectEntitiesByName = cache
        } catch {
            Log.data.error("DefaultSubjectRepository loadAll failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - CRUD
    // MARK: - 增删改查 / CRUD

    /// 把当前 `subjects` 数组 upsert 进 SwiftData（增删改 + 同步缓存）
    /// Upsert the current `subjects` array into SwiftData (CRUD + cache sync).
    func saveSubjects() {
        guard let context = modelContext else { return }
        do {
            var existingByName = subjectEntitiesByName
            if existingByName.isEmpty {
                let existing = try context.fetch(FetchDescriptor<SubjectRecord>())
                var cache: [String: SubjectRecord] = [:]
                for e in existing { cache[e.name] = e }
                existingByName = cache
                subjectEntitiesByName = cache
            }
            let newNames = Set(subjects.map(\.name))
            // 删除已不存在的
            for (name, entity) in existingByName where !newNames.contains(name) {
                context.delete(entity)
            }
            // 新增 / 更新
            for s in subjects {
                if let entity = existingByName[s.name] {
                    entity.enabled = s.enabled
                    entity.fullScore = s.fullScore
                    entity.displayName = s.displayName
                } else {
                    let newEntity = SubjectRecord(from: s)
                    context.insert(newEntity)
                    existingByName[s.name] = newEntity
                }
            }
            try context.save()
            // 同步缓存:删除已不存在的条目
            for name in existingByName.keys where !newNames.contains(name) {
                existingByName.removeValue(forKey: name)
            }
            subjectEntitiesByName = existingByName
            Log.data.debug("SubjectRepository saved subjects: count=\(self.subjects.count, privacy: .public)")
        } catch {
            Log.data.error("SubjectRepository saveSubjects failed: \(error.localizedDescription, privacy: .public)")
            return
        }
    }

    func initializeDefaultSubjects() {
        guard subjects.isEmpty else { return }
        guard let profile = profileRef?.profile else {
            Log.data.warning("SubjectRepository initializeDefaultSubjects: profileRef is nil")
            return
        }
        let stageRaw = profile.educationStage
        let stage = EducationStage(rawValue: stageRaw) ?? .highSchool
        let region = EducationConfig.region(named: profile.regionCode, stage: stage)
            ?? EducationConfig.defaultRegion(for: stage)
        subjects = region.subjects.map {
            Subject(name: $0.name, displayName: $0.displayName, enabled: $0.isRequired, fullScore: $0.fullScore)
        }
        Log.data.info("SubjectRepository initialized defaults: stage=\(stageRaw, privacy: .public) region=\(profile.regionCode, privacy: .public) count=\(self.subjects.count, privacy: .public)")
    }

    func applySmartSubjectRecommendation(stage: EducationStage, regionCode: String) {
        guard let region = EducationConfig.region(named: regionCode, stage: stage) else { return }
        var newSubjects: [Subject] = []
        for config in region.subjects {
            if let existing = subjects.first(where: { $0.name == config.name }) {
                var updated = existing
                updated.fullScore = config.fullScore
                updated.displayName = config.displayName
                newSubjects.append(updated)
            } else {
                newSubjects.append(Subject(
                    name: config.name,
                    displayName: config.displayName,
                    enabled: config.isRequired,
                    fullScore: config.fullScore
                ))
            }
        }
        subjects = newSubjects
        saveSubjects()
    }

    // MARK: - Query helpers
    // MARK: - 查询工具 / Query helpers

    /// 获取某科目的满分
    /// Get the full score for a subject.
    func fullScore(for subjectName: String) -> Double {
        if let subject = subjects.first(where: { $0.name == subjectName }) {
            return subject.fullScore
        }
        return 100
    }

    /// 获取某科目的本地化显示名
    /// Get the localized display name for a subject.
    func displayName(for subjectName: String) -> String {
        if let subject = subjects.first(where: { $0.name == subjectName }) {
            return subject.displayName.isEmpty ? subjectName : subject.displayName
        }
        return subjectName
    }
}
