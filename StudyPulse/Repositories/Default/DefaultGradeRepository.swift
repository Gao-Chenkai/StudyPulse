//
//  DefaultGradeRepository.swift
//  StudyPulse
//
//  成绩 (Grade) Repository 默认实现。
//  Default GradeRepository implementation backed by SwiftData.
//  纯 CRUD:无 widget sync / achievement 副作用(由 RepositoryContainer 编排)。
//

import Foundation
import SwiftData
import os

/// 成绩 (Grade) Repository 默认实现。
/// Default GradeRepository implementation backed by SwiftData.
/// 纯 CRUD:无 widget sync / achievement 副作用(由 RepositoryContainer 编排)。
/// Pure CRUD: no widget sync / achievement side effects (orchestrated by RepositoryContainer).
@Observable @MainActor
final class DefaultGradeRepository: GradeRepository {
    /// 全量成绩(按 date desc 排序)
    /// All grades, sorted by date desc.
    var grades: [Grade] = []
    /// 按 active phase 过滤后的成绩缓存
    /// Cached grades filtered by the active phase.
    var filteredGrades: [Grade] = []

    /// ModelContext:由 RepositoryContainer.setModelContainer 注入
    /// ModelContext: injected by RepositoryContainer.setModelContainer.
    @ObservationIgnored
    private var modelContext: ModelContext?

    /// 用于 background fetch 的容器引用(Sendable)
    /// Container reference for background fetches (Sendable).
    @ObservationIgnored
    private var modelContainer: ModelContainer?

    /// AppEnvironmentManager(由容器注入,用于读 activePhaseId)
    /// AppEnvironmentManager (injected by the container; used to read `activePhaseId`).
    @ObservationIgnored
    private let envManager: AppEnvironmentManager

    init(envManager: AppEnvironmentManager) {
        self.envManager = envManager
    }

    // MARK: - Lifecycle
    // MARK: - 生命周期 / Lifecycle

    /// 加载所有成绩
    /// Load all grades.
    func loadAll(context: ModelContext) async {
        self.modelContext = context
        self.modelContainer = context.container
        await reloadFromSwiftData()
    }

    func reloadFromSwiftData() async {
        guard let container = modelContainer else { return }
        // detached Task 内创建独立 background ModelContext,fetch + toSnapshot
        // @Model 不可跨 actor 边界 → 在 detached 内完成 toSnapshot,只返回 [Grade] Sendable 数组
        // Use an independent background ModelContext inside a detached task.
        // @Model entities can't cross actor boundaries → do toSnapshot inside
        // the detached task and return a Sendable [Grade] snapshot array.
        let snapshots: [Grade] = await Task.detached(priority: .utility) {
            let ctx = ModelContext(container)
            // fetchLimit=365:一年成绩足够趋势分析;按 date desc 保证拿到最新数据。
            // fetchLimit=365: a year of grades is enough for trend analysis; sort date desc
            // so the most recent data is retained when the cap is hit.
            var descriptor = FetchDescriptor<GradeRecord>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            descriptor.fetchLimit = 365
            let entities = (try? ctx.fetch(descriptor)) ?? []
            return entities.map { $0.toSnapshot() }
        }.value
        // 回到 MainActor 赋值(触发 @Observable 更新)
        self.grades = snapshots
        recomputeFiltered()
    }

