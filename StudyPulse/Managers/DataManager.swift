//
//  DataManager.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import Foundation
import Combine
import SwiftUI
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
/// 数据存储于 ~/Documents/ 目录下的 JSON 文件
class DataManager: ObservableObject {
    static let shared = DataManager()
    
    // MARK: - 已发布数据
    
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

    /// Set by open-app App Intents to trigger pre-filled sheets in ContentView.
    @Published var pendingIntentAction: IntentAction? = nil

   /// 异步加载完成后置为 true。视图与 widget 同步可据此判断数据是否就绪。
    @Published private(set) var isReady: Bool = false

    init() {
        // 故意不在这里读取任何磁盘 I/O；
        // 启动时由 asyncInit() 在后台 Task 中并行加载，避免阻塞主线程。
    }

    // MARK: - 异步初始化

    /// 异步初始化：在后台线程并行加载所有数据，避免阻塞主线程
    /// 用 `await dataManager.asyncInit()` 在 .task 中等待完成
    /// Async init: load all data in parallel on background threads to avoid blocking main.
    /// Await with `await dataManager.asyncInit()` inside a `.task` modifier.
    func asyncInit() async {
        Log.data.info("asyncInit 开始 / asyncInit start")
        Log.record(.info, category: "Data", message: "asyncInit 开始 / asyncInit start")
        let docsDir = DataFileIO.getDocsDir()
        let imagesDir = DataFileIO.getImagesDir()
        Log.data.debug("数据目录 / Docs dir: \(docsDir.path, privacy: .public); 图片目录 / Images dir: \(imagesDir.path, privacy: .public)")

        // 解码器在子任务中共享（线程安全的 JSONDecoder/Encoder）
        let examsDecoder = JSONDecoder()
        examsDecoder.dateDecodingStrategy = .iso8601
        let encoder = JSONEncoder()

        // 并行读取 6 个 JSON 文件，把磁盘 I/O 串行化压成 ~1 倍耗时
        async let profile: UserProfile? = DataFileIO.load(url: docsDir.appendingPathComponent("profile.json"))
        async let grades: [Grade]? = DataFileIO.load(url: docsDir.appendingPathComponent("grades.json"))
        async let mistakes: [MistakeNote]? = DataFileIO.load(url: docsDir.appendingPathComponent("mistakes.json"))
        async let exams: [Exam]? = DataFileIO.load(
            url: docsDir.appendingPathComponent("exams.json"),
            decoder: examsDecoder
        )
        async let compExams: [comprehensiveExam]? = DataFileIO.load(
            url: docsDir.appendingPathComponent("comprehensiveExams.json"),
            decoder: examsDecoder
        )
        async let subjects: [Subject]? = DataFileIO.load(url: docsDir.appendingPathComponent("subjects.json"))

        // 迁移内嵌图片（后台线程上执行，必要时写盘后回写 grades.json）
        let loadedGrades = await grades ?? []
        var migratedGrades = loadedGrades
        var needsSave = false
        var migratedImageCount = 0
        for i in 0..<migratedGrades.count where migratedGrades[i].image != nil && migratedGrades[i].imageFileName == nil {
            let grade = migratedGrades[i]
            if let imageData = grade.image {
                let filename = "grade_\(grade.id.uuidString).jpg"
                let url = imagesDir.appendingPathComponent(filename)
                do {
                    try imageData.write(to: url)
                    migratedGrades[i].imageFileName = filename
                    migratedGrades[i].image = nil
                    needsSave = true
                    migratedImageCount += 1
                } catch {
                    Log.data.error("迁移内嵌图片失败 / Migrating inline image failed for grade=\(grade.id.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }
        }
        if needsSave, let data = try? encoder.encode(migratedGrades) {
            do {
                try data.write(to: docsDir.appendingPathComponent("grades.json"))
                Log.data.info("迁移内嵌图片完成 / Migrated inline grade images: count=\(migratedImageCount, privacy: .public)")
            } catch {
                Log.data.error("回写迁移后 grades.json 失败 / Failed to rewrite grades.json after migration: \(error.localizedDescription, privacy: .public)")
            }
        } else if migratedImageCount == 0 {
            Log.data.debug("无需迁移内嵌图片 / No inline grade images to migrate")
        }

        // 一次性把数据迁回主线程：避免多次 MainActor.run 触发多次 @Published 重渲染
        let loadedProfile = await profile
        let loadedMistakes = await mistakes
        let loadedExams = await exams
        let loadedCompExams = await compExams
        let loadedSubjects = await subjects

        await MainActor.run {
            if let p = loadedProfile { self.profile = p }
            self.grades = migratedGrades
            if let m = loadedMistakes { self.mistakeSets = m }
            if let e = loadedExams { self.examSets = e }
            if let c = loadedCompExams { self.comprehensiveExamSets = c }
            if let s = loadedSubjects { self.subjects = s } else {
                Log.data.info("未找到 subjects.json，初始化默认科目 / subjects.json missing, initializing default subjects")
                self.initializeDefaultSubjects()
            }
            self.isReady = true

            Log.data.info("asyncInit 完成 / asyncInit done; grades=\(self.grades.count, privacy: .public) mistakes=\(self.mistakeSets.count, privacy: .public) exams=\(self.examSets.count, privacy: .public) compExams=\(self.comprehensiveExamSets.count, privacy: .public) subjects=\(self.subjects.count, privacy: .public)")
            Log.record(.info, category: "Data", message: "asyncInit 完成 / asyncInit done; grades=\(self.grades.count) mistakes=\(self.mistakeSets.count) exams=\(self.examSets.count) compExams=\(self.comprehensiveExamSets.count) subjects=\(self.subjects.count)")

            // 启动时同步 SRS 复习通知
            SRSReviewNotifications.shared.rescheduleAll(mistakes: self.mistakeSets)

            // 启动时同步考试与趋势数据到 Widget（在主线程上，因为 @MainActor 标注的 widget sync）
            WidgetDataSyncManager.syncUpcomingExams(
                examSets: self.examSets,
                comprehensiveExamSets: self.comprehensiveExamSets
            )
            TrendWidgetSyncManager.syncTrend(grades: self.grades, subjects: self.subjects)
        }
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
    }
    
    func saveProfile() {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(profile)
            let url = getDocumentsDirectory().appendingPathComponent("profile.json")
            try data.write(to: url)
            Log.data.debug("保存 profile 成功 / Saved profile: bytes=\(data.count, privacy: .public)")
            Log.record(.info, category: "Data", message: "保存 profile 成功 / Saved profile: bytes=\(data.count)")
        } catch {
            Log.data.error("保存 profile 失败 / Error saving profile: \(error.localizedDescription, privacy: .public)")
            Log.record(.error, category: "Data", message: "保存 profile 失败 / Error saving profile: \(error.localizedDescription)")
        }
    }

    func loadProfile() {
        let url = getDocumentsDirectory().appendingPathComponent("profile.json")
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                profile = try decoder.decode(UserProfile.self, from: data)
                Log.data.info("加载 profile 成功 / Loaded profile")
            } catch {
                Log.data.error("加载 profile 失败 / Error loading profile: \(error.localizedDescription, privacy: .public)")
            }
        } else {
            Log.data.debug("profile.json 不存在 / profile.json not found")
        }
    }

