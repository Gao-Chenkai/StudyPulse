//
//  DataManager.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import Foundation
import Combine
import SwiftUI

class DataManager: ObservableObject {
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
    
    func saveGrades() {
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
            } catch {
                print("Error loading grades: \(error)")
            }
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
        if let index = mistakeSets.firstIndex(where: { $0.title == mistake.title && $0.date == mistake.date }) {
            mistakeSets.remove(at: index)
            saveMistakeSets()
        }
    }
    
    // ✅ 新增：更新错题的方法
    func updateMistake(_ updatedMistake: MistakeNote) {
        // 查找原数据在数组中的位置 (假设通过 title 和 date 唯一标识，或者你有 id)
        // ⚠️ 注意：如果你的 MistakeNote 有唯一的 id 属性，请用 id 查找，更稳妥
        if let index = mistakeSets.firstIndex(where: {
            $0.title == updatedMistake.title && $0.date == updatedMistake.date
        }) {
            mistakeSets[index] = updatedMistake
            saveMistakeSets() // 保存到新文件
        } else {
            print("⚠️ Warning: Could not find the mistake to update.")
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
