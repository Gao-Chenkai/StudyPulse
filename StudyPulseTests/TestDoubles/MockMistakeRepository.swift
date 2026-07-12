//
//  MockMistakeRepository.swift
//  StudyPulseTests
//
//  MistakeRepository 的纯内存 Mock 测试替身。
//  In-memory mock implementation of MistakeRepository for unit tests.
//

import Foundation
import SwiftData
@testable import StudyPulse

@MainActor
final class MockMistakeRepository: MistakeRepository, @unchecked Sendable {
    var mistakeSets: [MistakeNote] = []
    var filteredMistakeSets: [MistakeNote] = []

    // MARK: - 调用状态追踪

    var loadAllCalledCount = 0
    var addCalledCount = 0
    var updateCalledCount = 0
    var deleteCalledCount = 0
    var clearAllCalledCount = 0
    var updateReviewStateCalledCount = 0
    var recordExposureCalledCount = 0
    var recordReviewCalledCount = 0
    var recordHandwritingCalledCount = 0

    var lastRecordedQuality: ReviewQuality?
    var lastRecordedHandwritingData: Data?

    init(mistakes: [MistakeNote] = [], filteredMistakes: [MistakeNote]? = nil) {
        self.mistakeSets = mistakes
        self.filteredMistakeSets = filteredMistakes ?? mistakes
    }

    func loadAll(context: ModelContext) async {
        loadAllCalledCount += 1
    }

    func add(_ mistake: MistakeNote) {
        addCalledCount += 1
        mistakeSets.insert(mistake, at: 0)
        filteredMistakeSets.insert(mistake, at: 0)
    }

    func add(_ newMistakes: [MistakeNote]) {
        addCalledCount += 1
        mistakeSets.insert(contentsOf: newMistakes, at: 0)
        filteredMistakeSets.insert(contentsOf: newMistakes, at: 0)
    }

    func update(_ mistake: MistakeNote) {
        updateCalledCount += 1
        if let idx = mistakeSets.firstIndex(where: { $0.id == mistake.id }) {
            mistakeSets[idx] = mistake
        }
        if let idx = filteredMistakeSets.firstIndex(where: { $0.id == mistake.id }) {
            filteredMistakeSets[idx] = mistake
        }
    }

    func delete(_ mistake: MistakeNote) {
        deleteCalledCount += 1
        mistakeSets.removeAll { $0.id == mistake.id }
        filteredMistakeSets.removeAll { $0.id == mistake.id }
    }

    func delete(at offsets: IndexSet, in set: inout [MistakeNote]) {
        deleteCalledCount += 1
        let toRemove = offsets.map { set[$0].id }
        set.remove(atOffsets: offsets)
        mistakeSets.removeAll { toRemove.contains($0.id) }
        filteredMistakeSets.removeAll { toRemove.contains($0.id) }
    }

    func clearAll() -> Int {
        clearAllCalledCount += 1
        let count = mistakeSets.count
        mistakeSets.removeAll()
        filteredMistakeSets.removeAll()
        return count
    }

    func updateReviewState(_ mistakeId: UUID, newState: ReviewState?) {
        updateReviewStateCalledCount += 1
        if let idx = mistakeSets.firstIndex(where: { $0.id == mistakeId }) {
            mistakeSets[idx].reviewState = newState
        }
        if let idx = filteredMistakeSets.firstIndex(where: { $0.id == mistakeId }) {
            filteredMistakeSets[idx].reviewState = newState
        }
    }

    func recordExposure(_ mistakeId: UUID) {
        recordExposureCalledCount += 1
        if let idx = mistakeSets.firstIndex(where: { $0.id == mistakeId }) {
            mistakeSets[idx].exposureCount += 1
        }
        if let idx = filteredMistakeSets.firstIndex(where: { $0.id == mistakeId }) {
            filteredMistakeSets[idx].exposureCount += 1
        }
    }

    func recordReview(_ mistakeId: UUID, quality: ReviewQuality, now: Date) {
        recordReviewCalledCount += 1
        lastRecordedQuality = quality
        recordExposure(mistakeId)
    }

    func recordHandwriting(_ mistakeId: UUID, pngData: Data, quality: ReviewQuality?, now: Date) {
        recordHandwritingCalledCount += 1
        lastRecordedHandwritingData = pngData
        lastRecordedQuality = quality
        if let idx = mistakeSets.firstIndex(where: { $0.id == mistakeId }) {
            let entry = HandwritingAnswerEntry(id: UUID(), timestamp: now, imageData: pngData, quality: quality?.rawValue ?? 0)
            mistakeSets[idx].handwritingHistory.append(entry)
        }
        if let idx = filteredMistakeSets.firstIndex(where: { $0.id == mistakeId }) {
            let entry = HandwritingAnswerEntry(id: UUID(), timestamp: now, imageData: pngData, quality: quality?.rawValue ?? 0)
            filteredMistakeSets[idx].handwritingHistory.append(entry)
        }
    }

    func allTags() -> [String] {
        var set = Set<String>()
        for note in mistakeSets {
            for tag in note.tags {
                set.insert(tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
            }
        }
        return set.sorted()
    }

    func tagCounts() -> [(tag: String, count: Int)] {
        var counts: [String: Int] = [:]
        for note in mistakeSets {
            for tag in note.tags {
                let clean = tag.trimmingCharacters(in: .whitespacesAndNewlines)
                if !clean.isEmpty {
                    counts[clean, default: 0] += 1
                }
            }
        }
        return counts.map { (tag: $0.key, count: $0.value) }.sorted { $0.count > $1.count }
    }
}