    /// 异步加载 profile
    /// Asynchronously load profile
    func loadProfileAsync() async {
        let url = getDocumentsDirectory().appendingPathComponent("profile.json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            Log.data.debug("profile.json 不存在，跳过 / profile.json missing, skipping")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let loaded = try decoder.decode(UserProfile.self, from: data)
            await MainActor.run { profile = loaded }
            Log.data.info("异步加载 profile 成功 / Async profile loaded")
        } catch {
            Log.data.error("异步加载 profile 失败 / Error loading profile: \(error.localizedDescription, privacy: .public)")
        }
    }

    func saveGrades() {
        // 迁移：将内嵌图片写入文件系统
        // Migrate: write any inline image data to the file system
        var migratedInline = 0
        for i in 0..<grades.count {
            if let imageData = grades[i].image, grades[i].imageFileName == nil {
                if let filename = saveGradeImage(imageData, gradeId: grades[i].id) {
                    grades[i].imageFileName = filename
                    grades[i].image = nil // 清除内嵌数据，减小 JSON 体积
                    migratedInline += 1
                }
            }
        }
        if migratedInline > 0 {
            Log.data.info("保存时迁移了内嵌图片 / Migrated inline images during saveGrades: count=\(migratedInline, privacy: .public)")
            Log.record(.info, category: "Data", message: "保存时迁移了内嵌图片 / Migrated inline images during saveGrades: count=\(migratedInline)")
        }

        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(grades)
            let url = getDocumentsDirectory().appendingPathComponent("grades.json")
            try data.write(to: url)
            Log.data.debug("保存 grades 成功 / Saved grades: count=\(self.grades.count, privacy: .public) bytes=\(data.count, privacy: .public)")
            Log.record(.info, category: "Data", message: "保存 grades 成功 / Saved grades: count=\(self.grades.count) bytes=\(data.count)")
        } catch {
            Log.data.error("保存 grades 失败 / Error saving grades: \(error.localizedDescription, privacy: .public)")
            Log.record(.error, category: "Data", message: "保存 grades 失败 / Error saving grades: \(error.localizedDescription)")
        }

