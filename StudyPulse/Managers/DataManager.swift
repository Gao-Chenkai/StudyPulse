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
    @Published var profile: UserProfile = UserProfile()
    
    init() {
        loadProfile()
        loadGrades()
        loadMistakeSets()
        initializeDefaultSubjects()
    }
    
    private func initializeDefaultSubjects() {
        if subjects.isEmpty {
            subjects = [
                Subject(name: "Chinese", enabled: true),
                Subject(name: "Mathematics", enabled: true),
                Subject(name: "English", enabled: true),
                Subject(name: "Physics", enabled: true),
                Subject(name: "Chemistry", enabled: true),
                Subject(name: "Biology", enabled: true),
                Subject(name: "History", enabled: true),
                Subject(name: "Geography", enabled: true),
                Subject(name: "Politics", enabled: true),
                Subject(name: "Information Technology", enabled: true),
                Subject(name: "General Technology", enabled: true),
                Subject(name: "Art", enabled: true),
                Subject(name: "Music", enabled: true),
                Subject(name: "PE & Health", enabled: true)
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
}
