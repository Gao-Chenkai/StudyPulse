//
//  ModelContainerFactory.swift
//  StudyPulse
//
//  SwiftData ModelContainer 单例工厂。
//  SwiftData ModelContainer factory singleton.
//
//  - 提供一个共享 ModelContainer（在 StudyPulseApp 启动时初始化）
//  - 提供 Migration 工具：从旧版 ~/Documents/*.json 读取并写入 SwiftData
//  - 通过 UserDefaults flag 记录迁移状态，避免重复执行
//

import Foundation
import SwiftData
import os

/// SwiftData 容器配置 + 自动迁移工具
/// SwiftData container configuration + auto-migration helper.
@MainActor
enum ModelContainerFactory {

    /// SwiftData 容器要包含的 @Model 实体
    /// @Model types included in the SwiftData container.
    static let modelTypes: [any PersistentModel.Type] = [
        SubjectRecord.self,
        GradeRecord.self,
        MistakeNoteRecord.self,
        ExamRecord.self,
        ComprehensiveExamRecord.self,
        TaskItemRecord.self,
        UserProfileRecord.self,
        StudyPhaseRecord.self,
        PlantStateRecord.self,
        RoutineRecord.self,
        RoutineInstanceRecord.self,
    ]

    /// 创建或获取共享 ModelContainer。
    /// Create or fetch the shared ModelContainer.
    ///
    /// 多次调用是安全的（同一进程内只创建一次），但只应在 main actor 上调用。
    /// Multiple calls are safe (single instance per process), but only call from main actor.
    ///
    /// 启动时若 store 加载失败（一般是 schema 不兼容的旧 store），会重命名旧的
    /// store 文件（保留为 .bak 备份）后重新创建，避免 "invalid reuse after
    /// initialization failure"。失败 3 次则退回纯内存容器。
    /// On startup, if the store fails to load (typically a schema mismatch from
    /// a previous build), the old store is renamed to a `.bak` backup and a
    /// fresh one is created. This avoids the sticky "invalid reuse after
    /// initialization failure" error. Falls back to in-memory after 3 failed
    /// attempts.
    static func makeContainer() -> ModelContainer {
        if let cached = _sharedContainer { return cached }

        let schema = Schema(modelTypes)
        let appSupport: URL
        do {
            appSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        } catch {
            Log.data.error("ModelContainer 创建失败（无法定位 Application Support）/ Cannot locate Application Support: \(error.localizedDescription, privacy: .public)")
            return makeInMemoryContainer(schema: schema)
        }
        let storeURL = appSupport.appendingPathComponent("studypulse.store")

        for attempt in 1...3 {
            do {
                let config = ModelConfiguration(
                    "StudyPulse",
                    schema: schema,
                    url: storeURL,
                    cloudKitDatabase: .none
                )
                let container = try ModelContainer(for: schema, configurations: [config])
                if attempt > 1 {
                    Log.data.warning("ModelContainer 第 \(attempt) 次尝试才成功 / ModelContainer succeeded on attempt \(attempt)")
                } else {
                    Log.data.info("ModelContainer 创建成功 / ModelContainer created: \(storeURL.path, privacy: .public)")
                }
                _sharedContainer = container
                return container
            } catch {
                Log.data.error("ModelContainer 创建失败（attempt \(attempt)）/ ModelContainer attempt \(attempt) failed: \(error.localizedDescription, privacy: .public)")
                // 关键:Core Data 会在 coordinator 内部把失败的 URL 标记为"已失败",
                // 后续用相同 URL 仍会抛 "invalid reuse after initialization failure"。
                // 解法:把旧文件改名,让新 store 用原 URL 重新创建(旧数据保留为 .bak)。
                // Core Data marks a failed URL as "do not retry" at the coordinator
                // level. Move the old files aside so the new store gets a fresh URL
                // history. Old data is kept as a .bak sidecar.
                quarantineStaleStore(at: storeURL, attempt: attempt)
                // 给 OS / Core Data 一点时间释放文件锁 / Brief pause to release file locks
                Thread.sleep(forTimeInterval: 0.1)
            }
        }

        Log.data.error("ModelContainer 3 次重试均失败 / All 3 attempts failed; falling back to in-memory")
        return makeInMemoryContainer(schema: schema)
    }