        // 同步趋势数据到 Widget
        // Sync trend data to widget
        Task {
            TrendWidgetSyncManager.syncTrend(grades: grades, subjects: subjects)
        }
    }

    func loadGrades() {
        let url = getDocumentsDirectory().appendingPathComponent("grades.json")
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                grades = try decoder.decode([Grade].self, from: data)
                Log.data.info("加载 grades 成功 / Loaded grades: count=\(self.grades.count, privacy: .public)")

                // 迁移：将旧数据的内嵌图片写入文件系统
                // Migrate inline images for legacy data
                var needsSave = false
                var migratedInline = 0
                for i in 0..<grades.count {
                    if let imageData = grades[i].image, grades[i].imageFileName == nil {
                        if let filename = saveGradeImage(imageData, gradeId: grades[i].id) {
                            grades[i].imageFileName = filename
                            grades[i].image = nil
                            needsSave = true
                            migratedInline += 1
                        }
                    }
                }
                if needsSave {
                    Log.data.info("加载时迁移了内嵌图片 / Migrated inline images during loadGrades: count=\(migratedInline, privacy: .public)")
                    saveGrades()
                }
            } catch {
                Log.data.error("加载 grades 失败 / Error loading grades: \(error.localizedDescription, privacy: .public)")
            }
        } else {
            Log.data.debug("grades.json 不存在 / grades.json not found")
        }
    }

    /// 异步加载 grades
    /// Asynchronously load grades
    func loadGradesAsync() async {
        let url = getDocumentsDirectory().appendingPathComponent("grades.json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            Log.data.debug("grades.json 不存在，跳过 / grades.json missing, skipping")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let loaded = try decoder.decode([Grade].self, from: data)
            await MainActor.run { grades = loaded }
            Log.data.info("异步加载 grades 成功 / Async grades loaded: count=\(loaded.count, privacy: .public)")
        } catch {
            Log.data.error("异步加载 grades 失败 / Error loading grades: \(error.localizedDescription, privacy: .public)")
        }
    }

    func saveMistakeSets() {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(mistakeSets)
            let url = getDocumentsDirectory().appendingPathComponent("mistakes.json")
            try data.write(to: url)
            Log.data.debug("保存 mistakes 成功 / Saved mistakes: count=\(self.mistakeSets.count, privacy: .public) bytes=\(data.count, privacy: .public)")
            Log.record(.info, category: "Data", message: "保存 mistakes 成功 / Saved mistakes: count=\(self.mistakeSets.count) bytes=\(data.count)")
        } catch {
            Log.data.error("保存 mistakes 失败 / Error saving mistakes: \(error.localizedDescription, privacy: .public)")
            Log.record(.error, category: "Data", message: "保存 mistakes 失败 / Error saving mistakes: \(error.localizedDescription)")
        }
    }

    func loadMistakeSets() {
        let url = getDocumentsDirectory().appendingPathComponent("mistakes.json")
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                mistakeSets = try decoder.decode([MistakeNote].self, from: data)
                Log.data.info("加载 mistakes 成功 / Loaded mistakes: count=\(self.mistakeSets.count, privacy: .public)")
            } catch {
                Log.data.error("加载 mistakes 失败 / Error loading mistakes: \(error.localizedDescription, privacy: .public)")
            }
        } else {
            Log.data.debug("mistakes.json 不存在 / mistakes.json not found")
        }
    }

    /// 异步加载 mistakes
    /// Asynchronously load mistakes
    func loadMistakeSetsAsync() async {
        let url = getDocumentsDirectory().appendingPathComponent("mistakes.json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            Log.data.debug("mistakes.json 不存在，跳过 / mistakes.json missing, skipping")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let loaded = try decoder.decode([MistakeNote].self, from: data)
            await MainActor.run { mistakeSets = loaded }
            Log.data.info("异步加载 mistakes 成功 / Async mistakes loaded: count=\(loaded.count, privacy: .public)")
        } catch {
            Log.data.error("异步加载 mistakes 失败 / Error loading mistakes: \(error.localizedDescription, privacy: .public)")
        }
    }

    // 新增：添加错题的方法 / Add a mistake note
    func addMistake(_ mistake: MistakeNote) {
        mistakeSets.append(mistake)
        Log.data.info("新增错题 / Added mistake: title=\(mistake.title, privacy: .public) subject=\(mistake.subject, privacy: .public)")
        Log.record(.info, category: "Data", message: "新增错题 / Added mistake: title=\(mistake.title) subject=\(mistake.subject)")
        saveMistakeSets()
    }

    // 可选：删除错题的方法（方便后续扩展）/ Delete mistake notes (helpers)
    func deleteMistake(at offsets: IndexSet, in set: inout [MistakeNote]) {
        let removed = offsets.map { set[$0].title }
        set.remove(atOffsets: offsets)
        Log.data.info("批量删除错题 / Removed mistakes: \(removed.joined(separator: ", "), privacy: .public)")
        saveMistakeSets()
    }

    func deleteMistake(_ mistake: MistakeNote) {
        if let index = mistakeSets.firstIndex(where: { $0.id == mistake.id }) {
            // 取消该错题的 SRS 复习通知
            SRSReviewNotifications.shared.cancel(for: mistake.id)
            mistakeSets.remove(at: index)
            Log.data.info("删除错题 / Deleted mistake: title=\(mistake.title, privacy: .public)")
            Log.record(.info, category: "Data", message: "删除错题 / Deleted mistake: title=\(mistake.title)")
            saveMistakeSets()
        } else {
            Log.data.warning("未找到要删除的错题 / Mistake to delete not found: id=\(mistake.id.uuidString, privacy: .public)")
        }
    }

    // 新增：更新错题的方法 / Update a mistake note
    func updateMistake(_ updatedMistake: MistakeNote) {
        if let index = mistakeSets.firstIndex(where: { $0.id == updatedMistake.id }) {
            mistakeSets[index] = updatedMistake
            Log.data.debug("更新错题 / Updated mistake: title=\(updatedMistake.title, privacy: .public)")
            saveMistakeSets()
        } else {
            Log.data.warning("未找到要更新的错题 / Mistake to update not found: id=\(updatedMistake.id.uuidString, privacy: .public)")
        }
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
        saveMistakeSets()
        Log.data.info("更新错题 SRS 状态 / Updated mistake SRS state: id=\(mistakeId.uuidString, privacy: .public) enrolled=\(newState != nil, privacy: .public)")
    }

    // 新增：保存考试集合 / Save exam sets
    func saveExamSets() {
        let encoder = JSONEncoder()
        // 设置日期编码策略，防止 Date 序列化问题
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(examSets)
            let url = getDocumentsDirectory().appendingPathComponent("exams.json")
            try data.write(to: url)
            Log.data.info("保存 exams 成功 / Saved exams: count=\(self.examSets.count, privacy: .public) bytes=\(data.count, privacy: .public)")
            Log.record(.info, category: "Data", message: "保存 exams 成功 / Saved exams: count=\(self.examSets.count) bytes=\(data.count)")

            // 同步到 Widget
            Task {
                WidgetDataSyncManager.syncUpcomingExams(
                    examSets: examSets,
                    comprehensiveExamSets: comprehensiveExamSets
                )
            }
        } catch {
            Log.data.error("保存 exams 失败 / Error saving exams: \(error.localizedDescription, privacy: .public)")
            Log.record(.error, category: "Data", message: "保存 exams 失败 / Error saving exams: \(error.localizedDescription)")
        }
    }

    // 修改：加载考试集合 (确保主线程更新)
    // Load exam sets (ensure main-thread updates)
    func loadExamSets() {
        let url = getDocumentsDirectory().appendingPathComponent("exams.json")
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let loadedData = try decoder.decode([Exam].self, from: data)

                // 关键修改：确保在主线程更新 @Published 变量
                // Critical: update @Published on the main thread
                DispatchQueue.main.async {
                    self.examSets = loadedData
                    Log.data.info("加载 exams 成功 / Loaded exams: count=\(loadedData.count, privacy: .public)")
                }
            } catch {
                Log.data.error("加载 exams 失败 / Error loading exams: \(error.localizedDescription, privacy: .public)")
            }
        } else {
            Log.data.debug("exams.json 不存在 / exams.json not found")
        }
    }

    func saveComprehensiveExams() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(comprehensiveExamSets)
            let url = getDocumentsDirectory().appendingPathComponent("comprehensiveExams.json")
            try data.write(to: url)
            Log.data.info("保存综合考试成功 / Saved comprehensive exams: count=\(self.comprehensiveExamSets.count, privacy: .public) bytes=\(data.count, privacy: .public)")
            Log.record(.info, category: "Data", message: "保存综合考试成功 / Saved comprehensive exams: count=\(self.comprehensiveExamSets.count) bytes=\(data.count)")

            // 同步到 Widget
            Task {
                WidgetDataSyncManager.syncUpcomingExams(
                    examSets: examSets,
                    comprehensiveExamSets: comprehensiveExamSets
                )
            }
        } catch {
            Log.data.error("保存综合考试失败 / Error saving comprehensive exams: \(error.localizedDescription, privacy: .public)")
            Log.record(.error, category: "Data", message: "保存综合考试失败 / Error saving comprehensive exams: \(error.localizedDescription)")
        }
    }

    // 新增：添加成绩的方法 / Add a grade
    func addGrade(_ grade: Grade) {
        grades.append(grade)
        Log.data.info("新增成绩 / Added grade: subject=\(grade.subject, privacy: .public) score=\(grade.score, privacy: .public)")
        Log.record(.info, category: "Data", message: "新增成绩 / Added grade: subject=\(grade.subject) score=\(grade.score)")
        saveGrades()
    }

    // 新增：删除成绩的方法 / Delete a grade
    func deleteGrade(_ grade: Grade) {
        if let index = grades.firstIndex(where: { $0.id == grade.id }) {
            // 如果有图片文件，也删除它 / Remove the image file too, if any
            if let imageFileName = grade.imageFileName {
                let imagesDir = getDocumentsDirectory().appendingPathComponent("images")
                let fileURL = imagesDir.appendingPathComponent(imageFileName)
                try? FileManager.default.removeItem(at: fileURL)
                Log.data.debug("删除成绩图片 / Removed grade image: \(imageFileName, privacy: .public)")
                Log.record(.debug, category: "Data", message: "删除成绩图片 / Removed grade image: \(imageFileName)")
            }

            grades.remove(at: index)
            Log.data.info("删除成绩 / Deleted grade: subject=\(grade.subject, privacy: .public)")
            Log.record(.info, category: "Data", message: "删除成绩 / Deleted grade: subject=\(grade.subject)")
            saveGrades()
        } else {
            Log.data.warning("未找到要删除的成绩 / Grade to delete not found: id=\(grade.id.uuidString, privacy: .public)")
        }
    }

    // 新增：批量添加成绩的方法（用于导入）
    // Batch add grades (for import)
    func addGrades(_ newGrades: [Grade]) {
        let count = newGrades.count
        grades.append(contentsOf: newGrades)
        Log.data.info("批量新增成绩 / Batch added grades: count=\(count, privacy: .public)")
        Log.record(.info, category: "Data", message: "批量新增成绩 / Batch added grades: count=\(count)")
        saveGrades()
    }

    // 新增：批量添加错题的方法（用于导入）
    // Batch add mistakes (for import)
    func addMistakes(_ newMistakes: [MistakeNote]) {
        let count = newMistakes.count
        mistakeSets.append(contentsOf: newMistakes)
        Log.data.info("批量新增错题 / Batch added mistakes: count=\(count, privacy: .public)")
        Log.record(.info, category: "Data", message: "批量新增错题 / Batch added mistakes: count=\(count)")
        saveMistakeSets()
    }

    // 新增：批量添加考试的方法（用于导入）
    // Batch add exams (for import)
    func addExams(single: [Exam], comprehensive: [comprehensiveExam]) {
        examSets.append(contentsOf: single)
        comprehensiveExamSets.append(contentsOf: comprehensive)
        Log.data.info("批量新增考试 / Batch added exams: single=\(single.count, privacy: .public) comprehensive=\(comprehensive.count, privacy: .public)")
        Log.record(.info, category: "Data", message: "批量新增考试 / Batch added exams: single=\(single.count) comprehensive=\(comprehensive.count)")
        saveExamSets()
        saveComprehensiveExams()
    }

    // 修改：加载综合考试 (确保主线程更新)
    // Load comprehensive exams (ensure main-thread updates)
    func loadComprehensiveExams() {
        let url = getDocumentsDirectory().appendingPathComponent("comprehensiveExams.json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            Log.data.debug("comprehensiveExams.json 不存在 / comprehensiveExams.json not found")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let loadedData = try decoder.decode([comprehensiveExam].self, from: data)

            // 关键修改：确保在主线程更新 / Critical: update on main thread
            DispatchQueue.main.async {
                self.comprehensiveExamSets = loadedData
                Log.data.info("加载综合考试成功 / Loaded comprehensive exams: count=\(loadedData.count, privacy: .public)")
            }
        } catch {
            Log.data.error("加载综合考试失败 / Error loading comprehensive exams: \(error.localizedDescription, privacy: .public)")
        }
    }

    func saveSubjects() {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(subjects)
            let url = getDocumentsDirectory().appendingPathComponent("subjects.json")
            try data.write(to: url)
            Log.data.debug("保存 subjects 成功 / Saved subjects: count=\(self.subjects.count, privacy: .public) bytes=\(data.count, privacy: .public)")
            Log.record(.info, category: "Data", message: "保存 subjects 成功 / Saved subjects: count=\(self.subjects.count) bytes=\(data.count)")
        } catch {
            Log.data.error("保存 subjects 失败 / Error saving subjects: \(error.localizedDescription, privacy: .public)")
            Log.record(.error, category: "Data", message: "保存 subjects 失败 / Error saving subjects: \(error.localizedDescription)")
        }
    }

    func loadSubjects() {
        let url = getDocumentsDirectory().appendingPathComponent("subjects.json")
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                subjects = try decoder.decode([Subject].self, from: data)
                Log.data.info("加载 subjects 成功 / Loaded subjects: count=\(self.subjects.count, privacy: .public)")
            } catch {
                Log.data.error("加载 subjects 失败 / Error loading subjects: \(error.localizedDescription, privacy: .public)")
            }
        } else {
            Log.data.debug("subjects.json 不存在 / subjects.json not found")
        }
    }
    
}
