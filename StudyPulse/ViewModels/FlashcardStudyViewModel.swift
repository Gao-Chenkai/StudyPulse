//
//  FlashcardStudyViewModel.swift
//  StudyPulse
//
//  Created by Antigravity on 2026/7/12.
//

import Foundation
import SwiftUI
import Combine
import PencilKit
import os

@MainActor
final class FlashcardStudyViewModel: ObservableObject {
    // MARK: - Dependencies
    private let container: RepositoryContainer
    let filter: FlashcardFilter

    // MARK: - Output States
    @Published var queue: [MistakeNote] = []
    @Published var currentIndex: Int = 0
    @Published var isFlipped: Bool = false
    @Published var stats: FlashcardSessionStats = FlashcardSessionStats()
    @Published var showingSummary: Bool = false
    @Published var reinsertQueue: [MistakeNote] = []
    @Published var showingCalculator: Bool = false
    @Published var handwritingEnabled: Bool = false
    @Published var currentDrawing: PKDrawing = PKDrawing()
    @Published var sessionHandwriting: [UUID: Data] = [:]
    @Published var hasSubmittedCurrent: Bool = false
    @Published var showHandwritingRequiredAlert: Bool = false

    // MARK: - Init
    init(container: RepositoryContainer, filter: FlashcardFilter, handwritingEnabled: Bool = false) {
        self.container = container
        self.filter = filter
        self.handwritingEnabled = handwritingEnabled
        loadQueue()
    }

    // MARK: - Computed Properties
    var currentMistake: MistakeNote? {
        guard currentIndex < queue.count else { return nil }
        return queue[currentIndex]
    }

    var totalToReview: Int {
        queue.count + reinsertQueue.count
    }

    var progress: Double {
        guard totalToReview > 0 else { return 0 }
        return Double(stats.reviewed) / Double(totalToReview)
    }

    // MARK: - Actions
    func loadQueue() {
        switch filter {
        case .dueQueue:
            queue = SRSAlgorithm.dueMistakes(from: container.mistakeRepo.mistakeSets)
        case .single(let note):
            queue = [note]
        case .tag(let tag):
            let due = SRSAlgorithm.dueMistakes(from: container.mistakeRepo.mistakeSets)
            queue = MistakeFilter.tagged(due, tag: tag)
        }
        currentIndex = 0
        isFlipped = false
        stats = FlashcardSessionStats()
        reinsertQueue = []
        handwritingEnabled = false
        currentDrawing = PKDrawing()
        hasSubmittedCurrent = false
        sessionHandwriting = [:]
    }

    func toggleHandwriting() {
        handwritingEnabled.toggle()
        if !handwritingEnabled {
            currentDrawing = PKDrawing()
            hasSubmittedCurrent = false
            if let id = currentMistake?.id {
                sessionHandwriting.removeValue(forKey: id)
            }
        }
    }

    func submitHandwriting(pngData: Data) {
        guard let id = currentMistake?.id else { return }
        sessionHandwriting[id] = pngData
        hasSubmittedCurrent = true
        Log.view.info("FlashcardStudyViewModel handwriting submitted: mistakeId=\(id.uuidString, privacy: .public) bytes=\(pngData.count, privacy: .public)")
    }

    func clearHandwriting() {
        guard let id = currentMistake?.id else { return }
        currentDrawing = PKDrawing()
        hasSubmittedCurrent = false
        sessionHandwriting.removeValue(forKey: id)
    }

    func handleRating(_ quality: ReviewQuality) {
        guard let current = currentMistake else { return }
        stats.record(quality)

        switch filter {
        case .dueQueue, .tag:
            if var state = current.reviewState {
                state = SRSAlgorithm.apply(quality: quality, to: state, difficulty: current.difficulty)
                container.mistakeRepo.updateReviewState(current.id, newState: state)
            }
        case .single:
            if var state = current.reviewState {
                state.lastReviewDate = Date()
                if let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: Date()) {
                    state.nextReviewDate = nextDay
                }
                container.mistakeRepo.updateReviewState(current.id, newState: state)
            }
        }

        container.mistakeRepo.recordReview(current.id, quality: quality, now: Date())

        if handwritingEnabled, let png = sessionHandwriting[current.id] {
            container.mistakeRepo.recordHandwriting(current.id, pngData: png, quality: quality, now: Date())
        }

        if quality == .again, !filter.isSingleMode {
            reinsertQueue.append(current)
        }

        advance()
    }

    private func advance() {
        isFlipped = false
        let prevId = currentMistake?.id
        currentDrawing = PKDrawing()
        hasSubmittedCurrent = false
        if let id = prevId {
            sessionHandwriting.removeValue(forKey: id)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if self.currentIndex < self.queue.count - 1 {
                self.currentIndex += 1
            } else {
                if !self.reinsertQueue.isEmpty {
                    self.queue = self.reinsertQueue
                    self.reinsertQueue = []
                    self.currentIndex = 0
                } else {
                    self.finishSession()
                }
            }
        }
    }

    func finishSession() {
        stats.endTime = Date()
        showingSummary = true
        SRSReviewNotifications.shared.rescheduleAll(mistakes: container.mistakeRepo.mistakeSets)
    }
}