    @discardableResult
    func migrateInlineImagesIfNeeded() -> Int {
        guard let context = modelContext else { return 0 }
        var migrated = 0
        for i in 0..<grades.count where grades[i].image != nil && grades[i].imageFileName == nil {
            let grade = grades[i]
            guard let imageData = grade.image else { continue }
            let filename = "grade_\(grade.id.uuidString).jpg"
            if ImageStorage.save(imageData, filename: filename) {
                grades[i].imageFileName = filename
                grades[i].image = nil
                if let entity = try? context.fetch(
                    FetchDescriptor<GradeRecord>(predicate: #Predicate { $0.id == grade.id })
                ).first {
                    entity.imageFileName = filename
                    entity.image = nil
                }
                migrated += 1
            }
        }
        if migrated > 0 {
            try? context.save()
            Log.data.info("DefaultGradeRepository migrated inline grade images: count=\(migrated, privacy: .public)")
        }
        return migrated
    }

    // MARK: - CRUD
    // MARK: - 增删改查 / CRUD

    /// 新增一条成绩
    /// Add a single grade.
    func add(_ grade: Grade) {
        var stored = grade
        if stored.phaseId == nil {
            stored.phaseId = envManager.activePhaseId
        }
        if let context = modelContext {
            context.insert(GradeRecord(from: stored))
            try? context.save()
        }
        grades.append(stored)
        Log.data.info("GradeRepository added: subject=\(stored.subject, privacy: .public) score=\(stored.score, privacy: .public) phaseId=\(stored.phaseId?.uuidString ?? "nil", privacy: .public)")
        Log.record(.info, category: "Data", message: "GradeRepository added: subject=\(stored.subject) score=\(stored.score) phaseId=\(stored.phaseId?.uuidString ?? "nil")")
        recomputeFiltered()
    }

    func add(_ newGrades: [Grade]) {
        let activeId = envManager.activePhaseId
        let stored: [Grade] = newGrades.map { g in
            var s = g
            if s.phaseId == nil { s.phaseId = activeId }
            return s
        }
        if let context = modelContext {
            for g in stored {
                context.insert(GradeRecord(from: g))
            }
            try? context.save()
        }
        grades.append(contentsOf: stored)
        let count = stored.count
        Log.data.info("GradeRepository batch added: count=\(count, privacy: .public)")
        Log.record(.info, category: "Data", message: "GradeRepository batch added: count=\(count)")
        recomputeFiltered()
    }

    func update(_ grade: Grade) {
        if let index = grades.firstIndex(where: { $0.id == grade.id }) {
            grades[index] = grade
        }
        guard let context = modelContext else { return }
        do {
            if let entity = try context.fetch(
                FetchDescriptor<GradeRecord>(predicate: #Predicate { $0.id == grade.id })
            ).first {
                entity.subject = grade.subject
                entity.score = grade.score
                entity.rawScore = grade.rawScore
                entity.ranking = grade.ranking
                entity.importance = grade.importance
                entity.image = grade.image
                entity.imageFileName = grade.imageFileName
                entity.date = grade.date
                entity.examName = grade.examName
                entity.examId = grade.examId
                entity.fullScore = grade.fullScore
                entity.phaseId = grade.phaseId
                try context.save()
            } else {
                context.insert(GradeRecord(from: grade))
                try context.save()
            }
        } catch {
            Log.data.error("GradeRepository update failed: \(error.localizedDescription, privacy: .public)")
        }
        recomputeFiltered()
    }

    func delete(_ grade: Grade) {
        if let imageFileName = grade.imageFileName {
            ImageStorage.delete(filename: imageFileName)
            Log.data.debug("GradeRepository removed grade image: \(imageFileName, privacy: .public)")
        }
        removeRecord(id: grade.id)
        grades.removeAll { $0.id == grade.id }
        Log.data.info("GradeRepository deleted: subject=\(grade.subject, privacy: .public)")
        Log.record(.info, category: "Data", message: "GradeRepository deleted: subject=\(grade.subject)")
        recomputeFiltered()
    }

    @discardableResult
    func clearAll() -> Int {
        guard let context = modelContext else { return 0 }
        let count = grades.count
        for g in grades {
            if let name = g.imageFileName {
                ImageStorage.delete(filename: name)
            }
        }
        do {
            let entities = try context.fetch(FetchDescriptor<GradeRecord>())
            for entity in entities { context.delete(entity) }
            try context.save()
        } catch {
            Log.data.error("GradeRepository clearAll failed: \(error.localizedDescription, privacy: .public)")
            return 0
        }
        grades.removeAll()
        Log.data.warning("GradeRepository clearAll: count=\(count, privacy: .public)")
        Log.record(.warning, category: "Data", message: "GradeRepository clearAll: count=\(count)")
        recomputeFiltered()
        return count
    }

    // MARK: - Internals
    // MARK: - 内部工具 / Internals

    /// 按 active phase 过滤(从外部 phase 切换时由容器调用,本类内部每次增删改后也会自动调)。
    /// Recompute filteredGrades from the active phase (also called internally after every CRUD).
    func recomputeFiltered() {
        let activeId = envManager.activePhaseId
        if let id = activeId {
            filteredGrades = grades.filter { $0.phaseId == id }
        } else {
            filteredGrades = grades
        }
    }

    private func removeRecord(id: UUID) {
        guard let context = modelContext else { return }
        do {
            if let entity = try context.fetch(
                FetchDescriptor<GradeRecord>(predicate: #Predicate { $0.id == id })
            ).first {
                context.delete(entity)
                try context.save()
            }
        } catch {
            Log.data.error("GradeRepository removeRecord failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
