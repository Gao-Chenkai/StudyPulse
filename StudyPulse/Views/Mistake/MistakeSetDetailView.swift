//
//  MistakeSetDetailView.swift
//  StudyPulse
//
//  Created for the MistakeView refactoring.
//

import SwiftUI
import UIKit
import SwiftStreamingMarkdown

struct MistakeSetDetailView: View {
    let mistakeSet: MistakeNote
    @Environment(RepositoryContainer.self) private var container
    @EnvironmentObject var envManager: AppEnvironmentManager
    @State private var showingEditSheet = false
    @State private var showingQuickReview = false
    @State private var showingAIAnalysis = false
    @State private var showingAIDiscussion = false
    @State private var showingAISimilarQuestion = false
    @State private var lastAIAnalysis: String? = nil

    private var liveMistake: MistakeNote {
        container.mistakeRepo.mistakeSets.first(where: { $0.id == mistakeSet.id }) ?? mistakeSet
    }

    var body: some View {
        List {
            // 掌握度曲线 / 曝光统计
            Section {
                MasteryCurveView(
                    history: liveMistake.masteryHistory,
                    currentScore: liveMistake.masteryScore,
                    exposureCount: liveMistake.exposureCount,
                    createdAt: liveMistake.date,
                    tintColor: envManager.effectiveAccentColor
                )
                .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                .listRowBackground(Color.clear)
            }

            // Basic Info Section
            Section(header: Text("Details".localized())) {
                HStack {
                    Text("Title".localized())
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(liveMistake.title)
                        .fontWeight(.medium)
                }

                if !liveMistake.subject.isEmpty {
                    HStack {
                        Text("Subject".localized())
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(liveMistake.subject.localized())
                            .fontWeight(.medium)
                    }
                }

                if !liveMistake.source.isEmpty {
                    HStack {
                        Text("Source".localized())
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(liveMistake.source)
                    }
                }

                HStack {
                    Text("Date".localized())
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(liveMistake.date.formatted(date: .abbreviated, time: .omitted))
                }

                // 难度自评
                if liveMistake.difficulty > 0 {
                    HStack {
                        Text("Difficulty".localized())
                            .foregroundColor(.secondary)
                        Spacer()
                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { i in
                                Image(systemName: i <= liveMistake.difficulty ? "star.fill" : "star")
                                    .font(.caption2)
                                    .foregroundStyle(i <= liveMistake.difficulty ? Color.orange : Color.gray.opacity(0.4))
                            }
                        }
                    }
                }

                // 标签(只读)
                if !liveMistake.tags.isEmpty {
                    HStack(alignment: .top) {
                        Text("Tags".localized())
                            .foregroundColor(.secondary)
                        Spacer()
                        TagChipsView(tags: liveMistake.tags, compact: true)
                            .frame(maxWidth: 240, alignment: .trailing)
                    }
                }
                
                // 语音备忘录
                if let audioFileName = liveMistake.audioFileName {
                    AudioPlaybackView(audioFileName: audioFileName, onDelete: nil)
                        .padding(.top, 4)
                }
            }
            
            // Question Section
            if !liveMistake.originalQuestion.isEmpty {
                Section(header: Text("Original Question".localized())) {
                    MarkdownView(
                        text: liveMistake.originalQuestion.normalisingSingleDollarMath(),
                        config: .previewConfig
                    )
                    .fixedSize(horizontal: false, vertical: true)

                    if !liveMistake.questionImages.isEmpty {
                        imageScrollView(images: liveMistake.questionImages)
                    }
                }
            }

            // Error Reason Section
            if !liveMistake.errorReason.isEmpty {
                Section(header: Text("Error Reason".localized())) {
                    MarkdownView(
                        text: liveMistake.errorReason.normalisingSingleDollarMath(),
                        config: .previewConfig
                    )
                    .fixedSize(horizontal: false, vertical: true)

                    if !liveMistake.reasonImages.isEmpty {
                        imageScrollView(images: liveMistake.reasonImages)
                    }
                }
            }

            // Wrong Solution Section
            if !liveMistake.wrongSolution.isEmpty {
                Section {
                    MarkdownView(
                        text: liveMistake.wrongSolution.normalisingSingleDollarMath(),
                        config: .previewConfig
                    )
                    .fixedSize(horizontal: false, vertical: true)

                    if !liveMistake.wrongSolutionImages.isEmpty {
                        imageScrollView(images: liveMistake.wrongSolutionImages)
                    }
                } header: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text("Wrong Solution".localized())
                    }
                }
            }

            // Correct Solution Section
            if !liveMistake.correctSolution.isEmpty {
                Section {
                    MarkdownView(
                        text: liveMistake.correctSolution.normalisingSingleDollarMath(),
                        config: .previewConfig
                    )
                    .fixedSize(horizontal: false, vertical: true)

                    if !liveMistake.correctSolutionImages.isEmpty {
                        imageScrollView(images: liveMistake.correctSolutionImages)
                    }
                } header: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Correct Solution".localized())
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(liveMistake.title)
        .navigationBarTitleDisplayMode(.inline)
        .adaptiveMaxWidth(820)
        .toolbar {
            MistakeDetailToolbar(
                liveMistake: liveMistake,
                isLLMConfigured: envManager.llmConfig.isConfigured,
                onEdit: { showingEditSheet = true },
                onQuickReview: { showingQuickReview = true },
                onAIAnalysis: { showingAIAnalysis = true },
                onAISimilarQuestion: { showingAISimilarQuestion = true }
            )
        }
        .sheet(isPresented: $showingEditSheet) {
            MistakeDetailEditView(container: container, mistakeSet: liveMistake)
                .adaptiveSheet()
        }
        .sheet(isPresented: $showingAIAnalysis) {
            MistakeAIAnalysisSheet(
                subject: liveMistake.subject,
                title: liveMistake.title,
                question: liveMistake.originalQuestion,
                wrongSolution: liveMistake.wrongSolution,
                correctSolution: liveMistake.correctSolution,
                reason: liveMistake.errorReason,
                onInsert: { insight in
                    var updated = liveMistake
                    let trimmed = insight.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        if updated.correctSolution.isEmpty {
                            updated.correctSolution = trimmed
                        } else {
                            updated.correctSolution += "\n\n---\n\n" + trimmed
                        }
                        container.mistakeRepo.update(updated)
                    }
                },
                onAnalysisComplete: { fullText in
                    lastAIAnalysis = fullText
                },
                onDiscuss: { context, lastAnalysis in
                    showingAIAnalysis = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showingAIDiscussion = true
                    }
                }
            )
            .environmentObject(envManager)
            .adaptiveSheet()
        }
        .sheet(isPresented: $showingAIDiscussion) {
            AIDiscussionSheet(
                title: "AI 解析 · 深入探讨".localized(),
                context: buildMistakeDiscussionContext(),
                initialAssistantMessage: lastAIAnalysis,
                onDismiss: { showingAIDiscussion = false }
            )
            .environmentObject(envManager)
            .adaptiveSheet(detents: [.large])
        }
        .sheet(isPresented: $showingAISimilarQuestion) {
            AISimilarQuestionFlowView(originalMistake: liveMistake)
                .environment(container)
                .environmentObject(envManager)
                .adaptiveSheet()
        }
        .fullScreenCover(isPresented: $showingQuickReview) {
            NavigationStack {
                FlashcardStudyView(container: container, filter: .single(liveMistake))
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                showingQuickReview = false
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .accessibilityLabel("Close".localized())
                        }
                    }
            }
        }
        .onAppear {
            container.mistakeRepo.recordExposure(mistakeSet.id)
        }
    }
    
    @ViewBuilder
    private func imageScrollView(images: [Data]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(images.indices, id: \.self) { index in
                    ThumbnailImageView(data: images[index])
                        .frame(width: 150, height: 150)
                        .clipped()
                        .cornerRadius(8)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func buildMistakeDiscussionContext() -> String {
        let m = liveMistake
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        var lines: [String] = []
        lines.append("错题 ID:\(m.id.uuidString)")
        lines.append("学科:\(m.subject.isEmpty ? "(无)" : m.subject)")
        lines.append("标题:\(m.title)")
        lines.append("来源:\(m.source.isEmpty ? "(无)" : m.source)")
        lines.append("日期:\(f.string(from: m.date))")
        lines.append("难度:\(m.difficulty)/5")
        lines.append("掌握度:\(String(format: "%.0f%%", m.masteryScore * 100))")
        lines.append("曝光次数:\(m.exposureCount)")
        if !m.tags.isEmpty {
            lines.append("标签:\(m.tags.joined(separator: ", "))")
        }
        func block(_ title: String, _ body: String) {
            if !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lines.append("")
                lines.append("--- \(title) ---")
                lines.append(body)
            }
        }
        block("原题", m.originalQuestion)
        block("错因", m.errorReason)
        block("错误解法", m.wrongSolution)
        block("正确解法", m.correctSolution)
        if let last = lastAIAnalysis, !last.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("")
            lines.append("--- 上一次 AI 解析(只读) ---")
            lines.append(last)
        }
        return lines.joined(separator: "\n")
    }
}