    /// 退回纯内存容器（最后兜底）。
    /// Last-resort in-memory container.
    private static func makeInMemoryContainer(schema: Schema) -> ModelContainer {
        do {
            let inMemory = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: schema, configurations: [inMemory])
            _sharedContainer = container
            return container
        } catch {
            // 极端情况：直接 crash
            fatalError("Cannot create any ModelContainer: \(error.localizedDescription)")
        }
    }

    /// 把所有以 baseName 开头的 store 相关文件改名到 .bak(覆盖旧 .bak)。
    /// 改名而不是删除,便于万一需要手动恢复。
    /// Move all sidecar files matching `baseName*` to `.bak` (overwriting any
    /// previous .bak). Renaming instead of deleting preserves data for manual
    /// recovery if needed.
    @discardableResult
    private static func quarantineStaleStore(at storeURL: URL, attempt: Int) -> Bool {
        let fm = FileManager.default
        let storeDir = storeURL.deletingLastPathComponent()
        let baseName = storeURL.lastPathComponent  // e.g. "studypulse.store"

        guard let contents = try? fm.contentsOfDirectory(
            at: storeDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            Log.data.error("无法枚举 store 目录 / Cannot list store dir: \(storeDir.path, privacy: .public)")
            return false
        }

        var moved = 0
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let suffix = ".bak-\(stamp)-a\(attempt)"

        for url in contents {
            let name = url.lastPathComponent
            // 匹配 studypulse.store / studypulse.store-shm / studypulse.store-wal /
            // studypulse.store.bak-* / 以及任何 SwiftData 元数据(suffix 可能在中间)
            guard name == baseName || name.hasPrefix(baseName + ".") || name.hasPrefix(baseName + "-") else {
                continue
            }
            let backupURL = url.deletingLastPathComponent()
                .appendingPathComponent(name + suffix)
            // 如果同名的 .bak 已存在,先删掉
            if fm.fileExists(atPath: backupURL.path) {
                try? fm.removeItem(at: backupURL)
            }
            do {
                try fm.moveItem(at: url, to: backupURL)
                moved += 1
                Log.data.debug("已隔离旧 store 文件 / Quarantined stale store: \(name, privacy: .public) -> \(backupURL.lastPathComponent, privacy: .public)")
            } catch {
                Log.data.error("隔离 store 文件失败 / Failed to quarantine \(name, privacy: .public): \(error.localizedDescription, privacy: .public)")
                // 如果改名失败(可能是只读 / 锁定),就尝试硬删一次
                do {
                    try fm.removeItem(at: url)
                    moved += 1
                } catch {
                    Log.data.error("硬删也失败 / Hard delete also failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        }

        Log.data.info("store 隔离完成 / Store quarantine done: moved=\(moved, privacy: .public)")
        return moved > 0
    }

    nonisolated(unsafe) private static var _sharedContainer: ModelContainer?

    // MARK: - Debug Helpers
    // MARK: - 调试辅助 / Debug helpers

    /// 返回各 @Model 实体的当前记录数（供 Debug → State & Cache 展示）
    /// Record count per registered @Model type, used by Debug → State & Cache.
    @MainActor
    static func entityCounts(context: ModelContext) -> [(name: String, count: Int)] {
        var results: [(name: String, count: Int)] = []
        for type in modelTypes {
            let count: Int
            do {
                count = try entityCount(for: type, in: context)
            } catch {
                Log.data.error("entityCounts 取数失败 / fetchCount failed for \(String(describing: type), privacy: .public): \(error.localizedDescription, privacy: .public)")
                count = -1
            }
            results.append((String(describing: type), count))
        }
        return results
    }

    /// 通用实体计数（通过类型分发到具体 PersistentModel 子类）
    /// Type-erased entity count dispatcher.
    private static func entityCount(for type: any PersistentModel.Type, in context: ModelContext) throws -> Int {
        switch type {
        case is SubjectRecord.Type:
            return try context.fetchCount(FetchDescriptor<SubjectRecord>())
        case is GradeRecord.Type:
            return try context.fetchCount(FetchDescriptor<GradeRecord>())
        case is MistakeNoteRecord.Type:
            return try context.fetchCount(FetchDescriptor<MistakeNoteRecord>())
        case is ExamRecord.Type:
            return try context.fetchCount(FetchDescriptor<ExamRecord>())
        case is ComprehensiveExamRecord.Type:
            return try context.fetchCount(FetchDescriptor<ComprehensiveExamRecord>())
        case is TaskItemRecord.Type:
            return try context.fetchCount(FetchDescriptor<TaskItemRecord>())
        case is UserProfileRecord.Type:
            return try context.fetchCount(FetchDescriptor<UserProfileRecord>())
        case is StudyPhaseRecord.Type:
            return try context.fetchCount(FetchDescriptor<StudyPhaseRecord>())
        case is PlantStateRecord.Type:
            return try context.fetchCount(FetchDescriptor<PlantStateRecord>())
        case is RoutineRecord.Type:
            return try context.fetchCount(FetchDescriptor<RoutineRecord>())
        case is RoutineInstanceRecord.Type:
            return try context.fetchCount(FetchDescriptor<RoutineInstanceRecord>())
        default:
            // 兜底：返回 -1 提示未实现
            return -1
        }
    }

    // MARK: - Migration
    // MARK: - 数据迁移 / Migration

    /// 是否已经完成 JSON → SwiftData 迁移
    /// Whether the JSON → SwiftData migration has finished.
    static let migrationDoneKey = "didMigrateToSwiftData_v1"

    /// 是否已经为首次启动准备好 PlantStateRecord
    /// Whether an initial PlantStateRecord has been seeded.
    static let plantSeedDoneKey = "didSeedPlantState_v1"

    /// 检查是否需要从 JSON 迁移
    /// Check if migration from JSON is needed.
    static var needsJSONMigration: Bool {
        !UserDefaults.standard.bool(forKey: migrationDoneKey)
    }

    /// 从旧版 ~/Documents/*.json 迁移到 SwiftData。
    /// Migrate legacy ~/Documents/*.json to SwiftData.
    ///
    /// 策略：
    /// - 读取每个 JSON 文件（profile / grades / mistakes / exams / comprehensiveExams / tasks / subjects）
    /// - 全部插入到给定 ModelContext
    /// - 标记迁移完成（写 UserDefaults）
    /// - 旧 JSON 文件保留在原位（不删），避免误操作导致数据丢失
    ///
    /// Strategy:
    /// - Read each JSON file and decode into existing structs
    /// - Insert all as @Model entities
    /// - Mark migration as done (UserDefaults)
    /// - Old JSON files are kept (not deleted) to prevent accidental data loss
    @MainActor
    static func migrateFromJSONIfNeeded(context: ModelContext) {
        guard needsJSONMigration else { return }

        Log.data.info("开始 JSON → SwiftData 迁移 / Starting JSON → SwiftData migration")
        guard let docs = DataFileIO.getDocsDir() else {
            Log.data.error("JSON 迁移跳过(无法解析 Documents 目录) / Migration skipped: no Documents dir")
            return
        }

        var counts: [(String, Int)] = []

        // subjects / 学科
        if let subjects: [Subject] = DataFileIO.load(url: docs.appendingPathComponent("subjects.json")) {
            for s in subjects {
                context.insert(SubjectRecord(from: s))
            }
            counts.append(("subjects", subjects.count))
        }

        // grades / 成绩
        if let grades: [Grade] = DataFileIO.load(url: docs.appendingPathComponent("grades.json")) {
            for g in grades {
                context.insert(GradeRecord(from: g))
            }
            counts.append(("grades", grades.count))
        }

        // mistakes / 错题
        if let mistakes: [MistakeNote] = DataFileIO.load(url: docs.appendingPathComponent("mistakes.json")) {
            for m in mistakes {
                context.insert(MistakeNoteRecord(from: m))
            }
            counts.append(("mistakes", mistakes.count))
        }

        // exams (single subject) / 考试 (单科)
        if let exams: [Exam] = DataFileIO.load(url: docs.appendingPathComponent("exams.json")) {
            for e in exams {
                context.insert(ExamRecord(from: e))
            }
            counts.append(("exams", exams.count))
        }

        // comprehensiveExams / 综合考试
        if let comps: [comprehensiveExam] = DataFileIO.load(url: docs.appendingPathComponent("comprehensiveExams.json")) {
            for e in comps {
                context.insert(ComprehensiveExamRecord(from: e))
            }
            counts.append(("comprehensiveExams", comps.count))
        }

        // tasks (homework / reading material) / 任务 (作业 / 阅读材料)
        if let tasks: [TaskItem] = DataFileIO.load(url: docs.appendingPathComponent("tasks.json")) {
            for t in tasks {
                context.insert(TaskItemRecord(from: t))
            }
            counts.append(("tasks", tasks.count))
        }

        // profile (单例) / profile (singleton)
        if let profile: UserProfile = DataFileIO.load(url: docs.appendingPathComponent("profile.json")) {
            context.insert(UserProfileRecord(from: profile))
            counts.append(("profile", 1))
        }

        do {
            try context.save()
            UserDefaults.standard.set(true, forKey: migrationDoneKey)
            let summary = counts.map { "\($0.0)=\($0.1)" }.joined(separator: ", ")
            Log.data.info("JSON → SwiftData 迁移完成 / Migration complete: \(summary, privacy: .public)")
            Log.record(.info, category: "Data", message: "JSON → SwiftData 迁移完成: \(summary)")
        } catch {
            Log.data.error("保存迁移数据失败 / Migration save failed: \(error.localizedDescription, privacy: .public)")
            Log.record(.error, category: "Data", message: "保存迁移数据失败: \(error.localizedDescription)")
        }
    }

    // MARK: - Plant Seed
    // MARK: - Plant 播种 / Plant seed

    /// 首次启动时插入一条 seed PlantStateRecord。
    /// Idempotent: 通过 `plantSeedDoneKey` 跳过；已经存在 record 也跳过。
    /// Seed an initial PlantStateRecord on first launch. Idempotent.
    @MainActor
    static func migratePlantStateIfNeeded(context: ModelContext) {
        // 已经播种过就跳过
        // Already seeded → skip.
        if UserDefaults.standard.bool(forKey: plantSeedDoneKey) { return }

        // 已经存在 record 也跳过（覆盖安装或老 build 升级上来）
        // If a record already exists, skip too (re-install / upgrade from an older build).
        let descriptor = FetchDescriptor<PlantStateRecord>()
        if let existing = try? context.fetch(descriptor), !existing.isEmpty {
            UserDefaults.standard.set(true, forKey: plantSeedDoneKey)
            return
        }

        let initial = PlantState(currentStage: .seed, lastUpdated: Date())
        let record = PlantStateRecord(from: initial, previousStage: .seed)
        context.insert(record)
        do {
            try context.save()
            UserDefaults.standard.set(true, forKey: plantSeedDoneKey)
            Log.data.info("PlantState 首次播种完成 / Plant state seed complete: stage=seed")
        } catch {
            Log.data.error("PlantState 播种失败 / Plant state seed failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
