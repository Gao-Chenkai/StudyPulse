//
//  SubjectMistakesView.swift
//  StudyPulse
//
//  学科下错题二级页:搜索 + "建议复习" + 错题列表。
//  Per-subject drill-down page: search + "suggested for review" + list.
//
//  Phase 3 拆分 (2026-07-14):原 `MistakeView.swift` 抽出(原本混在主文件里
//  共 930 行,实际属于"被导航推入"的独立二级页),独立可预览。
//

import SwiftUI

/// 学科下错题二级页:搜索 + "建议复习" + 错题列表。
/// Per-subject drill-down page: search + "suggested for review" + list.
struct SubjectMistakesView: View {
    /// 学科
    /// Subject.
    let subject: String
    /// 该学科下的错题(由 caller 注入)
    /// Mistakes under the subject (injected by the caller).
    let mistakes: [MistakeNote]
    /// 本地 ViewModel(搜索/排序)
    /// Local view model (search / sort).
    @StateObject private var viewModel: SubjectMistakesViewModel
    /// 本地搜索文本
    /// Local search text.
    @State private var searchText = ""
    /// 是否显示智能思维导图 sheet / Show Auto Mind Map sheet?
    @State private var showingAutoMindMap = false

    @Environment(RepositoryContainer.self) private var container

    init(subject: String, mistakes: [MistakeNote]) {
        self.subject = subject
        self.mistakes = mistakes
        _viewModel = StateObject(wrappedValue: SubjectMistakesViewModel(initialMistakes: mistakes))
    }

    /// 搜索过滤后的错题
    /// Mistakes filtered by the search text.
    private var filteredMistakes: [MistakeNote] {
        viewModel.searchInSubject(mistakes, searchText: searchText)
    }
    /// 排序后(目前直接 = filtered,保留 hook)
    /// Sorted (currently equal to filtered; kept as a hook).
    private var sortedMistakes: [MistakeNote] { filteredMistakes }
    /// SRS 调度建议复习的若干条(供顶部推荐区)
    /// SRS-suggested review candidates (shown in the top recommendation region).
    private var suggestedForReview: [MistakeNote] {
        viewModel.suggestedForReview(mistakes)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: DesignToken.Spacing.cardSpacing) {
                SubjectOverviewCard(subject: subject, mistakes: sortedMistakes)
                    .padding(.horizontal, DesignToken.Spacing.secondaryHorizontal)

                subjectTagsSection

                suggestedReviewSection

                mistakeListSection
            }
            .padding(.vertical)
            .adaptiveMaxWidth(900)
        }
        .navigationTitle(subject.localized())
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search mistakes...".localized())
        .background(Color(.systemGroupedBackground))
        .debugLayoutBoundsAuto()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !mistakes.isEmpty {
                    Button {
                        showingAutoMindMap = true
                    } label: {
                        Image(systemName: "arrow.triangle.branch")
                    }
                    .accessibilityLabel("Auto Mind Map".localized())
                }
            }
        }
        .fullScreenCover(isPresented: $showingAutoMindMap) {
            AutoMindMapView(
                mistakes: mistakes,
                contextTitle: subject
            )
            .environment(container)
        }
    }

    @ViewBuilder
    private var subjectTagsSection: some View {
        let allTags = MistakeFilter.allTags(mistakes)
        if !allTags.isEmpty && searchText.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "tag.fill")
                        .foregroundColor(.purple)
                    Text("Tags".localized())
                        .font(.headline)
                    Spacer()
                }
                .padding(.horizontal, DesignToken.Spacing.secondaryHorizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(allTags.enumerated()), id: \.element) { _, tag in
                            Button {
                                searchText = "#\(tag)"
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "number")
                                        .font(.caption2)
                                    Text(tag)
                                        .font(.caption.weight(.medium))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule().fill(Color.purple.opacity(0.85))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, DesignToken.Spacing.secondaryHorizontal)
                }
            }
        }
    }

    @ViewBuilder
    private var suggestedReviewSection: some View {
        if !suggestedForReview.isEmpty && searchText.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "book.circle.fill")
                        .foregroundColor(.purple)
                    Text("Suggested for Review".localized())
                        .font(.headline)
                        .foregroundColor(.primary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(suggestedForReview) { mistake in
                            NavigationLink(destination: MistakeSetDetailView(mistakeSet: mistake)) {
                                SuggestedMistakeCard(mistake: mistake)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, DesignToken.Spacing.secondaryHorizontal)
        }
    }

    @ViewBuilder
    private var mistakeListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            let headerText: String = searchText.isEmpty
                ? String(format: "All Mistakes (%d)".localized(), sortedMistakes.count)
                : String(format: "Search Results (%d)".localized(), filteredMistakes.count)
            Text(headerText)
                .font(.headline)
                .padding(.horizontal, DesignToken.Spacing.secondaryHorizontal)

            LazyVStack(spacing: 12) {
                ForEach(filteredMistakes) { mistake in
                    NavigationLink(destination: MistakeSetDetailView(mistakeSet: mistake)) {
                        MistakeCardView(mistake: mistake)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DesignToken.Spacing.secondaryHorizontal)
        }
    }
}

// MARK: - Previews / 独立预览入口

#Preview("Mathematics") {
    let container = RepositoryContainer()
    let mistakes = (0..<8).map { idx in
        MistakeNote(
            title: "Math Mistake \(idx)",
            subject: "Mathematics",
            originalQuestion: "原题 \(idx)",
            source: "来源",
            date: Date().addingTimeInterval(-Double(idx) * 86400),
            errorReason: "错因 \(idx)",
            wrongSolution: "错解",
            correctSolution: "正解",
            tags: idx % 2 == 0 ? ["计算粗心"] : ["概念混淆"]
        )
    }
    NavigationStack {
        SubjectMistakesView(subject: "Mathematics", mistakes: mistakes)
    }
    .environment(container)
}
