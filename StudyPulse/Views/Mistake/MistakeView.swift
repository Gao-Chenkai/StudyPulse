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

import SwiftUI
import UniformTypeIdentifiers

/// 错题主页(挂在主 tab 上),驱动 `MistakeViewModel`。
/// Mistake home screen (mounted on the main tab), drives `MistakeViewModel`.
struct MistakeView: View {
    @Environment(RepositoryContainer.self) private var container
    @EnvironmentObject private var envManager: AppEnvironmentManager
    /// 主 ViewModel(过滤 / 分组 / SRS / 搜索)
    /// Main view model (filter / grouping / SRS / search).
    @StateObject private var viewModel: MistakeViewModel
    /// 是否显示 AI Quiz setup sheet
    /// Whether the AI Quiz setup sheet is showing.
    @State private var showingAIQuizSetup = false

    init(container: RepositoryContainer) {
        _viewModel = StateObject(wrappedValue: MistakeViewModel.makeDefault(container: container))
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
                .padding()
                .cardSkin()
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
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
            VStack(spacing: 24) {
                if viewModel.searchText.isEmpty {
                    OverviewStatsCard(
                        totalCount: viewModel.groups.totalCount,
                        subjectCount: viewModel.groups.sortedSubjects.count
                    )
                    .padding(.horizontal)
                }

                srsBanner

                aiQuizCard

                tagSection

                subjectsList
            }
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
            .padding(.horizontal)
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
                .padding(.horizontal)

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
            .padding(.horizontal)
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
                .environmentObject(envManager)
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
            // 搜索栏:同时影响"subjectsList"标题 + 学科列表过滤
            // Search bar: drives both the "subjectsList" header and
            // the subject list filtering.
            .searchable(text: $viewModel.searchText, prompt: "Search subjects or mistakes...".localized())
            .onAppear { viewModel.recompute() }
            .onChange(of: viewModel.searchText) { _, _ in viewModel.recompute() }
            .onChange(of: container.mistakeRepo.filteredMistakeSets) { _, _ in viewModel.recompute() }
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
                .environmentObject(envManager)
                .interactiveDismissDisabled(true)
                .adaptiveSheet()
        }
    }
}

// MARK: - Due Review Banner / 待复习横幅

/// 「待复习」横幅：突出显示到期的错题数量，引导用户进入闪卡模式
/// "Due review" banner: surfaces the number of due mistakes and
/// nudges the user into the flashcard study flow.
struct DueReviewBanner: View {
    /// 概览数据(包含 due / upcoming)
    /// Overview payload (due / upcoming counts).
    let overview: SRSOverview
    /// 点击回调(进入闪卡模式)
    /// Tap callback (jumps to flashcard mode).
    let onStart: () -> Void

    var body: some View {
        Button(action: onStart) {
            bannerContent
        }
        .buttonStyle(.plain)
        .debugLayoutBoundsAuto()
    }

    @ViewBuilder
    private var bannerContent: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 48, height: 48)
                Image(systemName: "rectangle.stack.fill")
                    .font(.title3)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Time to Review".localized())
                        .font(.headline)
                        .foregroundColor(.primary)
                    if overview.dueCount > 0 {
                        Text("\(overview.dueCount)")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.red))
                    }
                }
                let subtitle = String(format: "%d due · %d upcoming this week".localized(), overview.dueCount, overview.upcomingCount)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.12), Color.blue.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(LinearGradient(
                    colors: [.purple.opacity(0.35), .blue.opacity(0.20)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ), lineWidth: 1)
        )
    }
}

// MARK: - 二级菜单：科目下的错题列表
// MARK: - Subject-mistake drill-down

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
    @EnvironmentObject private var envManager: AppEnvironmentManager

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
            VStack(spacing: 24) {
                SubjectOverviewCard(subject: subject, mistakes: sortedMistakes)
                    .padding(.horizontal)

                subjectTagsSection

                suggestedReviewSection

                mistakeListSection
            }
            .padding(.vertical)
            .adaptiveMaxWidth(900)
        }
        .navigationTitle(subject.localized())
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
            .environmentObject(envManager)
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
                .padding(.horizontal)

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
                    .padding(.horizontal)
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
            .padding(.horizontal)
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
                .padding(.horizontal)

            LazyVStack(spacing: 12) {
                ForEach(filteredMistakes) { mistake in
                    NavigationLink(destination: MistakeSetDetailView(mistakeSet: mistake)) {
                        MistakeCardView(mistake: mistake)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - 概览统计卡片 / Overview stats card
struct OverviewStatsCard: View {
    let totalCount: Int
    let subjectCount: Int
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 24) {
                StatItem(title: "Total".localized(), value: "\(totalCount)", icon: "doc.text.fill", color: .blue)
                StatItem(title: "Subjects".localized(), value: "\(subjectCount)", icon: "folder.fill", color: .purple)
            }
        }
        .padding(16)
        .cardSkin()
    }
}

