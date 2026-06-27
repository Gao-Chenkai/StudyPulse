//
//  FlashcardStudyView.swift
//  StudyPulse
//
//  全屏闪卡复习模式：Anki 风格翻牌 + 4 档自评
//
//  Created by Chenkai Gao on 2026/6/27.
//

import SwiftUI

// MARK: - Session Stats

/// 一次复习 session 的统计
struct FlashcardSessionStats: Equatable {
    var reviewed: Int = 0
    var again: Int = 0
    var hard: Int = 0
    var good: Int = 0
    var easy: Int = 0
    var startTime: Date = Date()
    var endTime: Date? = nil

    var totalRatings: Int { again + hard + good + easy }

    var durationString: String {
        let end = endTime ?? Date()
        let seconds = Int(end.timeIntervalSince(startTime))
        let m = seconds / 60
        let s = seconds % 60
        if m > 0 {
            return String(format: "%d min %d sec".localized(), m, s)
        }
        return String(format: "%d sec".localized(), s)
    }

    mutating func record(_ quality: ReviewQuality) {
        reviewed += 1
        switch quality {
        case .again: again += 1
        case .hard:  hard += 1
        case .good:  good += 1
        case .easy:  easy += 1
        }
    }
}

// MARK: - Flashcard Filter

/// FlashcardStudyView 的过滤模式
enum FlashcardFilter: Equatable {
    /// 默认：复习所有 due 错题
    case dueQueue
    /// 临时复习单张（不计 SM-2，仅标记）
    case single(MistakeNote)

    static func == (lhs: FlashcardFilter, rhs: FlashcardFilter) -> Bool {
        switch (lhs, rhs) {
        case (.dueQueue, .dueQueue):
            return true
        case (.single(let a), .single(let b)):
            return a.id == b.id
        default:
            return false
        }
    }
}

// MARK: - Flashcard Study View