struct ThumbnailImageView: View {
    let data: Data
    @State private var uiImage: UIImage?
    
    var body: some View {
        Group {
            if let image = uiImage {
                ZoomableImageView(image: image)
            } else {
                ProgressView()
                    .task {
                        await loadImage()
                    }
            }
        }
    }
    
    private func loadImage() async {
        if let cached = ImageCache.shared.getImage(data) {
            uiImage = cached
            return
        }
        let task = Task.detached(priority: .userInitiated) {
            ImageCache.thumbnail(from: data, maxDimension: 300)
        }
        let thumbnail = await task.value
        guard let thumb = thumbnail else { return }
        ImageCache.shared.putImage(thumb, data)
        await MainActor.run { uiImage = thumb }
    }
}

struct SuggestedMistakeCard: View {
    let mistake: MistakeNote
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var animateIn = false

    var reviewPriority: String {
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()

        if mistake.date > oneWeekAgo {
            return "🔴 High Priority".localized()
        } else if mistake.date < oneMonthAgo {
            return "🟡 Review Soon".localized()
        } else {
            return "🟢 Normal".localized()
        }
    }

    var daysSinceAdded: String {
        let components = Calendar.current.dateComponents([.day], from: mistake.date, to: Date())
        let days = components.day ?? 0
        if days == 0 {
            return "Today".localized()
        } else if days == 1 {
            return "Yesterday".localized()
        } else {
            return "\(days) " + "days ago".localized()
        }
    }