// MARK: - 科目概览卡片 / Subject overview card
struct SubjectOverviewCard: View {
    let subject: String
    let mistakes: [MistakeNote]
    
    var lastWeekCount: Int {
        // 一周前的 cut-off,只要 date 晚于这一刻就计入
        // One-week cutoff: count mistakes whose date is newer than this.
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return mistakes.filter { $0.date > oneWeekAgo }.count
    }

    var oldestDate: Date? {
        // 错题里最早期的一条,用于显示"已记录 N 天"
        // The earliest mistake in the list, used to display "tracked since N days".
        mistakes.min { $0.date < $1.date }?.date
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(subject.localized())
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(String(format: "%d mistakes".localized(), mistakes.count))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "folder.fill")
                    .font(.title)
                    .foregroundColor(.purple)
            }
            
            if lastWeekCount > 0 {
                HStack {
                    Image(systemName: "calendar.badge.plus")
                        .foregroundColor(.green)
                    Text(String(format: "%d added this week".localized(), lastWeekCount))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            
            if let oldest = oldestDate {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.orange)
                    Text(String(format: "Oldest: %@".localized(), oldest.formatted(date: .abbreviated, time: .omitted)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .padding(16)
        .cardSkin()
    }
}

// MARK: - 统计项组件 / Stat item component
struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 科目卡片组件 / Subject card component
struct SubjectCardView: View {
    /// 学科(内部 key)
    /// Subject (internal key).
    let subject: String
    /// 该学科下的错题
    /// Mistakes under this subject.
    let mistakes: [MistakeNote]
    /// 列表项进入动画状态
    /// Row enter-animation state.
    @State private var animateIn = false

    /// 调色板:用 subject 的 hash 决定一个稳定颜色
    /// Palette: pick a stable color from `subject.hash` so the same subject
    /// always shows up the same color across sessions.
    private static let palette: [Color] = [
        .red, .orange, .yellow, .green, .mint, .teal,
        .blue, .indigo, .purple, .pink, .brown, .cyan
    ]

    /// 学科 hash → 调色板里挑一个
    /// Pick a palette color from the subject's hash.
    private var iconColor: Color {
        let hash = abs(subject.hashValue)
        return Self.palette[hash % Self.palette.count]
    }

    /// 一周内新增的错题数(用于"新"小角标)
    /// Mistakes added in the last 7 days (for the "new" badge).
    var recentCount: Int {
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return mistakes.filter { $0.date > oneWeekAgo }.count
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [iconColor, iconColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)

                Image(systemName: "folder.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(subject.localized())
                    .font(.headline)
                    .lineLimit(1)
                
                Text(String(format: "%d mistakes".localized(), mistakes.count))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if recentCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkle")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                        Text(String(format: "%d new".localized(), recentCount))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Color(UIColor.tertiaryLabel))
        }
        .padding(16)
        .cardSkin()
        .hoverHighlight()
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 15)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                animateIn = true
            }
        }
    }
}

// MARK: - Mistake Card View / 错题卡片视图
struct MistakeCardView: View {
    /// 单条错题
    /// A single mistake entry.
    let mistake: MistakeNote
    /// 列表项进入动画状态
    /// Row enter-animation state.
    @State private var animateIn = false

    /// 四段图片总数(用于右上角的"图"小角标)
    /// Total image count across all four sections (for the "photo" badge).
    var totalImageCount: Int {
        mistake.questionImages.count + mistake.reasonImages.count +
        mistake.wrongSolutionImages.count + mistake.correctSolutionImages.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardHeader
            cardDetails
        }
        .padding(14)
        .cardSkin()
        .hoverHighlight()
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 15)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                animateIn = true
            }
        }
    }

    @ViewBuilder
    private var cardHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(mistake.title)
                    .font(.headline)
                    .lineLimit(1)

                if !mistake.subject.isEmpty {
                    Text(mistake.subject.localized())
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color(.systemPurple).opacity(0.15))
                        )
                        .foregroundColor(Color(.systemPurple))
                }

                if !mistake.tags.isEmpty {
                    TagChipsView(tags: mistake.tags, compact: true, maxVisible: 3)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                // 列表项右侧元信息:日期 + 图数量 + 难度星
                // Right-aligned metadata: date / image count / difficulty stars.
                Text(mistake.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)

                if totalImageCount > 0 {
                    // 图标:显示图片总数
                    // Photo icon: total image count.
                    Label("\(totalImageCount)", systemImage: "photo.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

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
        }
    }

    @ViewBuilder
    private var cardDetails: some View {
        if !mistake.originalQuestion.isEmpty {
            Text(mistake.originalQuestion)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .padding(.top, 2)
        }

        if !mistake.source.isEmpty {
            Text(String(format: "Source: %@".localized(), mistake.source))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
