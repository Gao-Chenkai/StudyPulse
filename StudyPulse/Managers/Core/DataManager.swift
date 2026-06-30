//
//  DataManager.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//
//  iOS 18+ SwiftData 迁移说明：
//  - 持久化层从 ~/Documents/*.json 改为 SwiftData（ModelContainer in Application Support）
//  - @Published 数组继续暴露 value-type 快照，视图层 API 不变
//  - 首次启动时自动把旧 JSON 文件导入 SwiftData（通过 ModelContainerFactory.migrateFromJSONIfNeeded）
//  - 旧 JSON 文件保留在原位作为冗余备份
//

import Foundation
import Combine
import SwiftUI
import SwiftData
import os

// MARK: - File I/O Utilities

/// 线程安全的文件读写工具，避免受 @MainActor 限制
/// 用于后台线程加载和保存 JSON 数据
nonisolated enum DataFileIO {
    /// 获取 Documents 目录
    static func getDocsDir() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    /// 获取 images 子目录（不存在则自动创建，结果按路径缓存以避免重复 stat）
    private static let imagesDirLock = NSLock()
    nonisolated(unsafe) private static var _cachedImagesDir: URL?
    static func getImagesDir() -> URL {
        imagesDirLock.lock()
        defer { imagesDirLock.unlock() }
        if let cached = _cachedImagesDir { return cached }
        let url = getDocsDir().appendingPathComponent("images")
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        _cachedImagesDir = url
        return url
    }

    /// 从指定 URL 加载并解码 JSON 数据
    /// Load and decode JSON data from the given URL
    static func load<T: Codable>(url: URL, decoder: JSONDecoder = JSONDecoder()) -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            Log.data.debug("文件不存在，跳过加载 / File missing, skipping load: \(url.lastPathComponent, privacy: .public)")
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            let result = try decoder.decode(T.self, from: data)
            Log.data.debug("加载成功 / Loaded: \(url.lastPathComponent, privacy: .public), bytes=\(data.count, privacy: .public)")
            return result
        } catch {
            Log.data.error("加载失败 / Load failed: \(url.lastPathComponent, privacy: .public), error=\(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}

// MARK: - Data Manager

/// 应用中央状态管理器
/// 所有视图通过 @EnvironmentObject 访问此管理器进行数据读写
/// iOS 18+ 数据存于 SwiftData（ModelContainerFactory.makeContainer()），
/// 旧 JSON 文件在首次启动时自动迁移到 SwiftData
@MainActor
final class DataManager: ObservableObject {
    static let shared = DataManager()

    // MARK: - 已发布数据（value-type 快照，视图层继续用）
    
    /// 成绩记录列表
    @Published var grades: [Grade] = []
    /// 科目列表
    @Published var subjects: [Subject] = []
    /// 错题笔记列表
    @Published var mistakeSets: [MistakeNote] = []
    /// 单科目考试列表
    @Published var examSets: [Exam] = []
    /// 用户资料
    @Published var profile: UserProfile = UserProfile()
   /// 多科目综合考试列表
   @Published var comprehensiveExamSets: [comprehensiveExam] = []
    /// 作业 / 阅读材料任务列表（与考试日程统一展示在「待办」页）
    @Published var taskItems: [TaskItem] = []

    /// Set by open-app App Intents to trigger pre-filled sheets in ContentView.
    @Published var pendingIntentAction: IntentAction? = nil

   /// 异步加载完成后置为 true。视图与 widget 同步可据此判断数据是否就绪。
    @Published private(set) var isReady: Bool = false

    // MARK: - SwiftData

    /// SwiftData 容器（首次调用 asyncInit 时懒初始化）
    nonisolated(unsafe) private static var _container: ModelContainer?
    nonisolated(unsafe) private static var _containerInitFailed: Bool = false

    /// 全局共享 ModelContainer（StudyPulseApp 启动时通过 .modelContainer 注入）
    /// Global shared ModelContainer (injected by StudyPulseApp via .modelContainer)
    nonisolated(unsafe) static var sharedModelContainer: ModelContainer?

    /// 把 @Environment(\.modelContext) 注入的 ModelContainer 设置为共享容器
    /// Set the ModelContainer injected via .modelContainer as the shared one.
    @MainActor
    func setModelContainer(_ container: ModelContainer) {
        Self._container = container
    }

    private var modelContainer: ModelContainer? { Self._container ?? Self.sharedModelContainer }
    private var modelContext: ModelContext? { modelContainer?.mainContext }

    private static func ensureContainer() -> ModelContainer? {
        if let c = _container { return c }
        if _containerInitFailed { return nil }
        do {
            let c = ModelContainerFactory.makeContainer()
            _container = c
            return c
        } catch {
            _containerInitFailed = true
            return nil
        }
    }

    init() {
        // 故意不在这里读取任何磁盘 I/O；
        // 启动时由 asyncInit() 在后台 Task 中并行加载，避免阻塞主线程。
    }

    // MARK: - 异步初始化

    /// 异步初始化：初始化 SwiftData、迁移旧 JSON、加载所有数据。
    /// 用 `await dataManager.asyncInit()` 在 .task 中等待完成。
    ///
    /// Async init: initialize SwiftData container, migrate legacy JSON
    /// files (one-time), and load all data from SwiftData.
    /// Await with `await dataManager.asyncInit()` inside a `.task` modifier.
    func asyncInit() async {
        Log.data.info("asyncInit 开始 / asyncInit start")
        Log.record(.info, category: "Data", message: "asyncInit 开始 / asyncInit start")

        // 1. 初始化 SwiftData 容器
        // 1. Initialize the SwiftData container
        guard let container = Self.ensureContainer() else {
            Log.data.error("无法创建 ModelContainer / Cannot create ModelContainer. asyncInit aborted.")
            isReady = false
            return
        }
        let context = container.mainContext

        // 2. 一次性从旧 JSON 迁移到 SwiftData（UserDefaults 标记保证只跑一次）
        // 2. One-time JSON → SwiftData migration (UserDefaults flag prevents repeats)
        ModelContainerFactory.migrateFromJSONIfNeeded(context: context)

        // 3. 加载 SwiftData 数据到 @Published 数组
        // 3. Load SwiftData into @Published arrays
        loadAllFromSwiftData(context: context)

        // 4. 迁移内嵌图片（如果还有老的 grades.json 残留，从那里迁移）
        // 4. Migrate any inline image data (legacy path)
        let migratedImageCount = migrateInlineGradeImagesIfNeeded()
        if migratedImageCount > 0 {
            // 重新加载 grades（因为部分 grade 的 imageFileName 已更新）
            // Reload grades since some imageFileName fields were updated
            await reloadGradesFromSwiftData()
        }

        isReady = true

        Log.data.info("asyncInit 完成 / asyncInit done; grades=\(self.grades.count, privacy: .public) mistakes=\(self.mistakeSets.count, privacy: .public) exams=\(self.examSets.count, privacy: .public) compExams=\(self.comprehensiveExamSets.count, privacy: .public) tasks=\(self.taskItems.count, privacy: .public) subjects=\(self.subjects.count, privacy: .public)")
        Log.record(.info, category: "Data", message: "asyncInit 完成 / asyncInit done; grades=\(self.grades.count) mistakes=\(self.mistakeSets.count) exams=\(self.examSets.count) compExams=\(self.comprehensiveExamSets.count) tasks=\(self.taskItems.count) subjects=\(self.subjects.count)")

        // 启动时同步 SRS 复习通知
        SRSReviewNotifications.shared.rescheduleAll(mistakes: self.mistakeSets)

        // 启动时同步考试与趋势数据到 Widget
        WidgetDataSyncManager.syncUpcomingExams(
            examSets: self.examSets,
            comprehensiveExamSets: self.comprehensiveExamSets
        )
        TrendWidgetSyncManager.syncTrend(grades: self.grades, subjects: self.subjects)
    }

    /// 从 SwiftData 一次性加载所有数据到 @Published 数组
    private func loadAllFromSwiftData(context: ModelContext) {
        do {
            // Subjects
            let subjectEntities = try context.fetch(FetchDescriptor<SubjectRecord>())
            self.subjects = subjectEntities.map { $0.toSnapshot() }

            // Grades
            let gradeEntities = try context.fetch(
                FetchDescriptor<GradeRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)])
            )
            self.grades = gradeEntities.map { $0.toSnapshot() }

            // MistakeNotes
            let mistakeEntities = try context.fetch(
                FetchDescriptor<MistakeNoteRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)])
            )
            self.mistakeSets = mistakeEntities.map { $0.toSnapshot() }

            // Exams (single subject)
            let examEntities = try context.fetch(
                FetchDescriptor<ExamRecord>(sortBy: [SortDescriptor(\.examDate, order: .forward)])
            )
            self.examSets = examEntities.map { $0.toSnapshot() }

            // Comprehensive exams
            let compEntities = try context.fetch(
                FetchDescriptor<ComprehensiveExamRecord>(sortBy: [SortDescriptor(\.examDate, order: .forward)])
            )
            self.comprehensiveExamSets = compEntities.map { $0.toSnapshot() }

            // TaskItems (homework / reading material)
            let taskEntities = try context.fetch(
                FetchDescriptor<TaskItemRecord>(sortBy: [SortDescriptor(\.dueDate, order: .forward)])
            )
            self.taskItems = taskEntities.map { $0.toSnapshot() }

            // Profile (singleton)
            let profiles = try context.fetch(FetchDescriptor<UserProfileRecord>())
            if let entity = profiles.first {
                self.profile = entity.toSnapshot()
            }

            Log.data.debug("SwiftData 加载完成 / SwiftData load complete")
        } catch {
            Log.data.error("SwiftData 加载失败 / SwiftData load failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 仅从 SwiftData 重读 grades（用于 imageFileName 更新后刷新）
    private func reloadGradesFromSwiftData() async {
        guard let context = modelContext else { return }
        await Task { @MainActor in
            do {
                let gradeEntities = try context.fetch(
                    FetchDescriptor<GradeRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)])
                )
                self.grades = gradeEntities.map { $0.toSnapshot() }
            } catch {
                Log.data.error("重读 grades 失败 / Failed to reload grades: \(error.localizedDescription, privacy: .public)")
            }
        }.value
    }

    /// 迁移 grades 里的内嵌图片到文件系统（如果还有就写盘，并更新 SwiftData 中的 imageFileName）
    /// Migrate inline grade images to the file system, if any, and update imageFileName in SwiftData.
    private func migrateInlineGradeImagesIfNeeded() -> Int {
        guard let context = modelContext else { return 0 }
        let imagesDir = DataFileIO.getImagesDir()
        var migrated = 0

        for i in 0..<grades.count where grades[i].image != nil && grades[i].imageFileName == nil {
            let grade = grades[i]
            guard let imageData = grade.image else { continue }
            let filename = "grade_\(grade.id.uuidString).jpg"
            let url = imagesDir.appendingPathComponent(filename)
            do {
                try imageData.write(to: url)
                grades[i].imageFileName = filename
                grades[i].image = nil
                // 同步更新 @Model
                if let entity = try? context.fetch(
                    FetchDescriptor<GradeRecord>(predicate: #Predicate { $0.id == grade.id })
                ).first {
                    entity.imageFileName = filename
                    entity.image = nil
                }
                migrated += 1
            } catch {
                Log.data.error("迁移内嵌图片失败 / Inline image migration failed: grade=\(grade.id.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
        if migrated > 0 {
            try? context.save()
            Log.data.info("迁移内嵌图片完成 / Migrated inline grade images: count=\(migrated, privacy: .public)")
        }
        return migrated
    }

    private func initializeDefaultSubjects() {
        if subjects.isEmpty {
            // 根据用户当前设置的教育阶段和地区初始化默认科目
            let stageRaw = profile.educationStage
            let stage = EducationStage(rawValue: stageRaw) ?? .highSchool
            let region = EducationConfig.region(named: profile.regionCode, stage: stage)
                ?? EducationConfig.defaultRegion(for: stage)

            subjects = region.subjects.map {
                Subject(name: $0.name, displayName: $0.displayName, enabled: $0.isRequired, fullScore: $0.fullScore)
            }
            Log.data.info("已初始化默认科目 / Initialized default subjects: stage=\(stageRaw, privacy: .public) region=\(self.profile.regionCode, privacy: .public) count=\(self.subjects.count, privacy: .public)")
        }
    }
    
    // MARK: - Image Management

    /// 获取 Documents 目录
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    /// 获取图片存储目录
    private func getImagesDirectory() -> URL {
        let url = getDocumentsDirectory().appendingPathComponent("images")
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    /// 保存 Grade 图片到文件系统，返回相对路径
    /// Save grade image to the file system, return the file name
    func saveGradeImage(_ data: Data, gradeId: UUID) -> String? {
        let filename = "grade_\(gradeId.uuidString).jpg"
        let url = getImagesDirectory().appendingPathComponent(filename)
        do {
            try data.write(to: url)
            Log.data.debug("保存成绩图片成功 / Saved grade image: grade=\(gradeId.uuidString, privacy: .public) bytes=\(data.count, privacy: .public)")
            return filename
        } catch {
            Log.data.error("保存成绩图片失败 / Error saving grade image: grade=\(gradeId.uuidString, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// 从文件系统加载 Grade 图片
    func loadGradeImage(filename: String) -> Data? {
        let url = getImagesDirectory().appendingPathComponent(filename)
        return try? Data(contentsOf: url)
    }

    /// 异步加载 Grade 图片（在后台线程读取，避免阻塞 UI）
    func loadGradeImageAsync(filename: String) async -> Data? {
        let url = getImagesDirectory().appendingPathComponent(filename)
        return await Task.detached(priority: .userInitiated) {
            try? Data(contentsOf: url)
        }.value
    }

    /// 删除 Grade 图片文件
    func deleteGradeImage(filename: String) {
        let url = getImagesDirectory().appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }

    /// 保存用户头像到文件系统，返回文件名
    /// Save user avatar to the file system, return the file name
    func saveAvatar(_ data: Data) -> String? {
        let filename = "avatar_\(UUID().uuidString).jpg"
        let url = getImagesDirectory().appendingPathComponent(filename)
        do {
            try data.write(to: url)
            // 如果之前有头像，删除旧文件 / Delete previous avatar file if any
            if let oldFilename = profile.avatarFileName, oldFilename != filename {
                deleteAvatar(filename: oldFilename)
            }
            Log.data.info("保存头像成功 / Saved avatar: \(filename, privacy: .public) bytes=\(data.count, privacy: .public)")
            return filename
        } catch {
            Log.data.error("保存头像失败 / Error saving avatar: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// 从文件系统加载用户头像
    func loadAvatar() -> Data? {
        guard let filename = profile.avatarFileName else { return nil }
        let url = getImagesDirectory().appendingPathComponent(filename)
        return try? Data(contentsOf: url)
    }

    /// 异步加载用户头像（在后台线程读取，避免阻塞 UI）
    func loadAvatarAsync() async -> Data? {
        guard let filename = profile.avatarFileName else { return nil }
        let url = getImagesDirectory().appendingPathComponent(filename)
        return await Task.detached(priority: .userInitiated) {
            try? Data(contentsOf: url)
        }.value
    }

    /// 删除用户头像文件
    func deleteAvatar(filename: String) {
        let url = getImagesDirectory().appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }
    
    // MARK: - 科目管理
    
    /// 根据科目名称获取满分
    func fullScore(for subjectName: String) -> Double {
        if let subject = subjects.first(where: { $0.name == subjectName }) {
            return subject.fullScore
        }
        return 100
    }
    
    /// 根据科目名称获取显示名
    func displayName(for subjectName: String) -> String {
        if let subject = subjects.first(where: { $0.name == subjectName }) {
            return subject.displayName.isEmpty ? subject.name : subject.displayName
        }
        return subjectName
    }
    
    /// 根据教育阶段和地区智能推荐科目
    func applySmartSubjectRecommendation(stage: EducationStage, regionCode: String) {
        guard let region = EducationConfig.region(named: regionCode, stage: stage) else { return }
        
        // 保留已存在的科目设置，只更新科目列表
        var newSubjects: [Subject] = []
        for config in region.subjects {
            if let existing = subjects.first(where: { $0.name == config.name }) {
                // 已存在：保留 enabled 状态，更新满分和显示名
                var updated = existing
                updated.fullScore = config.fullScore
                updated.displayName = config.displayName
                newSubjects.append(updated)
            } else {
                // 不存在：添加为推荐勾选状态
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
    
    func saveProfile() {
        persistProfile()
    }

    /// 首次启动 OnBoarding 完成时一次性提交用户资料 + 选科。
    /// - Parameters:
    ///   - draft: 草稿（与 UserProfile 字段一一对应，但所有字段都可选）
    ///   - selectedSubjectNames: 用户在填写阶段勾选的科目名（与 SubjectConfig.name 对应）
    /// 调用方应保证 DataManager.isReady == true 或自行处理失败。
    /// 如果 dataManager.profile 已有真实姓名 / 头像，则不会覆盖（保留原值以兼容回退场景）。
    func commitOnboardingProfile(draft: OnboardingProfileDraft, selectedSubjectNames: [String]) {
        let stage = EducationStage(rawValue: draft.educationStage) ?? .highSchool
        let region = EducationConfig.region(named: draft.regionCode, stage: stage)
            ?? EducationConfig.defaultRegion(for: stage)

        // 同步基础字段
        profile.username = draft.username
        profile.realName = draft.realName
        profile.age = max(draft.age, 0)
        profile.gender = draft.gender
        profile.educationStage = draft.educationStage
        profile.educationLevel = draft.educationStage
        profile.educationSystem = region.displayName
        profile.regionCode = draft.regionCode
        profile.region = region.displayName
        profile.schoolName = draft.schoolName
        profile.grade = draft.grade
        profile.className = draft.className
        profile.studentId = draft.studentId
        profile.enrollmentYear = draft.enrollmentYear
        profile.examYear = draft.examYear
        profile.targetSchool = draft.targetSchool
        profile.targetScore = draft.targetScore

        // 同步选科：把选中的 name 列表映射为 Subject 列表
        let configByName = Dictionary(uniqueKeysWithValues: (region.subjects).map { ($0.name, $0) })
        let newSubjects: [Subject] = selectedSubjectNames.compactMap { name in
            if let cfg = configByName[name] {
                return Subject(
                    name: cfg.name,
                    displayName: cfg.displayName,
                    enabled: true,
                    fullScore: cfg.fullScore
                )
            }
            // 兜底：选中的 name 在当前 region 不存在（理论上不应发生）
            return Subject(name: name, displayName: name, enabled: true, fullScore: 100)
        }
        if !newSubjects.isEmpty {
            subjects = newSubjects
            saveSubjects()
        } else {
            // 草稿没勾选任何科目，回退到 region 推荐
            applySmartSubjectRecommendation(stage: stage, regionCode: region.name)
        }

        // 写入 SwiftData
        saveProfile()
        Log.data.info("Onboarding 资料提交完成 / Onboarding profile committed: username=\(draft.username, privacy: .public) subjects=\(selectedSubjectNames.count, privacy: .public)")
        Log.record(.info, category: "Data", message: "Onboarding 资料提交完成 / Onboarding profile committed: username=\(draft.username) subjects=\(selectedSubjectNames.count)")
    }

    func loadProfile() {
        // 由 asyncInit 统一加载；这里保留仅为向后兼容
        // No-op: asyncInit handles all loads. Kept for back-compat.
    }

    /// 异步加载 profile
    /// Asynchronously load profile
    func loadProfileAsync() async {
        // 由 asyncInit 统一加载；这里保留仅为向后兼容
    }

    /// 将当前 profile 同步到 SwiftData（更新或插入单例）
    /// Sync current profile to SwiftData (insert or update singleton).
    private func persistProfile() {
        guard let context = modelContext else { return }
        do {
            let existing = try context.fetch(FetchDescriptor<UserProfileRecord>())
            if let entity = existing.first {
                // 把 struct 字段同步到 @Model（UserProfile 是单例，id 沿用 @Model）
                // Sync struct fields to @Model. UserProfile is a singleton — id is owned by @Model.
                entity.username = profile.username
                entity.age = profile.age
                entity.educationLevel = profile.educationLevel
                entity.educationSystem = profile.educationSystem
                entity.region = profile.region
                entity.selectedSubjectsData = try? JSONEncoder().encode(profile.selectedSubjects)
                entity.theme = profile.theme
                entity.avatarFileName = profile.avatarFileName
                entity.realName = profile.realName
                entity.grade = profile.grade
                entity.className = profile.className
                entity.schoolName = profile.schoolName
                entity.studentId = profile.studentId
                entity.enrollmentYear = profile.enrollmentYear
                entity.examYear = profile.examYear
                entity.educationStage = profile.educationStage
                entity.regionCode = profile.regionCode
                entity.gender = profile.gender
                entity.targetSchool = profile.targetSchool
                entity.targetScore = profile.targetScore
            } else {
                context.insert(UserProfileRecord(from: profile))
            }
            try context.save()
            Log.data.debug("保存 profile 成功 / Saved profile to SwiftData")
            Log.record(.info, category: "Data", message: "保存 profile 成功 / Saved profile to SwiftData")
        } catch {
            Log.data.error("保存 profile 失败 / Error saving profile: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Grades (SwiftData)

    func saveGrades() {
        // 现在 @Published 是同步源：每条 grade 在 add/update/delete 时已写入 SwiftData
        // No-op: changes are now persisted immediately on add/update/delete.
        // 重新做一次保存以确保所有未刷新的修改落盘
        try? modelContext?.save()
    }

    func loadGrades() {
        // 由 asyncInit 统一加载；这里保留仅为向后兼容
    }

    /// 异步加载 grades
    /// Asynchronously load grades
    func loadGradesAsync() async {
        // 由 asyncInit 统一加载；这里保留仅为向后兼容
    }

    func saveMistakeSets() {
        try? modelContext?.save()
    }

    func loadMistakeSets() {
        // 由 asyncInit 统一加载
    }

    /// 异步加载 mistakes
    /// Asynchronously load mistakes
    func loadMistakeSetsAsync() async {
        // 由 asyncInit 统一加载
    }

    // 新增：添加错题的方法 / Add a mistake note
    func addMistake(_ mistake: MistakeNote) {
        if let context = modelContext {
            context.insert(MistakeNoteRecord(from: mistake))
            try? context.save()
        }
        mistakeSets.append(mistake)
        Log.data.info("新增错题 / Added mistake: title=\(mistake.title, privacy: .public) subject=\(mistake.subject, privacy: .public)")
        Log.record(.info, category: "Data", message: "新增错题 / Added mistake: title=\(mistake.title) subject=\(mistake.subject)")
    }

    // 可选：删除错题的方法（方便后续扩展）/ Delete mistake notes (helpers)
    func deleteMistake(at offsets: IndexSet, in set: inout [MistakeNote]) {
        let removed = offsets.map { set[$0] }
        for note in removed {
            removeMistakeEntity(id: note.id)
        }
        set.remove(atOffsets: offsets)
        Log.data.info("批量删除错题 / Removed mistakes: \(removed.map(\.title).joined(separator: ", "), privacy: .public)")
    }

    func deleteMistake(_ mistake: MistakeNote) {
        // 取消该错题的 SRS 复习通知
        SRSReviewNotifications.shared.cancel(for: mistake.id)
        removeMistakeEntity(id: mistake.id)
        if let index = mistakeSets.firstIndex(where: { $0.id == mistake.id }) {
            mistakeSets.remove(at: index)
        }
        Log.data.info("删除错题 / Deleted mistake: title=\(mistake.title, privacy: .public)")
        Log.record(.info, category: "Data", message: "删除错题 / Deleted mistake: title=\(mistake.title)")
    }

    // 新增：更新错题的方法 / Update a mistake note
    func updateMistake(_ updatedMistake: MistakeNote) {
        updateMistakeEntity(updatedMistake)
        if let index = mistakeSets.firstIndex(where: { $0.id == updatedMistake.id }) {
            mistakeSets[index] = updatedMistake
        }
        Log.data.debug("更新错题 / Updated mistake: title=\(updatedMistake.title, privacy: .public)")
    }

    /// 更新某张错题的 SRS 复习状态（不修改其它字段）
    /// - Parameters:
    ///   - mistakeId: 错题 UUID
    ///   - newState: 新复习状态，传入 nil 表示退出队列
    func updateMistakeReviewState(_ mistakeId: UUID, newState: ReviewState?) {
        guard let index = mistakeSets.firstIndex(where: { $0.id == mistakeId }) else {
            Log.data.warning("未找到要更新 SRS 的错题 / Mistake to update SRS not found: id=\(mistakeId.uuidString, privacy: .public)")
            return
        }
        mistakeSets[index].reviewState = newState
        updateMistakeEntity(mistakeSets[index])
        Log.data.info("更新错题 SRS 状态 / Updated mistake SRS state: id=\(mistakeId.uuidString, privacy: .public) enrolled=\(newState != nil, privacy: .public)")
    }

    // 新增：保存考试集合 / Save exam sets
    func saveExamSets() {
        try? modelContext?.save()
        syncExamsToWidget()
    }

    // 修改：加载考试集合 (确保主线程更新)
    // Load exam sets (ensure main-thread updates)
    func loadExamSets() {
        // 由 asyncInit 统一加载
    }

    func saveComprehensiveExams() {
        try? modelContext?.save()
        syncExamsToWidget()
    }

    // 新增：添加成绩的方法 / Add a grade
    func addGrade(_ grade: Grade) {
        if let context = modelContext {
            context.insert(GradeRecord(from: grade))
            try? context.save()
        }
        grades.append(grade)
        Log.data.info("新增成绩 / Added grade: subject=\(grade.subject, privacy: .public) score=\(grade.score, privacy: .public)")
        Log.record(.info, category: "Data", message: "新增成绩 / Added grade: subject=\(grade.subject) score=\(grade.score)")
        AchievementManager.shared.recordGradeRecorded()
        syncGradesToWidget()
    }

    // 新增：删除成绩的方法 / Delete a grade
    func deleteGrade(_ grade: Grade) {
        // 如果有图片文件，也删除它 / Remove the image file too, if any
        if let imageFileName = grade.imageFileName {
            let imagesDir = getDocumentsDirectory().appendingPathComponent("images")
            let fileURL = imagesDir.appendingPathComponent(imageFileName)
            try? FileManager.default.removeItem(at: fileURL)
            Log.data.debug("删除成绩图片 / Removed grade image: \(imageFileName, privacy: .public)")
        }

        removeGradeRecord(id: grade.id)
        grades.removeAll { $0.id == grade.id }
        Log.data.info("删除成绩 / Deleted grade: subject=\(grade.subject, privacy: .public)")
        Log.record(.info, category: "Data", message: "删除成绩 / Deleted grade: subject=\(grade.subject)")
        syncGradesToWidget()
    }

    // 新增：批量添加成绩的方法（用于导入）
    // Batch add grades (for import)
    func addGrades(_ newGrades: [Grade]) {
        if let context = modelContext {
            for g in newGrades {
                context.insert(GradeRecord(from: g))
            }
            try? context.save()
        }
        grades.append(contentsOf: newGrades)
        let count = newGrades.count
        Log.data.info("批量新增成绩 / Batch added grades: count=\(count, privacy: .public)")
        Log.record(.info, category: "Data", message: "批量新增成绩 / Batch added grades: count=\(count)")
        AchievementManager.shared.recordGradeRecorded(count: count)
        syncGradesToWidget()
    }

    // 新增：批量添加错题的方法（用于导入）
    // Batch add mistakes (for import)
    func addMistakes(_ newMistakes: [MistakeNote]) {
        if let context = modelContext {
            for m in newMistakes {
                context.insert(MistakeNoteRecord(from: m))
            }
            try? context.save()
        }
        mistakeSets.append(contentsOf: newMistakes)
        let count = newMistakes.count
        Log.data.info("批量新增错题 / Batch added mistakes: count=\(count, privacy: .public)")
        Log.record(.info, category: "Data", message: "批量新增错题 / Batch added mistakes: count=\(count)")
    }

    // 新增：批量添加考试的方法（用于导入）
    // Batch add exams (for import)
    func addExams(single: [Exam], comprehensive: [comprehensiveExam]) {
        if let context = modelContext {
            for e in single { context.insert(ExamRecord(from: e)) }
            for e in comprehensive { context.insert(ComprehensiveExamRecord(from: e)) }
            try? context.save()
        }
        examSets.append(contentsOf: single)
        comprehensiveExamSets.append(contentsOf: comprehensive)
        Log.data.info("批量新增考试 / Batch added exams: single=\(single.count, privacy: .public) comprehensive=\(comprehensive.count, privacy: .public)")
        Log.record(.info, category: "Data", message: "批量新增考试 / Batch added exams: single=\(single.count) comprehensive=\(comprehensive.count)")
        syncExamsToWidget()
    }

    // 修改：加载综合考试 (确保主线程更新)
    // Load comprehensive exams (ensure main-thread updates)
    func loadComprehensiveExams() {
        // 由 asyncInit 统一加载
    }

    func saveSubjects() {
        if let context = modelContext {
            // 同步 subjects 到 SwiftData：增量 upsert（按 name 匹配）
            do {
                let existing = try context.fetch(FetchDescriptor<SubjectRecord>())
                let existingByName = Dictionary(uniqueKeysWithValues: existing.map { ($0.name, $0) })
                let newNames = Set(subjects.map(\.name))
                // 删除已不存在的
                for entity in existing where !newNames.contains(entity.name) {
                    context.delete(entity)
                }
                // 新增 / 更新
                for s in subjects {
                    if let entity = existingByName[s.name] {
                        entity.enabled = s.enabled
                        entity.fullScore = s.fullScore
                        entity.displayName = s.displayName
                    } else {
                        context.insert(SubjectRecord(from: s))
                    }
                }
                try context.save()
            } catch {
                Log.data.error("保存 subjects 失败 / Error saving subjects: \(error.localizedDescription, privacy: .public)")
                return
            }
        }
        Log.data.debug("保存 subjects 成功 / Saved subjects: count=\(self.subjects.count, privacy: .public)")
    }

    func loadSubjects() {
        // 由 asyncInit 统一加载
    }

    // MARK: - SwiftData 实体辅助方法

    /// 删除指定 id 的 GradeRecord
    private func removeGradeRecord(id: UUID) {
        guard let context = modelContext else { return }
        do {
            if let entity = try context.fetch(
                FetchDescriptor<GradeRecord>(predicate: #Predicate { $0.id == id })
            ).first {
                context.delete(entity)
                try context.save()
            }
        } catch {
            Log.data.error("删除 GradeRecord 失败 / Failed to delete GradeRecord: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 删除指定 id 的 MistakeNoteRecord
    private func removeMistakeEntity(id: UUID) {
        guard let context = modelContext else { return }
        do {
            if let entity = try context.fetch(
                FetchDescriptor<MistakeNoteRecord>(predicate: #Predicate { $0.id == id })
            ).first {
                context.delete(entity)
                try context.save()
            }
        } catch {
            Log.data.error("删除 MistakeNoteRecord 失败 / Failed to delete MistakeNoteRecord: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 更新指定 id 的 MistakeNoteRecord（找到则更新，未找到则插入）
    private func updateMistakeEntity(_ note: MistakeNote) {
        guard let context = modelContext else { return }
        do {
            if let entity = try context.fetch(
                FetchDescriptor<MistakeNoteRecord>(predicate: #Predicate { $0.id == note.id })
            ).first {
                let srs = note.reviewState
                entity.title = note.title
                entity.subject = note.subject
                entity.originalQuestion = note.originalQuestion
                entity.source = note.source
                entity.date = note.date
                entity.errorReason = note.errorReason
                entity.wrongSolution = note.wrongSolution
                entity.correctSolution = note.correctSolution
                entity.srsRepetitions = srs?.repetitions ?? 0
                entity.srsEaseFactor = srs?.easeFactor ?? 2.5
                entity.srsIntervalDays = srs?.intervalDays ?? 0
                entity.srsNextReviewDate = srs?.nextReviewDate
                entity.srsLastReviewDate = srs?.lastReviewDate
                entity.srsLapses = srs?.lapses ?? 0
                entity.questionImagesData = note.questionImages
                entity.reasonImagesData = note.reasonImages
                entity.wrongSolutionImagesData = note.wrongSolutionImages
                entity.correctSolutionImagesData = note.correctSolutionImages
                try context.save()
            } else {
                // 没找到就插入新记录
                context.insert(MistakeNoteRecord(from: note))
                try context.save()
            }
        } catch {
            Log.data.error("更新 MistakeNoteRecord 失败 / Failed to update MistakeNoteRecord: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 把当前 grades 同步到 Trend Widget
    private func syncGradesToWidget() {
        Task {
            TrendWidgetSyncManager.syncTrend(grades: grades, subjects: subjects)
        }
    }

    /// 把当前 examSets / comprehensiveExamSets 同步到 Exam Widget
    private func syncExamsToWidget() {
        WidgetDataSyncManager.syncUpcomingExams(
            examSets: examSets,
            comprehensiveExamSets: comprehensiveExamSets
        )
    }

    // MARK: - Task Items (作业 / 阅读材料)

    /// 新增任务（作业 / 阅读材料）
    /// Add a new task item (homework or reading material).
    /// - Parameters:
    ///   - task: 任务快照
    ///   - syncToReminders: 是否同步到系统 Reminders（如果关闭，由调用方自己处理 EKReminder 同步）
    ///   - reminderOverride: 传入同步后的 (calendarItemId, calendarId)，写回 task.reminderEventId/reminderCalendarId
    /// 调用方在 syncToReminders == true 时应自行调用 CalendarManager 并把结果回填。
    func addTask(
        _ task: TaskItem,
        syncToReminders: Bool,
        reminderResult: (calendarItemId: String, calendarId: String)? = nil
    ) {
        var stored = task
        if syncToReminders, let result = reminderResult {
            stored.reminderEventId = result.calendarItemId
            stored.reminderCalendarId = result.calendarId
        } else if !syncToReminders {
            stored.reminderEventId = nil
            stored.reminderCalendarId = nil
        }

        if let context = modelContext {
            context.insert(TaskItemRecord(from: stored))
            try? context.save()
        }
        taskItems.append(stored)
        // 任务列表按 dueDate 升序保持
        taskItems.sort { $0.dueDate < $1.dueDate }
        Log.data.info("新增任务 / Added task: title=\(stored.title, privacy: .public) type=\(stored.type.rawValue, privacy: .public) dueDate=\(stored.dueDate, privacy: .public)")
        Log.record(.info, category: "Data", message: "新增任务 / Added task: title=\(stored.title) type=\(stored.type.rawValue) dueDate=\(stored.dueDate)")
    }

    /// 批量新增任务（用于 CSV 导入等场景）
    /// Batch add tasks (for CSV import etc.)
    func addTasks(_ newTasks: [TaskItem]) {
        guard !newTasks.isEmpty else { return }
        if let context = modelContext {
            for t in newTasks {
                context.insert(TaskItemRecord(from: t))
            }
            try? context.save()
        }
        taskItems.append(contentsOf: newTasks)
        taskItems.sort { $0.dueDate < $1.dueDate }
        Log.data.info("批量新增任务 / Batch added tasks: count=\(newTasks.count, privacy: .public)")
        Log.record(.info, category: "Data", message: "批量新增任务 / Batch added tasks: count=\(newTasks.count)")
    }

    /// 更新已有任务
    /// Update an existing task.
    /// - Parameters:
    ///   - updated: 新任务快照
    ///   - reminderUpdateResult: 同步到系统 Reminders 后的结果（nil 表示未同步 / 失败）
    func updateTask(
        _ updated: TaskItem,
        reminderResult: (calendarItemId: String, calendarId: String)? = nil
    ) {
        var stored = updated
        if let result = reminderResult {
            stored.reminderEventId = result.calendarItemId
            stored.reminderCalendarId = result.calendarId
        }

        if let index = taskItems.firstIndex(where: { $0.id == stored.id }) {
            taskItems[index] = stored
            taskItems.sort { $0.dueDate < $1.dueDate }
        }
        updateTaskEntity(stored)
        Log.data.info("更新任务 / Updated task: title=\(stored.title, privacy: .public) id=\(stored.id.uuidString, privacy: .public)")
        Log.record(.info, category: "Data", message: "更新任务 / Updated task: title=\(stored.title) id=\(stored.id.uuidString)")
    }

    /// 删除任务（同步从系统 Reminders 移除已绑定的提醒项）
    /// Delete a task and remove its linked Reminder, if any.
    func deleteTask(_ task: TaskItem) {
        let reminderId = task.reminderEventId
        removeTaskEntity(id: task.id)
        if let index = taskItems.firstIndex(where: { $0.id == task.id }) {
            taskItems.remove(at: index)
        }
        if let reminderId = reminderId {
            Task {
                do {
                    _ = try await CalendarManager.shared.removeTaskFromReminders(calendarItemId: reminderId)
                } catch {
                    Log.data.warning("删除系统 Reminder 失败 / Failed to remove system Reminder: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
        Log.data.info("删除任务 / Deleted task: title=\(task.title, privacy: .public) id=\(task.id.uuidString, privacy: .public)")
        Log.record(.info, category: "Data", message: "删除任务 / Deleted task: title=\(task.title) id=\(task.id.uuidString)")
    }

    /// 切换任务完成态
    /// Toggle the task's completion flag and mirror it in system Reminders (if linked).
    func setTaskCompletion(_ taskId: UUID, isCompleted: Bool) {
        guard let index = taskItems.firstIndex(where: { $0.id == taskId }) else {
            Log.data.warning("未找到要切换完成态的任务 / Task not found: id=\(taskId.uuidString, privacy: .public)")
            return
        }
        var updated = taskItems[index]
        updated.isCompleted = isCompleted
        taskItems[index] = updated
        updateTaskEntity(updated)

        // 同步到系统 Reminders（如果绑定过）
        if let reminderId = updated.reminderEventId {
            Task {
                do {
                    _ = try await CalendarManager.shared.setTaskCompletionInReminders(
                        calendarItemId: reminderId,
                        isCompleted: isCompleted
                    )
                } catch {
                    Log.data.warning("同步系统 Reminder 完成态失败 / Failed to sync reminder completion: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
        Log.data.info("切换任务完成态 / Toggled task completion: id=\(taskId.uuidString, privacy: .public) completed=\(isCompleted, privacy: .public)")
    }

    /// 从系统 Reminders 拉取所有已绑定任务的当前完成态,并把差异写回本地。
    /// Pulls the current completion flags for all linked tasks from the system Reminders app
    /// and writes any changes back to the local store. If a Reminder has been deleted
    /// externally, the local reminderEventId / reminderCalendarId is cleared.
    ///
    /// - 幂等,可安全在启动时与页面 onAppear 时调用。
    /// - Idempotent; safe to call on launch and on view appear.
    func refreshTaskCompletionStatesFromReminders() {
        // 仅处理有 reminderEventId 的任务
        let tasksToRefresh = taskItems.filter { $0.reminderEventId != nil }
        guard !tasksToRefresh.isEmpty else { return }

        Task {
            var changed = 0
            var cleared = 0
            for task in tasksToRefresh {
                guard let reminderId = task.reminderEventId else { continue }
                do {
                    if let isCompleted = try await CalendarManager.shared.getTaskCompletionFromReminders(calendarItemId: reminderId) {
                        // Reminder 仍存在,检查完成态是否与本地一致
                        if task.isCompleted != isCompleted {
                            await MainActor.run {
                                if let idx = self.taskItems.firstIndex(where: { $0.id == task.id }) {
                                    self.taskItems[idx].isCompleted = isCompleted
                                    self.updateTaskEntity(self.taskItems[idx])
                                }
                            }
                            changed += 1
                        }
                    } else {
                        // Reminder 已被外部删除,清掉本地 reminderEventId / reminderCalendarId
                        await MainActor.run {
                            if let idx = self.taskItems.firstIndex(where: { $0.id == task.id }) {
                                self.taskItems[idx].reminderEventId = nil
                                self.taskItems[idx].reminderCalendarId = nil
                                self.updateTaskEntity(self.taskItems[idx])
                            }
                        }
                        cleared += 1
                    }
                } catch {
                    Log.data.warning("读取 Reminder 完成态失败 / Failed to read reminder completion: \(error.localizedDescription, privacy: .public)")
                }
            }
            if changed > 0 || cleared > 0 {
                Log.data.info("从 Reminders 同步完成态 / Synced completion from Reminders: changed=\(changed, privacy: .public) cleared=\(cleared, privacy: .public)")
                Log.record(.info, category: "Data", message: "从 Reminders 同步完成态: changed=\(changed) cleared=\(cleared)")
            }
        }
    }

    /// 保存任务（兼容旧 API；当前每次 add/update/delete 已即时落盘，此处为 no-op + 强制 save）
    func saveTaskItems() {
        try? modelContext?.save()
    }

    /// 构造统一的 TodoEntry 列表（考试 + 作业 + 阅读），按时间升序
    /// Build a unified `TodoEntry` list (exams + homework + reading) sorted ascending by date.
    /// - Parameter includeCompleted: 是否包含已完成的任务（默认 false：已完成的作业/阅读不进入主列表）
    func todoEntries(includeCompleted: Bool = false) -> [TodoEntry] {
        var entries: [TodoEntry] = []

        for exam in examSets {
            entries.append(TodoEntry(
                id: exam.id,
                kind: .exam,
                title: exam.name,
                subject: exam.subject,
                date: exam.examDate,
                endDate: exam.examEndDate,
                importance: exam.importance,
                isCompleted: false,
                exam: exam,
                comprehensiveExam: nil,
                taskItem: nil
            ))
        }
        for exam in comprehensiveExamSets {
            let subjectText = exam.subject.joined(separator: ", ")
            entries.append(TodoEntry(
                id: exam.id,
                kind: .comprehensiveExam,
                title: exam.name,
                subject: subjectText,
                date: exam.examDate,
                endDate: exam.examEndDate,
                importance: exam.importance,
                isCompleted: false,
                exam: nil,
                comprehensiveExam: exam,
                taskItem: nil
            ))
        }
        for task in taskItems where (includeCompleted || !task.isCompleted) {
            let kind: TodoEntryKind = task.type == .homework ? .homework : .reading
            entries.append(TodoEntry(
                id: task.id,
                kind: kind,
                title: task.title,
                subject: task.subject,
                date: task.dueDate,
                endDate: nil,
                importance: task.importance,
                isCompleted: task.isCompleted,
                exam: nil,
                comprehensiveExam: nil,
                taskItem: task
            ))
        }
        return entries.sorted { $0.date < $1.date }
    }

    /// 删除指定 id 的 TaskItemRecord
    private func removeTaskEntity(id: UUID) {
        guard let context = modelContext else { return }
        do {
            if let entity = try context.fetch(
                FetchDescriptor<TaskItemRecord>(predicate: #Predicate { $0.id == id })
            ).first {
                context.delete(entity)
                try context.save()
            }
        } catch {
            Log.data.error("删除 TaskItemRecord 失败 / Failed to delete TaskItemRecord: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 更新指定 id 的 TaskItemRecord（找到则更新，未找到则插入）
    private func updateTaskEntity(_ task: TaskItem) {
        guard let context = modelContext else { return }
        do {
            if let entity = try context.fetch(
                FetchDescriptor<TaskItemRecord>(predicate: #Predicate { $0.id == task.id })
            ).first {
                entity.title = task.title
                entity.typeRaw = task.type.rawValue
                entity.dueDate = task.dueDate
                entity.reminderDate = task.reminderDate
                entity.subject = task.subject
                entity.importance = task.importance
                entity.notes = task.notes
                entity.isCompleted = task.isCompleted
                entity.reminderEventId = task.reminderEventId
                entity.reminderCalendarId = task.reminderCalendarId
                entity.createdAt = task.createdAt
                try context.save()
            } else {
                context.insert(TaskItemRecord(from: task))
                try context.save()
            }
        } catch {
            Log.data.error("更新 TaskItemRecord 失败 / Failed to update TaskItemRecord: \(error.localizedDescription, privacy: .public)")
        }
    }
}