    private var cardWidth: CGFloat {
        sizeClass == .regular ? 220 : 180
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)

                Text(reviewPriority)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                Spacer()

                if mistake.difficulty > 0 {
                    HStack(spacing: 1) {
                        ForEach(1...5, id: \.self) { i in
                            Image(systemName: i <= mistake.difficulty ? "star.fill" : "star")
                                .font(.system(size: 9))
                                .foregroundStyle(i <= mistake.difficulty ? Color.orange : Color.gray.opacity(0.3))
                        }
                    }
                }
            }

            Text(mistake.title)
                .font(.headline)
                .foregroundColor(.primary)
                .lineLimit(1)

            if !mistake.subject.isEmpty {
                Text(mistake.subject.localized())
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(.systemPurple).opacity(0.15))
                    .foregroundColor(Color(.systemPurple))
                    .cornerRadius(4)
            }

            if !mistake.tags.isEmpty {
                TagChipsView(tags: mistake.tags, compact: true, maxVisible: 2)
            }

            if !mistake.originalQuestion.isEmpty {
                Text(mistake.originalQuestion)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            HStack {
                Text(daysSinceAdded)
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .frame(width: cardWidth)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .opacity(animateIn ? 1 : 0)
        .offset(x: animateIn ? 0 : -20)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.1)) {
                animateIn = true
            }
        }
    }
}