/// 全屏闪卡复习入口
struct FlashcardStudyView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss

    let filter: FlashcardFilter

    @State private var queue: [MistakeNote] = []
    @State private var currentIndex: Int = 0
    @State private var isFlipped: Bool = false
    @State private var stats: FlashcardSessionStats = FlashcardSessionStats()
    @State private var showingSummary: Bool = false
    @State private var reinsertQueue: [MistakeNote] = []  // 「Again」的题目临时重插入
    @State private var showingCalculator: Bool = false  // 简易计算器浮层

    init(filter: FlashcardFilter = .dueQueue) {
        self.filter = filter
    }

    // MARK: - Computed

    private var currentMistake: MistakeNote? {
        guard currentIndex < queue.count else { return nil }
        return queue[currentIndex]
    }

    private var totalToReview: Int {
        queue.count + reinsertQueue.count
    }

    private var progress: Double {
        guard totalToReview > 0 else { return 0 }
        return Double(stats.reviewed) / Double(totalToReview)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                colors: [Color.purple.opacity(0.18), Color.blue.opacity(0.12), Color(.systemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if showingSummary {
                FlashcardSessionSummaryView(stats: stats) {
                    dismiss()
                }
            } else if queue.isEmpty && reinsertQueue.isEmpty {
                emptyState
            } else if let mistake = currentMistake {
                reviewContent(mistake: mistake)
            } else {
                // 队列走完但有 reinsert（不应该到这里，因为 onComplete 会 advance）
                FlashcardSessionSummaryView(stats: stats) {
                    dismiss()
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar { toolbar }
        .overlay(alignment: .topTrailing) { calculatorFAB }
        .overlay(alignment: .topTrailing) {
            if showingCalculator {
                FlashcardCalculatorView {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showingCalculator = false
                    }
                }
                .padding(.top, 60)
                .padding(.trailing, 12)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.7, anchor: .topTrailing).combined(with: .opacity),
                    removal: .scale(scale: 0.7, anchor: .topTrailing).combined(with: .opacity)
                ))
                .zIndex(10)
            }
        }
        .onAppear { loadQueue() }
    }

    /// 浮于右上角的「计算器」开关按钮
    private var calculatorFAB: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                showingCalculator.toggle()
            }
        } label: {
            Image(systemName: showingCalculator ? "function" : "function")
                .font(.subheadline.weight(.bold))
                .frame(width: 36, height: 36)
                .background(
                    Circle().fill(LinearGradient(
                        colors: showingCalculator
                            ? [.purple, .blue]
                            : [Color(.tertiarySystemBackground), Color(.secondarySystemBackground)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                )
                .foregroundStyle(showingCalculator ? .white : .primary)
                .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 3)
        }
        .accessibilityLabel("Calculator".localized())
        .padding(.top, 8)
        .padding(.trailing, 16)
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("No Mistakes Due".localized())
                .font(.title2.weight(.semibold))
            Text("Add mistakes to your review queue to start spaced repetition".localized())
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                dismiss()
            } label: {
                Text("Close".localized())
                    .frame(maxWidth: 200)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 12)
        }
        .frame(maxWidth: 500)
    }

    @ViewBuilder
    private func reviewContent(mistake: MistakeNote) -> some View {
        VStack(spacing: 0) {
            // 顶部进度条
            VStack(spacing: 8) {
                HStack {
                    Text(String(format: "%d / %d".localized(), stats.reviewed, totalToReview))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "Time: %@".localized(), stats.durationString))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(.purple)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)

            // 主卡片
            FlashcardCardView(mistake: mistake, isFlipped: $isFlipped)
                .frame(maxWidth: 720)
                .padding(.horizontal, 20)
                .padding(.vertical, 20)

            // 底部操作区
            if isFlipped {
                ReviewActionsRow { quality in
                    handleRating(quality)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            } else {
                Button {
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                        isFlipped = true
                    }
                } label: {
                    Label("Show Answer".localized(), systemImage: "eye.fill")
                        .font(.headline)
                        .frame(maxWidth: 400)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                .transition(.opacity)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                finishSession()
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.semibold))
            }
            .accessibilityLabel("Close".localized())
        }
    }

    // MARK: - Actions

    private func loadQueue() {
        switch filter {
        case .dueQueue:
            queue = SRSAlgorithm.dueMistakes(from: dataManager.mistakeSets)
        case .single(let note):
            queue = [note]
        }
        currentIndex = 0
        isFlipped = false
        stats = FlashcardSessionStats()
        reinsertQueue = []
    }

    private func handleRating(_ quality: ReviewQuality) {
        guard let current = currentMistake else { return }
        stats.record(quality)

        // 应用 SM-2（仅在 .dueQueue 模式下计入，单题模式只标记已复习）
        switch filter {
        case .dueQueue:
            if var state = current.reviewState {
                state = SRSAlgorithm.apply(quality: quality, to: state)
                dataManager.updateMistakeReviewState(current.id, newState: state)
            }
        case .single:
            // 单题模式：只把 nextReviewDate 推后 1 天
            if var state = current.reviewState {
                state.lastReviewDate = Date()
                if let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: Date()) {
                    state.nextReviewDate = nextDay
                }
                dataManager.updateMistakeReviewState(current.id, newState: state)
            }
        }

        // 「Again」立即重插入队尾（确保至少复习一次）
        if quality == .again && filter == .dueQueue {
            reinsertQueue.append(current)
        }

        // 推进到下一张
        advance()
    }

    private func advance() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isFlipped = false
        }
        // 简单实现：移除当前并显示下一张
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if currentIndex < queue.count - 1 {
                currentIndex += 1
            } else {
                // 走完了；如果有 reinsert 就接上
                if !reinsertQueue.isEmpty {
                    queue = reinsertQueue
                    reinsertQueue = []
                    currentIndex = 0
                } else {
                    finishSession()
                }
            }
        }
    }

    private func finishSession() {
        stats.endTime = Date()
        withAnimation(.easeInOut(duration: 0.3)) {
            showingSummary = true
        }
        // 通知全部重调度
        SRSReviewNotifications.shared.rescheduleAll(mistakes: dataManager.mistakeSets)
    }
}

// MARK: - Review Actions Row

/// 底部 4 档自评按钮行
struct ReviewActionsRow: View {
    let onRate: (ReviewQuality) -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text("How well did you remember?".localized())
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(ReviewQuality.allCases) { quality in
                    Button {
                        onRate(quality)
                    } label: {
                        VStack(spacing: 4) {
                            Text(quality.shortTitle)
                                .font(.subheadline.weight(.bold))
                            Text(quality.description)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(quality.color.opacity(0.15))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(quality.color.opacity(0.45), lineWidth: 1)
                        )
                        .foregroundStyle(quality.color)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: 720)
    }
}
