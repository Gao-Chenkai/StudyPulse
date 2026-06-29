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
        UserProfileRecord.self,
    ]

    /// 创建或获取共享 ModelContainer。
    /// Create or fetch the shared ModelContainer.
    ///
    /// 多次调用是安全的（同一进程内只创建一次），但只应在 main actor 上调用。
    /// Multiple calls are safe (single instance per process), but only call from main actor.
    static func makeContainer() -> ModelContainer {
        if let cached = _sharedContainer { return cached }

        let schema = Schema(modelTypes)
        do {
            // 显式把 store URL 放到 Application Support/studypulse.store，
            // 而不是默认的 Documents/，避免被 iCloud Backup 备份（数据可能很大）。
            // Store in Application Support (excluded from iCloud backup) to avoid
            // backing up large local databases.
            let appSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let storeURL = appSupport.appendingPathComponent("studypulse.store")
            let config = ModelConfiguration(
                "StudyPulse",
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(for: schema, configurations: [config])
            _sharedContainer = container
            Log.data.info("ModelContainer 创建成功 / ModelContainer created: \(storeURL.path, privacy: .public)")
            return container
        } catch {
            // 创建失败（极少见，比如磁盘满）—— 退回内存容器
            // Fall back to in-memory container on failure (rare: disk full, etc.)
            Log.data.error("ModelContainer 创建失败 / ModelContainer creation failed: \(error.localizedDescription, privacy: .public). Falling back to in-memory store.")
            do {
                let inMemory = ModelConfiguration(isStoredInMemoryOnly: true)
                let container = try ModelContainer(for: schema, configurations: [inMemory])
                _sharedContainer = container
                return container
            } catch {
                // 极端情况：直接 crash 不合理，返回 last resort 配置
                fatalError("Cannot create any ModelContainer: \(error.localizedDescription)")
            }
        }
    }

    nonisolated(unsafe) private static var _sharedContainer: ModelContainer?

    // MARK: - Migration

    /// 是否已经完成 JSON → SwiftData 迁移
    /// Whether the JSON → SwiftData migration has finished.
    static let migrationDoneKey = "didMigrateToSwiftData_v1"

    /// 检查是否需要从 JSON 迁移
    /// Check if migration from JSON is needed.
    static var needsJSONMigration: Bool {
        !UserDefaults.standard.bool(forKey: migrationDoneKey)
    }

    /// 从旧版 ~/Documents/*.json 迁移到 SwiftData。
    /// Migrate legacy ~/Documents/*.json to SwiftData.
    ///
    /// 策略：
    /// - 读取每个 JSON 文件（profile / grades / mistakes / exams / comprehensiveExams / subjects）
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
        let docs = DataFileIO.getDocsDir()

        var counts: [(String, Int)] = []

        // subjects
        if let subjects: [Subject] = DataFileIO.load(url: docs.appendingPathComponent("subjects.json")) {
            for s in subjects {
                context.insert(SubjectRecord(from: s))
            }
            counts.append(("subjects", subjects.count))
        }

        // grades
        if let grades: [Grade] = DataFileIO.load(url: docs.appendingPathComponent("grades.json")) {
            for g in grades {
                context.insert(GradeRecord(from: g))
            }
            counts.append(("grades", grades.count))
        }

        // mistakes
        if let mistakes: [MistakeNote] = DataFileIO.load(url: docs.appendingPathComponent("mistakes.json")) {
            for m in mistakes {
                context.insert(MistakeNoteRecord(from: m))
            }
            counts.append(("mistakes", mistakes.count))
        }

        // exams (single subject)
        if let exams: [Exam] = DataFileIO.load(url: docs.appendingPathComponent("exams.json")) {
            for e in exams {
                context.insert(ExamRecord(from: e))
            }
            counts.append(("exams", exams.count))
        }

        // comprehensiveExams
        if let comps: [comprehensiveExam] = DataFileIO.load(url: docs.appendingPathComponent("comprehensiveExams.json")) {
            for e in comps {
                context.insert(ComprehensiveExamRecord(from: e))
            }
            counts.append(("comprehensiveExams", comps.count))
        }

        // profile (单例)
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
}
