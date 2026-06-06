//
//  DataManager.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import Foundation
import Combine
import SwiftUI

/// 后台线程安全的文件 I/O 工具（放在独立类型中避免 @MainActor 推断）
nonisolated enum DataFileIO {
    static func getDocsDir() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    static func getImagesDir() -> URL {
        let url = getDocsDir().appendingPathComponent("images")
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }
    
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

class DataManager: ObservableObject {
    static let shared = DataManager()
    
    @Published var grades: [Grade] = []
    @Published var subjects: [Subject] = []
    @Published var mistakeSets: [MistakeNote] = []
    @Published var examSets: [Exam] = []
    @Published var profile: UserProfile = UserProfile()
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
            subjects = [
                Subject(name: "Chinese"),
                Subject(name: "Mathematics"),
                Subject(name: "English"),
                Subject(name: "Science"),
                Subject(name: "History & Society"),
                Subject(name: "Physics"),
                Subject(name: "Chemistry"),
                Subject(name: "Biology"),
                Subject(name: "History"),
                Subject(name: "Geography"),
                Subject(name: "Politics"),
                Subject(name: "Information Technology"),
                Subject(name: "General Technology"),
                Subject(name: "Art"),
                Subject(name: "Music"),
                Subject(name: "PE & Health")
            ]
        }
    }
    
    // 存储和加载方法
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
    
    // ✅ 新增：添加错题的方法
    func addMistake(_ mistake: MistakeNote) {
        mistakeSets.append(mistake)
        saveMistakeSets()
    }
    
    // ✅ 可选：删除错题的方法（方便后续扩展）
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
    
    // ✅ 新增：更新错题的方法
    func updateMistake(_ updatedMistake: MistakeNote) {
        if let index = mistakeSets.firstIndex(where: { $0.id == updatedMistake.id }) {
            mistakeSets[index] = updatedMistake
            saveMistakeSets()
        } else {
            print("Warning: Could not find the mistake to update.")
        }
    }
    
    // ✅ 新增：保存考试集合
    func saveExamSets() {
        let encoder = JSONEncoder()
        // 设置日期编码策略，防止 Date 序列化问题
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(examSets)
            let url = getDocumentsDirectory().appendingPathComponent("exams.json")
            try data.write(to: url)
            print("✅ Exams saved successfully.")
        } catch {
            print("❌ Error saving exams: \(error)")
        }
    }
    
    // ✅ 修改：加载考试集合 (确保主线程更新)
    func loadExamSets() {
        let url = getDocumentsDirectory().appendingPathComponent("exams.json")
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let loadedData = try decoder.decode([Exam].self, from: data)
                
                // 👇 关键修改：确保在主线程更新 @Published 变量
                DispatchQueue.main.async {
                    self.examSets = loadedData
                    print("✅ Exams loaded successfully.")
                }
            } catch {
                print("❌ Error loading exams: \(error)")
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
            print("✅ 综合考试已保存")
        } catch {
            print("保存综合考试失败: \(error)")
        }
    }
    
    // ✅ 修改：加载综合考试 (确保主线程更新)
    func loadComprehensiveExams() {
        let url = getDocumentsDirectory().appendingPathComponent("comprehensiveExams.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let loadedData = try decoder.decode([comprehensiveExam].self, from: data)
            
            // 👇 关键修改：确保在主线程更新
            DispatchQueue.main.async {
                self.comprehensiveExamSets = loadedData
                print("✅ 综合考试已加载")
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
