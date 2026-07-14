//
//  MistakeSetDetailView.swift
//  StudyPulse
//
//  错题详情页:展示 + AI 入口(快速复习 / AI 解析 / 深入探讨 / 同类题)。
//  顶部 MasteryCurveView 展示掌握度曲线,下方是字段列表 + 题图。
//
//  Mistake detail page: display + AI entry points (quick review / AI
//  analysis / deep discussion / similar question).
//  Top of the page is the MasteryCurveView; below it is a field list
//  and the question image(s).
//

import SwiftUI
import UIKit
import SwiftStreamingMarkdown

/// 错题详情页:由 `MistakeView` 推入,集中展示错题字段 + 多个 AI 入口。
/// Mistake detail page: pushed by `MistakeView`, shows the mistake's
/// fields plus a range of AI entry points.
struct MistakeSetDetailView: View {
    /// 传入的错题(以 id 为准从 repo 拿最新数据)
    /// Injected mistake (uses the id to fetch the latest copy from the repo).
    let mistakeSet: MistakeNote
    @Environment(RepositoryContainer.self) private var container
    @EnvironmentObject var envManager: AppEnvironmentManager
    /// 是否弹出编辑 sheet
    /// Whether to present the edit sheet.
    @State private var showingEditSheet = false
    /// 是否弹出快速复习 sheet
    /// Whether to present the quick-review sheet.
    @State private var showingQuickReview = false
    /// 是否弹出 AI 解析 sheet
    /// Whether to present the AI analysis sheet.
    @State private var showingAIAnalysis = false
    /// 是否弹出 AI 深入讨论 sheet
    /// Whether to present the deep-discussion sheet.
    @State private var showingAIDiscussion = false
    /// 是否弹出 AI 同类题 sheet
    /// Whether to present the similar-question sheet.
    @State private var showingAISimilarQuestion = false
    /// 最近一次成功的 AI 解析(供"深入讨论"sheet 当作 initial assistant 消息)
    /// Most recent successful AI analysis (used as the initial assistant
    /// message in the deep-discussion sheet).
    @State private var lastAIAnalysis: String? = nil

    /// 实时从 repo 取最新版本的错题(repo 是单一数据源,避免 caller 拿到旧拷贝)
    /// Live copy of the mistake from the repo (the repo is the single
    /// source of truth, so we don't use a stale injected copy).
    private var liveMistake: MistakeNote {
        container.mistakeRepo.mistakeSets.first(where: { $0.id == mistakeSet.id }) ?? mistakeSet
    }

    var body: some View {
        List {
            // 掌握度曲线 / 曝光统计
            // Mastery curve / exposure stats card.
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
            // 原题段:MarkdownView + 题图横滑(若存在)
            // Question section: MarkdownView + question-image strip (if any).
            if !liveMistake.originalQuestion.isEmpty {
                Section(header: Text("Original Question".localized())) {
                    MarkdownView(
                        // normalisingSingleDollarMath 把 "$...$" → "$ ... $",
                        // 让 SwiftUI Markdown / MathJax 都能正确解析
                        // normalisingSingleDollarMath rewrites "$...$" to "$ ... $"
                        // so both SwiftUI Markdown and MathJax render it.
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
            // 错因段:MarkdownView + 错因图(若存在)
            // Error reason section: MarkdownView + reason images (if any).
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
            // 错解段:红 ✗ 图标作为 header 装饰
            // Wrong-solution section: red ✗ icon in the header.
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
            // 正解段:绿 ✓ 图标作为 header 装饰
            // Correct-solution section: green ✓ icon in the header.
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
        // iPad / 横屏下限制最大宽度 820pt,避免一行太长
        // On iPad / landscape, cap the max width at 820pt to avoid overly long lines.
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
        // 编辑 sheet
        // Edit sheet.
        .sheet(isPresented: $showingEditSheet) {
            MistakeDetailEditView(container: container, mistakeSet: liveMistake)
                .adaptiveSheet()
        }
        // AI 解析 sheet:
        // - onInsert: 把 AI 的"正确思路"塞回正解字段(空则替换,否则追加)
        // - onAnalysisComplete: 缓存完整 LLM 输出,供"深入探讨"用
        // - onDiscuss: 关掉当前 sheet,延迟 0.3s 弹出讨论 sheet
        // AI analysis sheet:
        // - onInsert: pushes the AI "correct approach" back into the
        //   correct-solution field (replaces if empty, appends otherwise).
        // - onAnalysisComplete: caches the full LLM output for "deep discussion".
        // - onDiscuss: closes this sheet, then opens the discussion sheet after 0.3s.
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
                        let correctApproach = MistakeAnalysisLLM.parseCorrectApproach(from: trimmed)
                        if !correctApproach.isEmpty {
                            if updated.correctSolution.isEmpty {
                                updated.correctSolution = correctApproach
                            } else {
                                updated.correctSolution += "\n\n---\n\n" + correctApproach
                            }
                        }
                        
                        let errorReason = MistakeAnalysisLLM.parseErrorReason(from: trimmed)
                        if !errorReason.isEmpty {
                            if updated.errorReason.isEmpty {
                                updated.errorReason = errorReason
                            } else {
                                updated.errorReason += "\n\n---\n\n" + errorReason
                            }
                        }
                        
                        let extractedTags = MistakeAnalysisLLM.parseTags(from: trimmed)
                        for tag in extractedTags {
                            if !updated.tags.contains(tag) {
                                updated.tags.append(tag)
                            }
                        }
                        container.mistakeRepo.update(updated)
                    }
                },
                onAnalysisComplete: { fullText in
                    lastAIAnalysis = fullText
                },
                onDiscuss: { context, lastAnalysis in
                    showingAIAnalysis = false
                    // 0.3s 延迟,避免 sheet 状态机冲突
                    // 0.3s delay to avoid sheet state-machine conflicts.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showingAIDiscussion = true
                    }
                }
            )
            .environmentObject(envManager)
            .adaptiveSheet()
        }
        // "深入探讨" sheet:在 AI 解析之上多轮对话
        // "Deep discussion" sheet: multi-turn chat on top of the AI analysis.
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
        // AI 同类题 flow
        // AI similar-question flow.
        .sheet(isPresented: $showingAISimilarQuestion) {
            AISimilarQuestionFlowView(originalMistake: liveMistake)
                .environment(container)
                .environmentObject(envManager)
                .adaptiveSheet()
        }
        // 快速复习:以全屏 cover 形式弹闪卡
        // Quick review: presents the flashcard flow as a full-screen cover.
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
        // 每次进入页面记一次曝光(exposureCount 影响 SRS 调度)
        // Record one exposure on appear (exposureCount drives SRS scheduling).
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
        // 把错题打包成 LLM 可读的多行 block:
        // 1. metadata(学科/日期/难度/掌握度/标签/曝光)
        // 2. 四个 markdown 段(原题/错因/错解/正解)
        // 3. 上一次的 AI 解析(只读,显式标记,避免 LLM 重复说一次)
        // Pack the mistake into an LLM-readable multi-line block:
        // 1. metadata (subject / date / difficulty / mastery / tags / exposure)
        // 2. four markdown sections (question / reason / wrong / correct)
        // 3. previous AI analysis (read-only, marked explicitly so the LLM
        //    won't re-derive the same conclusion).
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
        // 内部小函数:只在非空时才把某段拼进 context
        // Local helper: only appends a section if its body is non-empty.
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
