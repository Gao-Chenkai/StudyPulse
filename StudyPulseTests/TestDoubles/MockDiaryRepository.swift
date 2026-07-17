//
//  MockDiaryRepository.swift
//  StudyPulseTests
//
//  DiaryRepository 的纯内存 Mock 测试替身。
//  In-memory mock implementation of DiaryRepository for unit tests.
//

import Foundation
import SwiftData
@testable import StudyPulse

@MainActor
final class MockDiaryRepository: DiaryRepository, @unchecked Sendable {
    var diaryEntries: [DiaryEntry] = []
    var filteredDiaryEntries: [DiaryEntry] = []

    // MARK: - 调用状态追踪 / Call tracking

    var loadAllCalledCount = 0
    var addCalledCount = 0
    var updateCalledCount = 0
    var deleteCalledCount = 0
    var clearAllCalledCount = 0

    init(entries: [DiaryEntry] = [], filteredEntries: [DiaryEntry]? = nil) {
        self.diaryEntries = entries
        self.filteredDiaryEntries = filteredEntries ?? entries
    }

    func loadAll(context: ModelContext) async {
        loadAllCalledCount += 1
    }

    func add(_ entry: DiaryEntry) {
        addCalledCount += 1
        diaryEntries.insert(entry, at: 0)
        filteredDiaryEntries.insert(entry, at: 0)
    }

    func update(_ entry: DiaryEntry) {
        updateCalledCount += 1
        if let idx = diaryEntries.firstIndex(where: { $0.id == entry.id }) {
            diaryEntries[idx] = entry
        }
        if let idx = filteredDiaryEntries.firstIndex(where: { $0.id == entry.id }) {
            filteredDiaryEntries[idx] = entry
        }
    }

    func delete(_ entry: DiaryEntry) {
        deleteCalledCount += 1
        diaryEntries.removeAll { $0.id == entry.id }
        filteredDiaryEntries.removeAll { $0.id == entry.id }
    }

    @discardableResult
    func clearAll() -> Int {
        clearAllCalledCount += 1
        let count = diaryEntries.count
        diaryEntries.removeAll()
        filteredDiaryEntries.removeAll()
        return count
    }

    func entriesInRange(_ start: Date, _ end: Date) -> [DiaryEntry] {
        diaryEntries.filter { $0.date >= start && $0.date < end }
            .sorted { $0.date < $1.date }
    }

    func todayEntry() -> DiaryEntry? {
        let todayStart = Calendar.current.startOfDay(for: .now)
        let todayEnd = Calendar.current.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart
        return entriesInRange(todayStart, todayEnd).last
    }
}
