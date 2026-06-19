//
//  DataManager.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import Foundation
import Combine
import SwiftUI

// MARK: - File I/O Utilities

/// 线程安全的文件读写工具，避免受 @MainActor 限制
/// 用于后台线程加载和保存 JSON 数据
nonisolated enum DataFileIO {
    /// 获取 Documents 目录
    static func getDocsDir() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    /// 获取 images 子目录（不存在则自动创建）
    static func getImagesDir() -> URL {
        let url = getDocsDir().appendingPathComponent("images")
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }
    
    /// 从指定 URL 加载并解码 JSON 数据
    static func load<T: Codable>(url: URL, decoder: JSONDecoder = JSONDecoder()) -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(T.self, from: data)
        } catch {
            print("Error loading \(url.lastPathComponent): \(error)")
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
    
    init() {
        loadProfile()
        loadGrades()
        loadMistakeSets()
        loadExamSets()
        initializeDefaultSubjects()
        loadComprehensiveExams()
        loadSubjects()
    }
    
    // MARK: - 异步初始化
    
    /// 异步初始化：在后台线程加载所有数据，避免阻塞主线程
    func asyncInit() {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            let docsDir = DataFileIO.getDocsDir()
            let imagesDir = DataFileIO.getImagesDir()
            
            // 非主线程加载数据
            let profile: UserProfile? = DataFileIO.load(url: docsDir.appendingPathComponent("profile.json"))
            let grades: [Grade]? = DataFileIO.load(url: docsDir.appendingPathComponent("grades.json"))
            let mistakes: [MistakeNote]? = DataFileIO.load(url: docsDir.appendingPathComponent("mistakes.json"))
            let examsDecoder = JSONDecoder()
            examsDecoder.dateDecodingStrategy = .iso8601
            let exams: [Exam]? = DataFileIO.load(url: docsDir.appendingPathComponent("exams.json"), decoder: examsDecoder)
            let compExams: [comprehensiveExam]? = DataFileIO.load(url: docsDir.appendingPathComponent("comprehensiveExams.json"), decoder: examsDecoder)
            let subjects: [Subject]? = DataFileIO.load(url: docsDir.appendingPathComponent("subjects.json"))
            
            // 迁移内嵌图片
            var migratedGrades = grades ?? []
            var needsSave = false
            for i in 0..<migratedGrades.count {
                let grade = migratedGrades[i]
                if let imageData = grade.image, grade.imageFileName == nil {
                    let filename = "grade_\(grade.id.uuidString).jpg"
                    let url = imagesDir.appendingPathComponent(filename)
                    try? imageData.write(to: url)
                    migratedGrades[i].imageFileName = filename
                    migratedGrades[i].image = nil
                    needsSave = true
                }
            }
            if needsSave {
                let encoder = JSONEncoder()
                if let data = try? encoder.encode(migratedGrades) {
                    try? data.write(to: docsDir.appendingPathComponent("grades.json"))
                }
            }
            
            // 回到主线程更新 @Published
            await MainActor.run {
                if let p = profile { self.profile = p }
                self.grades = migratedGrades
                if let m = mistakes { self.mistakeSets = m }
                if let e = exams { self.examSets = e }
                if let c = compExams { self.comprehensiveExamSets = c }
                if let s = subjects { self.subjects = s }
                self.initializeDefaultSubjects()
            }
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
    func saveGradeImage(_ data: Data, gradeId: UUID) -> String? {
        let filename = "grade_\(gradeId.uuidString).jpg"
        let url = getImagesDirectory().appendingPathComponent(filename)
        do {
            try data.write(to: url)
            return filename
        } catch {
            print("Error saving grade image: \(error)")
            return nil
        }
    }
    
    /// 从文件系统加载 Grade 图片
    func loadGradeImage(filename: String) -> Data? {
        let url = getImagesDirectory().appendingPathComponent(filename)
        return try? Data(contentsOf: url)
    }
    
    /// 删除 Grade 图片文件
    func deleteGradeImage(filename: String) {
        let url = getImagesDirectory().appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }
    
    /// 保存用户头像到文件系统，返回文件名
    func saveAvatar(_ data: Data) -> String? {
        let filename = "avatar_\(UUID().uuidString).jpg"
        let url = getImagesDirectory().appendingPathComponent(filename)
        do {
            try data.write(to: url)
            // 如果之前有头像，删除旧文件
            if let oldFilename = profile.avatarFileName, oldFilename != filename {
                deleteAvatar(filename: oldFilename)
            }
            return filename
        } catch {
            print("Error saving avatar: \(error)")
            return nil
        }
    }
    
    /// 从文件系统加载用户头像
    func loadAvatar() -> Data? {
        guard let filename = profile.avatarFileName else { return nil }
        let url = getImagesDirectory().appendingPathComponent(filename)
        return try? Data(contentsOf: url)
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
        } catch {
            print("Error saving profile: \(error)")
        }
    }
    
    func loadProfile() {
        let url = getDocumentsDirectory().appendingPathComponent("profile.json")
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                profile = try decoder.decode(UserProfile.self, from: data)
            } catch {
                print("Error loading profile: \(error)")
            }
        }
    }
    
    /// 异步加载 profile
    func loadProfileAsync() async {
        let url = getDocumentsDirectory().appendingPathComponent("profile.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let loaded = try decoder.decode(UserProfile.self, from: data)
            await MainActor.run { profile = loaded }
        } catch {
            print("Error loading profile: \(error)")
        }
    }
    
    func saveGrades() {
        // 迁移：将内嵌图片写入文件系统
        for i in 0..<grades.count {
            if let imageData = grades[i].image, grades[i].imageFileName == nil {
                if let filename = saveGradeImage(imageData, gradeId: grades[i].id) {
                    grades[i].imageFileName = filename
                    grades[i].image = nil // 清除内嵌数据，减小 JSON 体积
                }
            }
        }
        
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(grades)
            let url = getDocumentsDirectory().appendingPathComponent("grades.json")
            try data.write(to: url)
        } catch {
            print("Error saving grades: \(error)")
        }
    }
    
    func loadGrades() {
        let url = getDocumentsDirectory().appendingPathComponent("grades.json")
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                grades = try decoder.decode([Grade].self, from: data)
                
                // 迁移：将旧数据的内嵌图片写入文件系统
                var needsSave = false
                for i in 0..<grades.count {
                    if let imageData = grades[i].image, grades[i].imageFileName == nil {
                        if let filename = saveGradeImage(imageData, gradeId: grades[i].id) {
                            grades[i].imageFileName = filename
                            grades[i].image = nil
                            needsSave = true
                        }
                    }
                }
                if needsSave { saveGrades() }
            } catch {
                print("Error loading grades: \(error)")
            }
        }
    }
    
    /// 异步加载 grades
    func loadGradesAsync() async {
        let url = getDocumentsDirectory().appendingPathComponent("grades.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let loaded = try decoder.decode([Grade].self, from: data)
            await MainActor.run { grades = loaded }
        } catch {
            print("Error loading grades: \(error)")
        }
    }
    
    func saveMistakeSets() {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(mistakeSets)
            let url = getDocumentsDirectory().appendingPathComponent("mistakes.json")
            try data.write(to: url)
        } catch {
            print("Error saving mistakes: \(error)")
        }
    }
    
    func loadMistakeSets() {
        let url = getDocumentsDirectory().appendingPathComponent("mistakes.json")
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                mistakeSets = try decoder.decode([MistakeNote].self, from: data)
            } catch {
                print("Error loading mistakes: \(error)")
            }
        }
    }
    
    /// 异步加载 mistakes
    func loadMistakeSetsAsync() async {
        let url = getDocumentsDirectory().appendingPathComponent("mistakes.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let loaded = try decoder.decode([MistakeNote].self, from: data)
            await MainActor.run { mistakeSets = loaded }
        } catch {
            print("Error loading mistakes: \(error)")
        }
    }
    
    // 新增：添加错题的方法
    func addMistake(_ mistake: MistakeNote) {
        mistakeSets.append(mistake)
        saveMistakeSets()
    }
    
    // 可选：删除错题的方法（方便后续扩展）
    func deleteMistake(at offsets: IndexSet, in set: inout [MistakeNote]) {
        set.remove(atOffsets: offsets)
        saveMistakeSets()
    }
    
    func deleteMistake(_ mistake: MistakeNote) {
        if let index = mistakeSets.firstIndex(where: { $0.id == mistake.id }) {
            mistakeSets.remove(at: index)
            saveMistakeSets()
        }
    }
    
    // 新增：更新错题的方法
    func updateMistake(_ updatedMistake: MistakeNote) {
        if let index = mistakeSets.firstIndex(where: { $0.id == updatedMistake.id }) {
            mistakeSets[index] = updatedMistake
            saveMistakeSets()
        } else {
            print("Warning: Could not find the mistake to update.")
        }
    }
    
    // 新增：保存考试集合
    func saveExamSets() {
        let encoder = JSONEncoder()
        // 设置日期编码策略，防止 Date 序列化问题
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(examSets)
            let url = getDocumentsDirectory().appendingPathComponent("exams.json")
            try data.write(to: url)
            print("[OK] Exams saved successfully.")
            
            // 同步到 Widget
            Task {
                WidgetDataSyncManager.syncUpcomingExams(
                    examSets: examSets,
                    comprehensiveExamSets: comprehensiveExamSets
                )
            }
        } catch {
            print("[ERROR] Error saving exams: \(error)")
        }
    }
    
    // 修改：加载考试集合 (确保主线程更新)
    func loadExamSets() {
        let url = getDocumentsDirectory().appendingPathComponent("exams.json")
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let loadedData = try decoder.decode([Exam].self, from: data)
                
                // 关键修改：确保在主线程更新 @Published 变量
                DispatchQueue.main.async {
                    self.examSets = loadedData
                    print("[OK] Exams loaded successfully.")
                }
            } catch {
                print("[ERROR] Error loading exams: \(error)")
            }
        }
    }
    
    func saveComprehensiveExams() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(comprehensiveExamSets)
            let url = getDocumentsDirectory().appendingPathComponent("comprehensiveExams.json")
            try data.write(to: url)
            print("[OK] 综合考试已保存")
            
            // 同步到 Widget
            Task {
                WidgetDataSyncManager.syncUpcomingExams(
                    examSets: examSets,
                    comprehensiveExamSets: comprehensiveExamSets
                )
            }
        } catch {
            print("保存综合考试失败: \(error)")
        }
    }
    
    // 新增：添加成绩的方法
    func addGrade(_ grade: Grade) {
        grades.append(grade)
        saveGrades()
    }
    
    // 新增：删除成绩的方法
    func deleteGrade(_ grade: Grade) {
        if let index = grades.firstIndex(where: { $0.id == grade.id }) {
            // 如果有图片文件，也删除它
            if let imageFileName = grade.imageFileName {
                let imagesDir = getDocumentsDirectory().appendingPathComponent("images")
                let fileURL = imagesDir.appendingPathComponent(imageFileName)
                try? FileManager.default.removeItem(at: fileURL)
            }
            
            grades.remove(at: index)
            saveGrades()
        }
    }
    
    // 新增：批量添加成绩的方法（用于导入）
    func addGrades(_ newGrades: [Grade]) {
        grades.append(contentsOf: newGrades)
        saveGrades()
    }
    
    // 新增：批量添加错题的方法（用于导入）
    func addMistakes(_ newMistakes: [MistakeNote]) {
        mistakeSets.append(contentsOf: newMistakes)
        saveMistakeSets()
    }
    
    // 新增：批量添加考试的方法（用于导入）
    func addExams(single: [Exam], comprehensive: [comprehensiveExam]) {
        examSets.append(contentsOf: single)
        comprehensiveExamSets.append(contentsOf: comprehensive)
        saveExamSets()
        saveComprehensiveExams()
    }
    
    // 修改：加载综合考试 (确保主线程更新)
    func loadComprehensiveExams() {
        let url = getDocumentsDirectory().appendingPathComponent("comprehensiveExams.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let loadedData = try decoder.decode([comprehensiveExam].self, from: data)
            
            // 关键修改：确保在主线程更新
            DispatchQueue.main.async {
                self.comprehensiveExamSets = loadedData
                print("[OK] 综合考试已加载")
            }
        } catch {
            print("加载综合考试失败: \(error)")
        }
    }
    
    func saveSubjects() {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(subjects)
            let url = getDocumentsDirectory().appendingPathComponent("subjects.json")
            try data.write(to: url)
        } catch {
            print("保存科目失败: \(error)")
        }
    }

    func loadSubjects() {
        let url = getDocumentsDirectory().appendingPathComponent("subjects.json")
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                subjects = try decoder.decode([Subject].self, from: data)
            } catch {
                print("加载科目失败: \(error)")
            }
        }
    }
    
}
