//
//  HomeView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//
//  主页(Dashboard)。负责:
//  - 顶部欢迎区
//  - 主要统计卡(4 个核心指标)
//  - 用户可配置的动态卡片(快捷操作 / 学习建议 / 趋势图 / 即将考试 / 热力图 等)
//  - 学习报告图片导出(整页 + 单卡分享)
//
//  架构:
//  - HomeViewModel: 派生数据(SRS / recent grades / upcoming exams / chart 选科 / 建议生成)
//  - HomeUIState:   主页 UI 临时状态(分阶段渲染 / modal / 报告导出),聚合在 @State
//  - HomeCards/...: 7 个卡片子 View,各自独立文件
//
//

import SwiftUI
import Charts
import UIKit

// MARK: - 主视图
struct HomeView: View {
    @Binding var selectedTab: Int
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(RepositoryContainer.self) private var container
    @EnvironmentObject var envManager: AppEnvironmentManager
    @StateObject private var viewModel: HomeViewModel
    @ObservedObject private var hrvManager = HealthKitManager.shared

    /// UI 临时状态聚合(分阶段渲染 / 模态 / 报告导出)。详见 `HomeUIState`。
    @State private var uiState = HomeUIState()

    // MARK: - Init

    init(container: RepositoryContainer, selectedTab: Binding<Int>) {
        _viewModel = StateObject(wrappedValue: HomeViewModel.makeDefault(container: container))
        self._selectedTab = selectedTab
    }

    // MARK: - Layout

