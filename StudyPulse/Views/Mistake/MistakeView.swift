//
//  MistakeView.swift
//  StudyPulse
//
//  错题主页:Overview 统计卡 + SRS Due Banner + AI 智能自测卡 + 标签 +
//  学科分组列表。
//
//  Mistake home screen: overview stats card + SRS due banner + AI self-test
//  card + tags + per-subject group list.
//
//  Phase 3 拆分 (2026-07-14):原 930 行单文件 → orchestrator 留本文件,
//  拆出 3 个独立子文件:
//  - MistakeListCellViews.swift  (SubjectCardView / MistakeCardView / StatItem /
//                                  OverviewStatsCard / SubjectOverviewCard)
//  - DueReviewBanner.swift       (DueReviewBanner)
//  - SubjectMistakesView.swift   (SubjectMistakesView 二级页)
//
//  本文件只剩:主 View 编排 + AI 智能自测卡 + sheets / fullScreenCovers 挂载。
//

import SwiftUI
import UniformTypeIdentifiers

/// 错题主页(挂在主 tab 上),驱动 `MistakeViewModel`。
/// Mistake home screen (mounted on the main tab), drives `MistakeViewModel`.
struct MistakeView: View {
    @Environment(RepositoryContainer.self) private var container
    @Environment(\.horizontalSizeClass) private var sizeClass
    /// 主 ViewModel(过滤 / 分组 / SRS / 搜索)
    /// Main view model (filter / grouping / SRS / search).
    @State private var viewModel: MistakeViewModel
    /// Knowledge-gap scan VM. The local scan is immediate; AI enhancement is
    /// started once per mistake-set fingerprint.
    @State private var knowledgeFaultViewModel: KnowledgeFaultLineViewModel
    /// 是否显示 AI Quiz setup sheet
    /// Whether the AI Quiz setup sheet is showing.
    @State private var showingAIQuizSetup = false

    init(container: RepositoryContainer) {
        _viewModel = State(initialValue: MistakeViewModel.makeDefault(container: container))
        _knowledgeFaultViewModel = State(initialValue: KnowledgeFaultLineViewModel.makeDefault(container: container))
    }

    // MARK: - AI Quiz Card / AI 自测卡片