    private var isRegularWidth: Bool {
        sizeClass == .regular || isIPad
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                // 外层用 LazyVStack 避免屏外卡片参与布局
                // Use LazyVStack at the outer level so off-screen cards skip layout
                LazyVStack(spacing: 20) {
                    // 顶部欢迎区域（全宽）
                    WelcomeHeaderCard(selectedTab: $selectedTab)

                    // 主要统计卡片（全宽，4 个指标横排）
                    if uiState.renderPhase >= 1 {
                        MainStatsCard()
                    }

                    if uiState.renderPhase >= 2 {
                        dynamicCards
                    }
                }
                .padding(.horizontal, sizeClass == .regular || isIPad ? 24 : 20)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .background(Color(.systemGroupedBackground).opacity(0.4))
            .containerBackground(.clear, for: .navigation)
            .navigationTitle("Dashboard".localized())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        uiState.showingReportOptions = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                    }
                    .accessibilityLabel("Share Report".localized())
                    .disabled(uiState.isExporting)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(isPresented: Binding(
                get: { uiState.showingFlashcards },
                set: { uiState.showingFlashcards = $0 }
            )) {
                NavigationStack {
                    FlashcardStudyView()
                        .environment(container)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button {
                                    uiState.showingFlashcards = false
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .accessibilityLabel("Close".localized())
                            }
                        }
                }
            }
            .sheet(isPresented: Binding(
                get: { uiState.showingReportOptions },
                set: { uiState.showingReportOptions = $0 }
            )) {
                ReportOptionsSheet { options in
                    generateReport(options: options)
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: Binding(
                get: { uiState.showingShareSheet },
                set: { uiState.showingShareSheet = $0 }
            )) {
                if let image = uiState.reportImage {
                    ReportShareSheet(items: [image], subject: "StudyPulse Report")
                } else if let image = uiState.singleCardImage {
                    ReportShareSheet(items: [image], subject: uiState.singleCardTitle)
                }
            }
            .alert(
                "Report export failed".localized(),
                isPresented: Binding(
                    get: { uiState.reportErrorMessage != nil },
                    set: { if !$0 { uiState.reportErrorMessage = nil } }
                )
            ) {
                Button("OK".localized(), role: .cancel) { }
            } message: {
                Text(uiState.reportErrorMessage ?? "")
            }
            // 派生数据重算:由 HomeViewModel.recompute() 集中处理
            .onAppear { viewModel.recompute() }
            .onChange(of: container.gradeRepo.grades) { _, _ in viewModel.recompute() }
            .onChange(of: container.examRepo.filteredExamSets) { _, _ in viewModel.recompute() }
            .onChange(of: container.mistakeRepo.mistakeSets) { _, _ in viewModel.recompute() }
            .overlay {
                if uiState.isRenderingReport {
                    ZStack {
                        Color.black.opacity(0.15)
                        ProgressView()
                            .scaleEffect(1.4)
                            .padding(24)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .transition(.opacity)
                    .zIndex(99)
                }
            }
        }
        .task {
            // 分三帧渲染：欢迎区 → 统计卡 → 动态卡片（含 Charts）
            try? await Task.sleep(nanoseconds: 50_000_000)
            uiState.renderPhase = 1
            try? await Task.sleep(nanoseconds: 50_000_000)
            uiState.renderPhase = 2
        }
    }

    // MARK: - Dynamic Cards

    /// 动态渲染可配置卡片：iPhone 单列，iPad 双列网格（全宽卡片独占一行）
    @ViewBuilder
    private var dynamicCards: some View {
        let layout = HomeLayoutPreference.load()
        let enabledTypes = layout.enabledTypes

        if isRegularWidth {
            // iPad: 按 enabledTypes 顺序渲染；全宽卡片独占一行，其他 2 列成行
            iPadDynamicCards(types: enabledTypes)
        } else {
            // iPhone：LazyVStack 包装 ForEach 让屏外卡片跳过布局
            // iPhone: wrap ForEach in LazyVStack so off-screen cards skip layout
            LazyVStack(spacing: 16) {
                ForEach(enabledTypes, id: \.self) { type in
                    cardView(for: type)
                }
            }
        }
    }

    /// iPad 上的卡片布局：把 enabledTypes 切成"块"——全宽卡片独立成块，
    /// 其余按 2 个一组进网格。这样 heatmap 等宽幅卡片可以出现在任何排序位置。
    @ViewBuilder
    private func iPadDynamicCards(types: [HomeCardType]) -> some View {
        let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
        let chunks = makeChunks(from: types)

        LazyVStack(spacing: 16) {
            ForEach(Array(chunks.enumerated()), id: \.offset) { _, chunk in
                if chunk.count == 1 && chunk[0].isFullWidth {
                    // 全宽卡片：脱离网格
                    cardView(for: chunk[0])
                } else {
                    // 1-2 个普通卡片：进 2 列网格
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(chunk, id: \.self) { type in
                            cardView(for: type)
                        }
                    }
                }
            }
        }
    }

    /// 把 enabledTypes 切成行块：全宽卡片独占一块，普通卡片每 2 个一块。
    private func makeChunks(from types: [HomeCardType]) -> [[HomeCardType]] {
        var chunks: [[HomeCardType]] = []
        var current: [HomeCardType] = []
        for type in types {
            if type.isFullWidth {
                if !current.isEmpty {
                    chunks.append(current)
                    current = []
                }
                chunks.append([type])
            } else {
                current.append(type)
                if current.count == 2 {
                    chunks.append(current)
                    current = []
                }
            }
        }
        if !current.isEmpty {
            chunks.append(current)
        }
        return chunks
    }

    /// 根据卡片类型返回对应视图；数据不足时自动隐藏
    @ViewBuilder
    private func cardView(for type: HomeCardType) -> some View {
        // 每个分支都用 `.contextMenu` 包一层，支持长按分享该卡片。
        switch type {
        case .studyTimer:
            StudyTimerCard()
                .contextMenu { shareCardMenu(for: type) }
        case .hrvStatus:
            HRVStatusCard()
                .contextMenu { shareCardMenu(for: type) }
        case .unregisteredExamsReminder:
            if !viewModel.unregisteredExams.isEmpty {
                UnregisteredExamsReminderCard(unregisteredExams: viewModel.unregisteredExams)
                    .contextMenu { shareCardMenu(for: type) }
            }
        case .flashcardReview:
            if viewModel.srsOverview.dueCount > 0 {
                FlashcardReviewHomeCard(overview: viewModel.srsOverview) {
                    uiState.showingFlashcards = true
                }
                .contextMenu { shareCardMenu(for: type) }
            }
        case .quickActions:
            QuickActionsCard()
                .contextMenu { shareCardMenu(for: type) }
        case .studySuggestions:
            StudySuggestionsCard(viewModel: viewModel)
                .contextMenu { shareCardMenu(for: type) }
        case .trendChart:
            if !viewModel.recentGrades.isEmpty {
                TrendChartCard(viewModel: viewModel)
                    .contextMenu { shareCardMenu(for: type) }
            }
        case .upcomingExams:
            if !viewModel.upcomingExams.isEmpty {
                UpcomingExamsCard()
                    .contextMenu { shareCardMenu(for: type) }
            }
        case .dailyQuote:
            DailyQuoteCard(quote: QuoteProvider.dailyQuote())
                .contextMenu { shareCardMenu(for: type) }
        case .streakProgress:
            StreakHomeCard()
                .contextMenu { shareCardMenu(for: type) }
        case .recentGrades:
            if !viewModel.recentGrades.isEmpty {
                RecentGradesCard()
                    .contextMenu { shareCardMenu(for: type) }
            }
        case .learningHeatmap:
            LearningHeatmapView()
                .contextMenu { shareCardMenu(for: type) }
        }
    }

    /// 单卡片长按分享：contextMenu 内显示的按钮。
    @ViewBuilder
    private func shareCardMenu(for type: HomeCardType) -> some View {
        Button {
            Task { await renderAndShareSingleCard(type: type) }
        } label: {
            Label("Share Report".localized(), systemImage: "square.and.arrow.up")
        }
    }

    // MARK: - 学习报告图片导出

    /// 渲染并分享整页学习报告。
    /// Render the full report and present the share sheet.
    @MainActor
    private func generateReport(options: ReportOptions) {
        uiState.isRenderingReport = true
        Task {
            defer { uiState.isRenderingReport = false }
            let report = StudyReport.make(
                from: container,
                hrvManager: hrvManager,
                start: options.startDate,
                end: options.endDate
            )
            let view = ReportContentView(report: report)
            guard let image = ReportRenderer.render(view) else {
                uiState.reportErrorMessage = "Report export failed".localized()
                Log.record(.error, category: "Export", message: "整页报告渲染失败 / Full report render returned nil")
                return
            }
            // PNG 始终可用；JPEG 编码在外部保存时再处理。
            uiState.reportImage = image
            uiState.singleCardImage = nil
            // 短暂延迟，确保 isRendering 状态先变化（让 ProgressView 闪一下再消失）
            try? await Task.sleep(nanoseconds: 80_000_000)
            uiState.showingShareSheet = true
            Log.record(.info, category: "Export", message: "整页报告已生成 / Full report generated: size=\(Int(image.size.width))x\(Int(image.size.height))")
        }
    }

    /// 渲染并分享单张 Home 卡片。
    /// Render a single Home card and present the share sheet.
    @MainActor
    private func renderAndShareSingleCard(type: HomeCardType) async {
        uiState.isRenderingReport = true
        defer { uiState.isRenderingReport = false }
        let snapshot = StudyReport.make(
                from: container,
            hrvManager: hrvManager,
            start: Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date(),
            end: Date()
        )
        let title = cardShareTitle(for: type)
        let view = cardShareView(for: type, report: snapshot)
        guard let image = ReportRenderer.render(view) else {
            uiState.reportErrorMessage = "Report export failed".localized()
            Log.record(.error, category: "Export", message: "单卡渲染失败 / Single card render returned nil: type=\(type.rawValue)")
            return
        }
        uiState.singleCardImage = image
        uiState.singleCardTitle = title
        uiState.reportImage = nil
        try? await Task.sleep(nanoseconds: 80_000_000)
        uiState.showingShareSheet = true
        Log.record(.info, category: "Export", message: "单卡已生成 / Single card generated: type=\(type.rawValue) size=\(Int(image.size.width))x\(Int(image.size.height))")
    }

    /// 单卡分享时使用的本地化标题。
    private func cardShareTitle(for type: HomeCardType) -> String {
        switch type {
        case .hrvStatus: return "Recovery Radar".localized()
        case .unregisteredExamsReminder: return "Pending Grades".localized()
        case .flashcardReview: return "Flashcard Review".localized()
        case .quickActions: return "Quick Actions".localized()
        case .studyTimer: return "Study Timer".localized()
        case .studySuggestions: return "Study Suggestions".localized()
        case .trendChart: return "Trend Chart".localized()
        case .upcomingExams: return "Upcoming Exams".localized()
        case .dailyQuote: return "Daily Quote".localized()
        case .streakProgress: return "Streak Progress".localized()
        case .recentGrades: return "Recent Grades".localized()
        case .learningHeatmap: return "Learning Heatmap".localized()
        }
    }

    /// 把单卡渲染成 PDF 友好的 SwiftUI 视图。
    /// Wrap the home card into a self-contained view ready for rendering.
    @ViewBuilder
    private func cardShareView(for type: HomeCardType, report: StudyReport) -> some View {
        // 报告内容卡片固定 612pt 宽，上下加 padding 让小卡片也居中。
        // 不同卡片自身可能依赖 @EnvironmentObject / @ObservedObject，
        // 这里直接复用 HomeView 的环境上下文。
        VStack {
            Group {
                switch type {
                case .studyTimer: StudyTimerCard()
                case .hrvStatus: HRVStatusCard()
                case .unregisteredExamsReminder:
                    if !viewModel.unregisteredExams.isEmpty {
                UnregisteredExamsReminderCard(unregisteredExams: viewModel.unregisteredExams)
            } else {
                        Text("No data in this period".localized())
                    }
                case .flashcardReview:
                    if viewModel.srsOverview.dueCount > 0 {
                        FlashcardReviewHomeCard(overview: viewModel.srsOverview) {}
                    } else {
                        Text("No data in this period".localized())
                    }
                case .quickActions: QuickActionsCard()
                case .studySuggestions: StudySuggestionsCard(viewModel: viewModel)
                case .trendChart:
                    if !viewModel.recentGrades.isEmpty {
                        TrendChartCard(viewModel: viewModel)
                    } else {
                        Text("No data in this period".localized())
                    }
                case .upcomingExams:
                    if !viewModel.upcomingExams.isEmpty {
                        UpcomingExamsCard()
                    } else {
                        Text("No data in this period".localized())
                    }
                case .dailyQuote: DailyQuoteCard(quote: QuoteProvider.dailyQuote())
                case .streakProgress: StreakHomeCard()
                case .recentGrades:
                    if !viewModel.recentGrades.isEmpty {
                        RecentGradesCard()
                    } else {
                        Text("No data in this period".localized())
                    }
                case .learningHeatmap:
                    LearningHeatmapView()
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .frame(width: ReportRenderer.defaultWidth, alignment: .topLeading)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - 成绩登记提醒卡片

struct UnregisteredExamsReminderCard: View {
    let unregisteredExams: [Exam]
    @Environment(RepositoryContainer.self) private var container
    @State private var showingAddGrade = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "exclamationmark.bubble.fill")
                    .foregroundColor(.orange)
                Text("Register Exam Grades".localized())
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
            }

            ForEach(unregisteredExams) { exam in
                Button {
                    showingAddGrade = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(exam.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.primary)
                            HStack(spacing: 4) {
                                Text(exam.subject.localized())
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("·")
                                    .foregroundColor(.secondary)
                                Text("\(daysSince(exam.examDate)) " + "days ago".localized())
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                        Spacer()
                        Image(systemName: "plus.circle")
                            .font(.system(size: 20))
                            .foregroundColor(.orange)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground).opacity(0.6))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(
            color: Color.black.opacity(0.05),
            radius: 10,
            x: 0,
            y: 4
        )
        .sheet(isPresented: $showingAddGrade) {
            AddGradeView()
                .environment(container)
                .adaptiveSheet()
        }
    }

    private func daysSince(_ date: Date) -> Int {
        Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
    }
}

// MARK: - 每日励志卡片
struct DailyQuoteCard: View {
    let quote: String

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "quote.bubble.fill")
                    .font(.system(size: 28))
                    .foregroundColor(Color(.systemIndigo).opacity(0.6))

                Text(quote)
                    .font(.system(size: 15, weight: .medium, design: .serif))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 16)
            }
            Spacer()
        }
        .frame(minHeight: 140)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.secondarySystemGroupedBackground))

                RadialGradient(
                    colors: [
                        Color(.systemIndigo).opacity(0.06),
                        Color.clear
                    ],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 200
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
        )
        .shadow(
            color: Color.black.opacity(0.05),
            radius: 10,
            x: 0,
            y: 4
        )
    }
}

// MARK: - Flashcard Review Home Card

/// 主页「待复习」卡片：显示到期错题数量，引导用户进入闪卡模式
struct FlashcardReviewHomeCard: View {
    let overview: SRSOverview
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.stack.fill")
                        .foregroundStyle(LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .font(.title3)
                    Text("Flashcard Review".localized())
                        .font(.system(size: 18, weight: .semibold))
                }
                Spacer()
                if overview.dueCount > 0 {
                    Text("\(overview.dueCount)")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.red))
                }
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(overview.dueCount)")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                    Text("Due Today".localized())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Divider().frame(height: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(overview.upcomingCount)")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                    Text("Upcoming".localized())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Button {
                onStart()
            } label: {
                Label("Start Review".localized(), systemImage: "play.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.12), Color.blue.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(LinearGradient(
                    colors: [.purple.opacity(0.30), .blue.opacity(0.18)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}

// MARK: - 派生数据重算 ViewModifier
/// 集中管理 HomeView 4 个缓存的 onAppear / onChange 触发,
/// 避免在 body 链式调用中直接堆 4 个 modifier 导致 SwiftUI 类型推断超时。
private struct DerivedRecomputeModifier: ViewModifier {
    let grades: [Grade]
    let filteredExamSets: [Exam]
    let mistakeNotes: [MistakeNote]
    let recompute: () -> Void

    func body(content: Content) -> some View {
        content
            .onAppear { recompute() }
            .onChange(of: grades) { _, _ in recompute() }
            .onChange(of: filteredExamSets) { _, _ in recompute() }
            .onChange(of: mistakeNotes) { _, _ in recompute() }
    }
}

// MARK: - Previews
#Preview {
    HomeView(container: RepositoryContainer(), selectedTab: .constant(0))
        .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    HomeView(container: RepositoryContainer(), selectedTab: .constant(0))
        .preferredColorScheme(.dark)
}