    @ViewBuilder
    private var aiQuizCard: some View {
        // 搜索态不显示 AI 自测卡(搜索意图偏向"找错题",出题反而是干扰)
        // Hide the AI self-test card while searching (search intent is
        // "find a mistake", generating quizzes would be noise).
        if viewModel.searchText.isEmpty {
            Button {
                // 跳到 AIQuizSetupView,setup → quiz → result 三态流程
                // Push to AIQuizSetupView; the setup → quiz → result flow
                // is driven by the view.
                showingAIQuizSetup = true
            } label: {
                HStack(spacing: 14) {
                    // 蓝→绿渐变圆形 icon
                    // Blue-to-green gradient circle icon.
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [.teal, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 48, height: 48)
                        Image(systemName: "sparkles.rectangle.stack")
                            .font(.title3)
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI 智能自测".localized())
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("基于错题/指定章节进行 AI 智能出题，自测并自动阅卷。".localized())
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(DesignToken.Spacing.cardPadding)
                .cardSkin()
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Empty State / 空态

    @ViewBuilder
    private var emptyView: some View {
        VStack(spacing: 24) {
            ContentUnavailableView(
                "No Mistakes".localized(),
                systemImage: "exclamationmark.triangle",
                description: Text("Tap '+' to add a new mistake note.".localized())
            )
            Spacer()
        }
    }

    // MARK: - List Content / 列表内容

    @ViewBuilder
    private var listView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: DesignToken.Spacing.cardSpacing) {
                if viewModel.searchText.isEmpty {
                    OverviewStatsCard(
                        totalCount: viewModel.groups.totalCount,
                        subjectCount: viewModel.groups.sortedSubjects.count
                    )

                    if knowledgeFaultViewModel.repeatedFaultLines.isEmpty {
                        KnowledgeFaultLineEmptyCard()
                    } else {
                        KnowledgeFaultLineCard(
                            scan: knowledgeFaultViewModel.scan,
                            container: container
                        )
                    }

                    if viewModel.patternSummaries.isEmpty {
                        MistakePatternEmptyCard()
                    }
                }

                if let topPattern = viewModel.patternSummaries.first {
                    MistakePatternCard(
                        summary: topPattern,
                        summaries: viewModel.patternSummaries
                    )
                }

                srsBanner

                aiQuizCard

                tagSection

                subjectsList
            }
            .padding(.horizontal, DesignToken.Spacing.mainHorizontal(for: sizeClass))
            .padding(.vertical)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var srsBanner: some View {
        // 有 due 错题且不在搜索状态下才显示 banner
        // Only show the banner when there are due mistakes AND the
        // user is not currently searching.
        if viewModel.searchText.isEmpty && viewModel.srsOverview.dueCount > 0 {
            DueReviewBanner(overview: viewModel.srsOverview) {
                viewModel.flashcardFilter = .dueQueue
                viewModel.showingFlashcards = true
            }
        }
    }

    @ViewBuilder
    private var tagSection: some View {
        // 标签 chip + 标签图谱入口(没有标签时整段不渲染)
        // Tag chip + tag-graph entry (rendered only when tags exist).
        let allTags = MistakeFilter.allTags(container.mistakeRepo.filteredMistakeSets)
        if !allTags.isEmpty {
            MistakeTagSectionView(
                tags: allTags,
                searchText: $viewModel.searchText,
                onShowTagGraph: { viewModel.showingTagGraph = true }
            )
        }
    }

    @ViewBuilder
    private var subjectsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 搜索态:标题变成"搜索结果";非搜索态:标题为"学科"
            // In search mode the header reads "Search Results"; otherwise "Subjects".
            let headerText: String = viewModel.searchText.isEmpty
                ? "Subjects".localized()
                : "Search Results".localized()
            Text(headerText)
                .font(.headline)

            // 每个学科一个 card,点进去展开该学科下的错题
            // One card per subject; tap to expand the subject's mistakes.
            LazyVStack(spacing: 12) {
                ForEach(viewModel.groups.filteredSubjects, id: \.self) { subject in
                    let mistakes = viewModel.viewModelSubjectMistakes(subject: subject)
                    NavigationLink(destination: SubjectMistakesView(subject: subject, mistakes: mistakes)) {
                        SubjectCardView(subject: subject, mistakes: mistakes)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Sheets & Covers / Sheet & Cover

    @ViewBuilder
    private var sheetsAndCovers: some View {
        // 这里用 Color.clear 挂所有 sheet / fileExporter,
        // 真正显示由 viewModel 里的多个 bool 决定。
        // A Color.clear that hosts every sheet / fileExporter; visibility
        // is driven by the viewModel's booleans.
        Color.clear
            // 新建错题 sheet
            // New mistake sheet.
            .sheet(isPresented: $viewModel.showingNewMistakeSet) {
                NewMistakeSetView(container: container)
                    .adaptiveSheet()
            }
            // PDF 导出选项 sheet
            // PDF export options sheet.
            .sheet(isPresented: $viewModel.showingPDFExportSheet) {
                MistakePDFExportSheet { options in
                    viewModel.handlePDFExport(options: options)
                }
                .adaptiveSheet()
            }
            // 真正的 PDF 生成进度页(由 viewModel 准备好的 snapshot 驱动)
            // Actual PDF generation progress page (driven by the snapshot
            // prepared by the viewModel).
            .sheet(item: $viewModel.pendingPDFSnapshot) { snapshot in
                MistakePDFGenerationView(
                    snapshot: snapshot,
                    onCompleted: { data in
                        viewModel.presentPDFExportSheet(data: data)
                    },
                    onError: { message in
                        viewModel.pdfErrorMessage = message
                    }
                )
                .interactiveDismissDisabled(true)
            }
            // 导出失败 alert
            // Export-failed alert.
            .alert("Export Failed".localized(), isPresented: $viewModel.showingExportError) {
                Button("OK".localized()) { viewModel.pdfErrorMessage = nil }
            } message: {
                Text(viewModel.pdfErrorMessage ?? "")
            }
            // Save-to-Files 弹层(fileExporter)
            // Save-to-Files panel (fileExporter).
            .fileExporter(
                isPresented: $viewModel.isExportingPDF,
                document: viewModel.pdfDocument,
                contentType: .pdf,
                defaultFilename: viewModel.pdfDocument?.fileName
            ) { result in
                viewModel.handleExportResult(result)
            }
    }

    @ViewBuilder
    private var fullScreenCovers: some View {
        // 全屏 cover 集合(FlashcardStudyView / TagGraphView)
        // Full-screen cover collection (FlashcardStudyView / TagGraphView).
        Color.clear
            // 闪卡学习:全屏,点左上 x 关闭
            // Flashcard study: full screen, tap top-left x to close.
            .fullScreenCover(isPresented: $viewModel.showingFlashcards) {
                NavigationStack {
                    FlashcardStudyView(container: container, filter: viewModel.flashcardFilter)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button {
                                    viewModel.showingFlashcards = false
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .accessibilityLabel("Close".localized())
                            }
                        }
                }
            }
            // 标签图谱:点节点 → 把 #tag 写回 searchText,然后关闭
            // Tag graph: tapping a node writes "#tag" back to searchText and closes.
            .fullScreenCover(isPresented: $viewModel.showingTagGraph) {
                TagGraphView(
                    mistakes: container.mistakeRepo.filteredMistakeSets,
                    onSelectTag: { tag in
                        viewModel.searchText = "#\(tag)"
                        viewModel.showingTagGraph = false
                    }
                )
            }
            // 智能思维导图:全屏
            // Auto Mind Map: full screen cover.
            .fullScreenCover(isPresented: $viewModel.showingAutoMindMap) {
                AutoMindMapView(
                    mistakes: container.mistakeRepo.filteredMistakeSets,
                    contextTitle: "My Mistakes".localized()
                )
                .environment(container)
            }
    }


    // MARK: - Body / 主体

    var body: some View {
        NavigationStack {
            ZStack {
                // 主体内容:无错题时显示空态,否则显示 listView
                // Main content: empty state when no mistakes, otherwise listView.
                Group {
                    if container.mistakeRepo.filteredMistakeSets.isEmpty {
                        emptyView
                    } else {
                        listView
                    }
                }

                // sheets / fullScreenCover 用 0x0 的隐藏容器挂在 ZStack 里,
                // 这样它们不会影响布局但仍受 navigationStack 控制
                // Sheets / fullScreenCovers are hosted in 0x0 hidden containers
                // inside the ZStack so they don't affect layout but are still
                // controlled by the navigation stack.
                sheetsAndCovers.frame(width: 0, height: 0).hidden()
                fullScreenCovers.frame(width: 0, height: 0).hidden()
            }
            // iOS 26+ 上让 nav bar 背景透明
            // On iOS 26+ make the nav bar background transparent.
            .containerBackground(.clear, for: .navigation)
            .debugModeContainer()
            .debugLayoutBoundsAuto()
            .navigationTitle("Mistakes".localized())
            .navigationBarTitleDisplayMode(.large)
            // 搜索栏:同时影响"subjectsList"标题 + 学科列表过滤
            // Search bar: drives both the "subjectsList" header and
            // the subject list filtering.
            .searchable(text: $viewModel.searchText, prompt: "Search subjects or mistakes...".localized())
            .onAppear {
                viewModel.recompute()
                knowledgeFaultViewModel.recompute()
            }
            .onChange(of: viewModel.searchText) { _, _ in viewModel.recompute() }
            .onChange(of: container.mistakeRepo.filteredMistakeSets) { _, _ in
                viewModel.recompute()
                knowledgeFaultViewModel.recompute()
            }
            .toolbar {
                // 左侧:SRS 复习入口
                // Leading: SRS review entry.
                MistakeListToolbarLeading(
                    totalEnrolled: viewModel.srsOverview.totalEnrolled,
                    dueCount: viewModel.srsOverview.dueCount,
                    dueTags: viewModel.topTagsDue(),
                    onFilterSelect: { filter in
                        viewModel.flashcardFilter = filter
                        viewModel.showingFlashcards = true
                    }
                )
            }
            .toolbar {
                // 右侧:AI Quiz / Auto Mind Map / Tag Graph / PDF / New
                // Trailing: AI Quiz / Auto Mind Map / Tag Graph / PDF / New.
                MistakeListToolbarTrailing(
                    hasMistakes: !container.mistakeRepo.filteredMistakeSets.isEmpty,
                    hasTags: !MistakeFilter.allTags(container.mistakeRepo.filteredMistakeSets).isEmpty,
                    onShowTagGraph: { viewModel.showingTagGraph = true },
                    onShowMindMap: { viewModel.showingAutoMindMap = true },
                    onShowPDFExport: { viewModel.showingPDFExportSheet = true },
                    onShowNewMistake: { viewModel.showingNewMistakeSet = true },
                    onShowAIQuiz: { showingAIQuizSetup = true },
                    container: container
                )
            }

            .toolbar {
                // 阶段选择器(放到 principal,跟 iPad 大标题布局更协调)
                // Phase selector (placed at .principal for better iPad layout).
                ToolbarItem(placement: .principal) {
                    PhaseSelectorView()
                }
            }
            .background(Color(.systemGroupedBackground).opacity(DesignToken.Opacity.rootBackground))
        }
        .sheet(isPresented: $showingAIQuizSetup) {
            AIQuizSetupView()
                .environment(container)
                .interactiveDismissDisabled(true)
                .adaptiveSheet()
        }
    }
}
