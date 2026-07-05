//
//  HomeView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import SwiftUI
import Charts
import UIKit

// MARK: - 每日变化的励志语录（基于日期）
let dailyQuotes = [
    "Quote 1".localized(),
    "Quote 2".localized(),
    "Quote 3".localized(),
    "Quote 4".localized(),
    "Quote 5".localized(),
    "Quote 6".localized(),
    "Quote 7".localized(),
    "Quote 8".localized(),
    "Quote 9".localized(),
    "Quote 10".localized(),
    "Quote 11".localized(),
    "Quote 12".localized(),
    "Quote 13".localized(),
    "Quote 14".localized(),
]

var dailyQuote: String {
    let calendar = Calendar.current
    let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 0
    let index = dayOfYear % dailyQuotes.count
    return dailyQuotes[index]
}

// MARK: - 主视图
struct HomeView: View {
    @Binding var selectedTab: Int
    @Environment(\.horizontalSizeClass) private var sizeClass
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var envManager: AppEnvironmentManager
    @ObservedObject private var hrvManager = HealthKitManager.shared
    /// 异步加载的头像数据，避免 body 中同步读文件
    @State private var avatarData: Data? = nil
    /// 分阶段渲染计数器，避免一次性构建所有复杂子视图
    @State private var renderPhase = 0
    /// 闪卡复习 fullScreenCover 状态
    @State private var showingFlashcards = false

    // MARK: - 学习报告图片导出状态
    /// 选项 sheet
    @State private var showingReportOptions = false
    /// 渲染进度
    @State private var isRenderingReport = false
    /// 已渲染的整页报告图片（用于分享）
    @State private var reportImage: UIImage?
    /// 已渲染的单卡图片（用于分享）
    @State private var singleCardImage: UIImage?
    @State private var singleCardTitle: String = ""
    /// 分享 sheet 控制
    @State private var showingShareSheet = false
    /// 错误提示
    @State private var reportErrorMessage: String?

    // MARK: - 派生数据缓存(避免 body 每次重新计算)
    /// SRS 队列总览(随 mistakeSets 变化)
    @State private var cachedSRSOverview: SRSOverview = SRSOverview(dueCount: 0, upcomingCount: 0, totalEnrolled: 0)
    /// 最近 5 条成绩(随 grades 变化)
    @State private var cachedRecentGrades: [Grade] = []
    /// 未来 14 天即将到来的考试(随 filteredExamSets 变化)
    @State private var cachedUpcomingExams: [Exam] = []
    /// 已过 3-7 天但未登记成绩的考试(随 grades + filteredExamSets 变化)
    @State private var cachedUnregisteredExams: [Exam] = []

    private var isRegularWidth: Bool {
        sizeClass == .regular || isIPad
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                // 外层用 LazyVStack 避免屏外卡片参与布局
                // Use LazyVStack at the outer level so off-screen cards skip layout
                LazyVStack(spacing: 20) {
                    // 顶部欢迎区域（全宽）
                    WelcomeHeaderView(selectedTab: $selectedTab)

                    // 主要统计卡片（全宽，4 个指标横排）
                    if renderPhase >= 1 {
                        MainStatsCard()
                    }

                    if renderPhase >= 2 {
                        dynamicCards
                    }
                }
                .padding(.horizontal, sizeClass == .regular || isIPad ? 24 : 20)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Dashboard".localized())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingReportOptions = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                    }
                    .accessibilityLabel("Share Report".localized())
                    .disabled(isRenderingReport)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(isPresented: $showingFlashcards) {
                NavigationStack {
                    FlashcardStudyView()
                        .environmentObject(dataManager)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button {
                                    showingFlashcards = false
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .accessibilityLabel("Close".localized())
                            }
                        }
                }
            }
            .sheet(isPresented: $showingReportOptions) {
                ReportOptionsSheet { options in
                    generateReport(options: options)
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showingShareSheet) {
                if let image = reportImage {
                    ReportShareSheet(items: [image], subject: "StudyPulse Report")
                } else if let image = singleCardImage {
                    ReportShareSheet(items: [image], subject: singleCardTitle)
                }
            }
            .alert(
                "Report export failed".localized(),
                isPresented: Binding(
                    get: { reportErrorMessage != nil },
                    set: { if !$0 { reportErrorMessage = nil } }
                )
            ) {
                Button("OK".localized(), role: .cancel) { }
            } message: {
                Text(reportErrorMessage ?? "")
            }
            // 派生数据重算:仅在 grades/examSets/mistakeSets 真正变化时触发,
            // 避免 body 每次 re-render 都全量扫描。
            .modifier(DerivedRecomputeModifier(
                grades: dataManager.grades,
                filteredExamSets: dataManager.filteredExamSets,
                mistakeNotes: dataManager.mistakeSets,
                recompute: recomputeDerived
            ))
            .overlay {
                if isRenderingReport {
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
            renderPhase = 1
            try? await Task.sleep(nanoseconds: 50_000_000)
            renderPhase = 2
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
            if !cachedUnregisteredExams.isEmpty {
                UnregisteredExamsReminderCard(unregisteredExams: cachedUnregisteredExams)
                    .contextMenu { shareCardMenu(for: type) }
            }
        case .flashcardReview:
            if cachedSRSOverview.dueCount > 0 {
                FlashcardReviewHomeCard(overview: cachedSRSOverview) {
                    showingFlashcards = true
                }
                .contextMenu { shareCardMenu(for: type) }
            }
        case .quickActions:
            QuickActionsCard()
                .contextMenu { shareCardMenu(for: type) }
        case .studySuggestions:
            StudySuggestionsCard()
                .contextMenu { shareCardMenu(for: type) }
        case .trendChart:
            if !cachedRecentGrades.isEmpty {
                ChartSectionView()
                    .contextMenu { shareCardMenu(for: type) }
            }
        case .upcomingExams:
            if !cachedUpcomingExams.isEmpty {
                UpcomingExamsSection()
                    .contextMenu { shareCardMenu(for: type) }
            }
        case .dailyQuote:
            DailyQuoteCard(quote: dailyQuote)
                .contextMenu { shareCardMenu(for: type) }
        case .streakProgress:
            StreakHomeCard()
                .contextMenu { shareCardMenu(for: type) }
        case .recentGrades:
            if !cachedRecentGrades.isEmpty {
                RecentGradesSection()
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

    // MARK: - 派生数据重算(集中管理,避免 body 内隐式 O(n²))

    /// 一次性刷新 4 个缓存,避免对 grades/filterExamSets 多次扫描。
    /// O(n+m) 一次扫：先建 Set<String> 给 unregisteredExams 用,再 prefix 5 给 recentGrades 用,
    /// 再同时按时间窗口 filter 给 upcomingExams / unregisteredExams 用。
    private func recomputeDerived() {
        // SRS 队列
        cachedSRSOverview = SRSAlgorithm.overview(from: dataManager.mistakeSets)
        // Recent grades: 按时间倒序取前 5,O(n log n) 一次排序
        let sortedGradesDesc = dataManager.grades.sorted { $0.date > $1.date }
        cachedRecentGrades = Array(sortedGradesDesc.prefix(5))
        // Upcoming exams: 14 天内的考试
        let twoWeeksFromNow = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
        let now = Date()
        cachedUpcomingExams = dataManager.filteredExamSets
            .filter { $0.examDate > now && $0.examDate <= twoWeeksFromNow }
            .sorted { $0.examDate < $1.examDate }
        // Unregistered exams: 3-7 天前过、未登记
        // 之前是 N+1 嵌套 filter(每场 exam 都扫全部 grades),现改为单次建 Set
        let startOfToday = Calendar.current.startOfDay(for: now)
        guard let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: startOfToday),
              let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: startOfToday) else {
            cachedUnregisteredExams = []
            return
        }
        let dayInterval: TimeInterval = 86_400
        // 预建 key 集合(subject+examName+dateBucket)→ O(n)
        var registeredKeys = Set<String>()
        registeredKeys.reserveCapacity(dataManager.grades.count)
        for g in dataManager.grades {
            let dayBucket = Int(g.date.timeIntervalSince1970 / dayInterval)
            registeredKeys.insert("\(g.subject)|\(g.examName)|\(dayBucket)")
        }
        cachedUnregisteredExams = dataManager.filteredExamSets.filter { exam in
            guard exam.examDate < threeDaysAgo && exam.examDate >= sevenDaysAgo else {
                return false
            }
            let dayBucket = Int(exam.examDate.timeIntervalSince1970 / dayInterval)
            return !registeredKeys.contains("\(exam.subject)|\(exam.examName)|\(dayBucket)")
        }.sorted { $0.examDate < $1.examDate }
    }

    // MARK: - 学习报告图片导出

    /// 渲染并分享整页学习报告。
    /// Render the full report and present the share sheet.
    @MainActor
    private func generateReport(options: ReportOptions) {
        isRenderingReport = true
        Task {
            defer { isRenderingReport = false }
            let report = StudyReport.make(
                from: dataManager,
                hrvManager: hrvManager,
                start: options.startDate,
                end: options.endDate
            )
            let view = ReportContentView(report: report)
            guard let image = ReportRenderer.render(view) else {
                reportErrorMessage = "Report export failed".localized()
                Log.record(.error, category: "Export", message: "整页报告渲染失败 / Full report render returned nil")
                return
            }
            // PNG 始终可用；JPEG 编码在外部保存时再处理。
            self.reportImage = image
            self.singleCardImage = nil
            // 短暂延迟，确保 isRendering 状态先变化（让 ProgressView 闪一下再消失）
            try? await Task.sleep(nanoseconds: 80_000_000)
            self.showingShareSheet = true
            Log.record(.info, category: "Export", message: "整页报告已生成 / Full report generated: size=\(Int(image.size.width))x\(Int(image.size.height))")
        }
    }

    /// 渲染并分享单张 Home 卡片。
    /// Render a single Home card and present the share sheet.
    @MainActor
    private func renderAndShareSingleCard(type: HomeCardType) async {
        isRenderingReport = true
        defer { isRenderingReport = false }
        let snapshot = StudyReport.make(
            from: dataManager,
            hrvManager: hrvManager,
            start: Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date(),
            end: Date()
        )
        let title = cardShareTitle(for: type)
        let view = cardShareView(for: type, report: snapshot)
        guard let image = ReportRenderer.render(view) else {
            reportErrorMessage = "Report export failed".localized()
            Log.record(.error, category: "Export", message: "单卡渲染失败 / Single card render returned nil: type=\(type.rawValue)")
            return
        }
        self.singleCardImage = image
        self.singleCardTitle = title
        self.reportImage = nil
        try? await Task.sleep(nanoseconds: 80_000_000)
        self.showingShareSheet = true
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
                    if !cachedUnregisteredExams.isEmpty {
                        UnregisteredExamsReminderCard(unregisteredExams: cachedUnregisteredExams)
                    } else {
                        Text("No data in this period".localized())
                    }
                case .flashcardReview:
                    if cachedSRSOverview.dueCount > 0 {
                        FlashcardReviewHomeCard(overview: cachedSRSOverview) {}
                    } else {
                        Text("No data in this period".localized())
                    }
                case .quickActions: QuickActionsCard()
                case .studySuggestions: StudySuggestionsCard()
                case .trendChart:
                    if !cachedRecentGrades.isEmpty {
                        ChartSectionView()
                    } else {
                        Text("No data in this period".localized())
                    }
                case .upcomingExams:
                    if !cachedUpcomingExams.isEmpty {
                        UpcomingExamsSection()
                    } else {
                        Text("No data in this period".localized())
                    }
                case .dailyQuote: DailyQuoteCard(quote: dailyQuote)
                case .streakProgress: StreakHomeCard()
                case .recentGrades:
                    if !cachedRecentGrades.isEmpty {
                        RecentGradesSection()
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
    @EnvironmentObject var dataManager: DataManager
    /// 异步加载的头像数据，避免 body 中同步读文件
    @State private var avatarData: Data? = nil
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
                .environmentObject(dataManager)
                .adaptiveSheet()
        }
    }
    
    private func daysSince(_ date: Date) -> Int {
        Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
    }
}

// MARK: - 顶部欢迎区域
struct WelcomeHeaderView: View {
    @Binding var selectedTab: Int
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var dataManager: DataManager
    /// 异步加载的头像数据，避免 body 中同步读文件
    @State private var avatarData: Data? = nil
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(greetingText())
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text("Ready to study!".localized())
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(currentDateText())
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                selectedTab = 4
            } label: {
                AvatarView(
                    username: dataManager.profile.username,
                    avatarData: avatarData,
                    size: 50,
                    showBorder: true
                )
            }
            .buttonStyle(.plain)
        }
        .task {
            avatarData = await dataManager.loadAvatarAsync()
        }
    }
    
    private func greetingText() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "Good Morning".localized()
        } else if hour < 18 {
            return "Good Afternoon".localized()
        } else {
            return "Good Evening".localized()
        }
    }
    
    // 静态化 DateFormatter 避免每次调用新建(DateFormatter 初始化 ~1ms)
    private static let fullDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f
    }()

    private func currentDateText() -> String {
        Self.fullDateFormatter.string(from: Date())
    }
}

// MARK: - 主要统计卡片
struct MainStatsCard: View {
    @EnvironmentObject var dataManager: DataManager
    /// 异步加载的头像数据，避免 body 中同步读文件
    @State private var avatarData: Data? = nil
    @Environment(\.horizontalSizeClass) private var sizeClass
    /// 渐变动画开关 — 之前用 repeatForever 持续触发 gradient 重算,
    /// 现改为 onAppear 后单次播放 6 秒动画,然后停(避免持续 CPU 占用)。
    @State private var animateGradient = false
    /// 平均分文本缓存(随 grades 变化重算,避免每次 body reduce 所有 grades)
    @State private var cachedAverageText: String = "N/A"
    /// 14 天内考试数量缓存(随 filteredExamSets 变化重算)
    @State private var cachedUpcomingExamsCount: Int = 0

    private var isWide: Bool { sizeClass == .regular || isIPad }

    var body: some View {
        VStack(spacing: 20) {
            // iPad 一行 4 个,iPhone 仍是 2x2
            if isWide {
                HStack(spacing: 12) {
                    StatItemView(
                        title: "Average".localized(),
                        value: cachedAverageText,
                        icon: "chart.line.uptrend.xyaxis",
                        color: .cyan
                    )
                    StatItemView(
                        title: "Total Grades".localized(),
                        value: "\(dataManager.grades.count)",
                        icon: "doc.text.fill",
                        color: .purple
                    )
                    StatItemView(
                        title: "Upcoming".localized(),
                        value: "\(cachedUpcomingExamsCount)",
                        icon: "calendar.badge.exclamationmark",
                        color: .orange
                    )
                    StatItemView(
                        title: "Mistakes".localized(),
                        value: "\(dataManager.mistakeSets.count)",
                        icon: "exclamationmark.triangle.fill",
                        color: .red
                    )
                }
            } else {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        StatItemView(
                            title: "Average".localized(),
                            value: cachedAverageText,
                            icon: "chart.line.uptrend.xyaxis",
                            color: .cyan
                        )
                        StatItemView(
                            title: "Total Grades".localized(),
                            value: "\(dataManager.grades.count)",
                            icon: "doc.text.fill",
                            color: .purple
                        )
                    }
                    HStack(spacing: 12) {
                        StatItemView(
                            title: "Upcoming".localized(),
                            value: "\(cachedUpcomingExamsCount)",
                            icon: "calendar.badge.exclamationmark",
                            color: .orange
                        )
                        StatItemView(
                            title: "Mistakes".localized(),
                            value: "\(dataManager.mistakeSets.count)",
                            icon: "exclamationmark.triangle.fill",
                            color: .red
                        )
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.secondarySystemGroupedBackground))

                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemBlue).opacity(0.06),
                        Color(.cyan).opacity(0.03)
                    ]),
                    startPoint: animateGradient ? .topLeading : .bottomTrailing,
                    endPoint: animateGradient ? .bottomTrailing : .topLeading
                )
                .clipShape(RoundedRectangle(cornerRadius: 24))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(.systemBlue).opacity(0.3),
                            Color(.cyan).opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(
            color: Color.black.opacity(0.08),
            radius: 16,
            x: 0,
            y: 8
        )
        .onAppear {
            // 单次 6 秒动画,完成后停在 .bottomTrailing 状态(不再 repeat),
            // 避免长期占用 CPU 持续 gradient 重算
            withAnimation(.easeInOut(duration: 6.0)) {
                animateGradient = true
            }
            recomputeStats()
        }
        .onChange(of: dataManager.grades) { _, _ in recomputeStats() }
        .onChange(of: dataManager.filteredExamSets) { _, _ in recomputeStats() }
    }

    /// 集中计算 average / upcoming count,避免 body 中多次 reduce
    private func recomputeStats() {
        if dataManager.grades.isEmpty {
            cachedAverageText = "N/A"
        } else {
            let total = dataManager.grades.reduce(0) { $0 + $1.score }
            let average = total / Double(dataManager.grades.count)
            cachedAverageText = String(format: "%.1f", average)
        }
        let now = Date()
        let twoWeeksFromNow = Calendar.current.date(byAdding: .day, value: 14, to: now) ?? now
        cachedUpcomingExamsCount = dataManager.filteredExamSets
            .filter { $0.examDate > now && $0.examDate <= twoWeeksFromNow }
            .count
    }
}

// MARK: - 单个统计项目
struct StatItemView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(color)
                }
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color(.systemBackground).opacity(0.6))
        .cornerRadius(16)
    }
}

// MARK: - 快捷操作卡片
struct QuickActionsCard: View {
    @EnvironmentObject var dataManager: DataManager
    /// 异步加载的头像数据，避免 body 中同步读文件
    @State private var avatarData: Data? = nil
    @State private var showingAddGrade = false
    @State private var showingNewExam = false
    @State private var showingNewMistake = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions".localized())
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            HStack(spacing: 12) {
                QuickActionButton(
                    title: "Add Grade".localized(),
                    icon: "plus.circle.fill",
                    color: .cyan,
                    action: { showingAddGrade = true }
                )
                
                QuickActionButton(
                    title: "New Exam".localized(),
                    icon: "calendar.badge.plus",
                    color: .purple,
                    action: { showingNewExam = true }
                )
                
                QuickActionButton(
                    title: "New Mistake".localized(),
                    icon: "pencil.tip.crop.circle.badge.plus",
                    color: .orange,
                    action: { showingNewMistake = true }
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(
            color: Color.black.opacity(0.05),
            radius: 10,
            x: 0,
            y: 4
        )
        .sheet(isPresented: $showingAddGrade) {
            AddGradeView()
                .environmentObject(dataManager)
                .adaptiveSheet()
        }
        .sheet(isPresented: $showingNewExam) {
            NewExamSetView()
                .adaptiveSheet()
        }
        .sheet(isPresented: $showingNewMistake) {
            NewMistakeSetView()
                .environmentObject(dataManager)
                .adaptiveSheet()
        }
    }
}

// MARK: - 快捷操作按钮
struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.2), color.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 60)
                    
                    Image(systemName: icon)
                        .font(.system(size: 28))
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 缩放按钮样式
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - 即将到来的考试区域
struct UpcomingExamsSection: View {
    @EnvironmentObject var dataManager: DataManager
    /// 异步加载的头像数据，避免 body 中同步读文件
    @State private var avatarData: Data? = nil
    
    var upcomingExams: [Exam] {
        let twoWeeksFromNow = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
        return dataManager.filteredExamSets
            .filter { $0.examDate > Date() && $0.examDate <= twoWeeksFromNow }
            .sorted { $0.examDate < $1.examDate }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Upcoming Exams".localized())
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(upcomingExams.count)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(.systemOrange), Color(.orange)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
            }
            
            VStack(spacing: 12) {
                ForEach(upcomingExams.prefix(3)) { exam in
                    CompactExamCard(exam: exam)
                        .equatable()
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(
            color: Color.black.opacity(0.05),
            radius: 10,
            x: 0,
            y: 4
        )
    }
}

// MARK: - 紧凑考试卡片
struct CompactExamCard: View, Equatable {
    let exam: Exam
    @State private var animateIn = false

    /// 只按 exam.id 比较，避免在 DataManager 变化时重建无关卡片
    /// Only compare by exam.id so unrelated DataManager changes don't rebuild this card.
    static func == (lhs: CompactExamCard, rhs: CompactExamCard) -> Bool {
        lhs.exam.id == rhs.exam.id
    }

    private var daysRemaining: Int {
        let components = Calendar.current.dateComponents([.day], from: Date(), to: exam.examDate)
        return max(0, components.day ?? 0)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(spacing: 4) {
                Text(dayString(from: exam.examDate))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(monthString(from: exam.examDate))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(width: 60)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
            
            VStack(alignment: .leading, spacing: 6) {
                Text(exam.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(exam.subject.localized())
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(.systemBlue).opacity(0.8), Color(.blue)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                    
                    Text(daysRemainingText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(daysRemaining <= 3 ? Color(.systemRed) : .secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(14)
        .background(Color(.systemBackground).opacity(0.6))
        .cornerRadius(14)
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 12)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                animateIn = true
            }
        }
    }
    
    private var daysRemainingText: String {
        if daysRemaining == 0 {
            return "Today!".localized()
        } else if daysRemaining == 1 {
            return "Tomorrow".localized()
        } else {
            return "\(daysRemaining) " + "days".localized()
        }
    }
    
    // 静态化 DateFormatter 避免每次调用新建(DateFormatter 初始化 ~1ms)
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()
    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()

    private func dayString(from date: Date) -> String {
        Self.dayFormatter.string(from: date)
    }

    private func monthString(from date: Date) -> String {
        Self.monthFormatter.string(from: date)
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

// MARK: - 最近成绩区域
struct RecentGradesSection: View {
    @EnvironmentObject var dataManager: DataManager
    /// 异步加载的头像数据，避免 body 中同步读文件
    @State private var avatarData: Data? = nil
    
    var recentGrades: [Grade] {
        Array(dataManager.grades.sorted { $0.date > $1.date }.prefix(5))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Grades".localized())
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            VStack(spacing: 10) {
                ForEach(recentGrades) { grade in
                    CompactGradeRow(grade: grade)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(
            color: Color.black.opacity(0.05),
            radius: 10,
            x: 0,
            y: 4
        )
    }
}

// MARK: - 紧凑成绩行
struct CompactGradeRow: View {
    let grade: Grade
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(scoreColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Text("\(Int(grade.score))")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(scoreColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(grade.subject.localized())
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(grade.date, style: .date)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let ranking = grade.ranking {
                Text("#\(ranking)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(.systemBackground).opacity(0.6))
        .cornerRadius(12)
    }
    
    private var scoreColor: Color {
        let rate = grade.scoreRate()
        if rate >= 0.85 { return .green }
        if rate >= 0.6 { return .orange }
        return .red
    }
}

// MARK: - 图表区域

/// 科目选择规则
enum SubjectSelectionRule {
    case lowestScore
    case mostGrades
    case recentMost
    case mostImprovement
    case random
}

/// 单科目趋势图表，用户通过 Menu 选择聚焦规则
struct ChartSectionView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var envManager: AppEnvironmentManager
    /// 异步加载的头像数据，避免 body 中同步读文件
    @State private var avatarData: Data? = nil
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var currentRule: SubjectSelectionRule = .lowestScore
    @State private var selectedSubject: String? = nil
    @State private var animateChart = false

    private var chartHeight: CGFloat {
        isIPad || sizeClass == .regular ? 260 : 180
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Subject Trend".localized())
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Menu {
                    Button(action: { selectSubject(rule: .lowestScore) }) {
                        Label("Focus: Lowest Score".localized(), systemImage: "chart.line.downtrend.xyaxis")
                    }
                    Button(action: { selectSubject(rule: .mostGrades) }) {
                        Label("Focus: Most Data".localized(), systemImage: "doc.text.fill")
                    }
                    Button(action: { selectSubject(rule: .recentMost) }) {
                        Label("Focus: Recent Activity".localized(), systemImage: "clock")
                    }
                    Button(action: { selectSubject(rule: .mostImprovement) }) {
                        Label("Focus: Improvement".localized(), systemImage: "chart.line.uptrend.xyaxis")
                    }
                    Button(action: { selectSubject(rule: .random) }) {
                        Label("Random Subject".localized(), systemImage: "shuffle")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(ruleDescription)
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            if let subject = selectedSubject, let grades = gradesForSubject(subject) {
                VStack(spacing: 12) {
                    HStack {
                        Text(subject.localized())
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(String(format: "%d records".localized(), grades.count))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    TrendChartView(
                        grades: grades.sorted(by: { $0.date < $1.date }),
                        fullScore: dataManager.fullScore(for: subject),
                        chartType: envManager.preferences.chartType,
                        tintColor: envManager.effectiveAccentColor
                    )
                    .frame(height: chartHeight)
                    .opacity(animateChart ? 1 : 0)
                    .offset(y: animateChart ? 0 : 20)
                    
                    HStack(spacing: 20) {
                        StatisticItem(title: "Average".localized(), value: String(format: "%.1f", averageScore(for: grades)), color: .cyan)
                        StatisticItem(title: "Highest".localized(), value: String(format: "%.1f", highestScore(for: grades)), color: .green)
                        StatisticItem(title: "Lowest".localized(), value: String(format: "%.1f", lowestScore(for: grades)), color: .orange)
                    }
                }
                .padding(16)
                .background(Color(.systemBackground).opacity(0.6))
                .cornerRadius(16)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("Select a subject to view trends".localized())
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color(.systemBackground).opacity(0.6))
                .cornerRadius(16)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(
            color: Color.black.opacity(0.05),
            radius: 10,
            x: 0,
            y: 4
        )
        .onAppear {
            selectSubject(rule: currentRule)
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                animateChart = true
            }
        }
    }

    private var ruleDescription: String {
        switch currentRule {
        case .lowestScore: return "Focus: Weakest".localized()
        case .mostGrades: return "Focus: Most Data".localized()
        case .recentMost: return "Focus: Recent".localized()
        case .mostImprovement: return "Focus: Improving".localized()
        case .random: return "Random".localized()
        }
    }
    
    private func selectSubject(rule: SubjectSelectionRule) {
        currentRule = rule

        let activeSubjects = Set(dataManager.grades.map { $0.subject })
        guard !activeSubjects.isEmpty else {
            selectedSubject = nil
            return
        }

        // 单次 O(n) 分组聚合,供 4 个 find* 方法复用,避免 N+1 嵌套 filter
        let aggregates = subjectAggregates(for: activeSubjects)

        switch rule {
        case .lowestScore:
            selectedSubject = aggregates.min { $0.value.average < $1.value.average }?.key
        case .mostGrades:
            selectedSubject = aggregates.max { $0.value.count < $1.value.count }?.key
        case .recentMost:
            selectedSubject = aggregates.max { $0.value.recentCount < $1.value.recentCount }?.key
        case .mostImprovement:
            // 改进分 = (last - first);需要至少 2 条成绩
            selectedSubject = aggregates.compactMap { (subject, agg) -> (String, Double)? in
                guard let first = agg.sortedAsc.first, let last = agg.sortedAsc.last,
                      agg.sortedAsc.count >= 2 else { return nil }
                return (subject, last.score - first.score)
            }.max { $0.1 < $1.1 }?.0
        case .random:
            selectedSubject = activeSubjects.randomElement()
        }

        animateChart = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animateChart = true
            }
        }
    }

    /// 一次扫所有 grades,按 subject 分组并预计算 avg / count / recentCount / sorted。
    /// 之前每个 find* 都 O(n*m) filter,合并后整体 O(n)。
    private func subjectAggregates(for subjects: Set<String>) -> [String: (average: Double, count: Int, recentCount: Int, sortedAsc: [Grade])] {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        // 单次 group by subject
        var groups: [String: [Grade]] = [:]
        for g in dataManager.grades {
            groups[g.subject, default: []].append(g)
        }
        var result: [String: (average: Double, count: Int, recentCount: Int, sortedAsc: [Grade])] = [:]
        for subject in subjects {
            guard let arr = groups[subject], !arr.isEmpty else { continue }
            let sortedAsc = arr.sorted { $0.date < $1.date }
            let total = sortedAsc.reduce(0.0) { $0 + $1.score }
            let average = total / Double(sortedAsc.count)
            let recentCount = sortedAsc.reduce(0) { $0 + ($1.date >= thirtyDaysAgo ? 1 : 0) }
            result[subject] = (average, sortedAsc.count, recentCount, sortedAsc)
        }
        return result
    }

    private func gradesForSubject(_ subject: String) -> [Grade]? {
        let grades = dataManager.grades.filter { $0.subject == subject }
        return grades.isEmpty ? nil : grades
    }

    private func averageScore(for grades: [Grade]) -> Double {
        grades.reduce(0) { $0 + $1.score } / Double(grades.count)
    }

    private func highestScore(for grades: [Grade]) -> Double {
        grades.max { $0.score < $1.score }?.score ?? 0
    }

    private func lowestScore(for grades: [Grade]) -> Double {
        grades.min { $0.score < $1.score }?.score ?? 0
    }
}

// MARK: - 统计项视图
struct StatisticItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 学习建议卡片
struct StudySuggestionsCard: View {
    @EnvironmentObject var dataManager: DataManager
    /// 异步加载的头像数据，避免 body 中同步读文件
    @State private var avatarData: Data? = nil
    @ObservedObject private var healthManager = HealthKitManager.shared
    @State private var suggestions: [StudySuggestion] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Study Suggestions".localized())
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.yellow)
            }

            if suggestions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("Start adding grades to get suggestions!".localized())
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(suggestions.prefix(3), id: \.id) { suggestion in
                        SuggestionRowView(suggestion: suggestion)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(
            color: Color.black.opacity(0.05),
            radius: 10,
            x: 0,
            y: 4
        )
        .onAppear {
            generateSuggestions()
        }
        .onChange(of: healthManager.bodyStatus) { _, _ in
            generateSuggestions()
        }
    }

    private func generateSuggestions() {
        var newSuggestions: [StudySuggestion] = []

        // 身体状况相关建议 (优先于纯成绩建议)
        if let bodySuggestion = makeBodyStatusSuggestion() {
            newSuggestions.append(bodySuggestion)
        }

        if let weakSubject = findWeakSubject() {
            newSuggestions.append(
                StudySuggestion(
                    icon: "exclamationmark.triangle.fill",
                    title: String(format: "Focus on %@".localized(), weakSubject.localized()),
                    description: "Your scores in this subject are lower than average. Spend more time reviewing key concepts.".localized(),
                    priority: .high,
                    color: .yellow
                )
            )
        }

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let urgentExams = dataManager.filteredExamSets.filter {
            Calendar.current.isDate($0.examDate, inSameDayAs: Date()) ||
            Calendar.current.isDate($0.examDate, inSameDayAs: tomorrow)
        }
        if !urgentExams.isEmpty {
            newSuggestions.append(
                StudySuggestion(
                    icon: "timer",
                    title: "Exam is almost here!".localized(),
                    description: String(format: "You have %d exam(s) today or tomorrow. Review your notes now!".localized(), urgentExams.count),
                    priority: .high,
                    color: .red
                )
            )
        }

        if let declining = findDecliningTrend() {
            newSuggestions.append(
                StudySuggestion(
                    icon: "chart.line.downtrend.xyaxis",
                    title: String(format: "%@ scores are slipping".localized(), declining.localized()),
                    description: "Your recent scores in this subject show a downward trend. Identify what's causing the gap.".localized(),
                    priority: .high,
                    color: .orange
                )
            )
        }

        let unreviewedMistakes = findUnreviewedMistakeSubjects()
        if !unreviewedMistakes.isEmpty {
            newSuggestions.append(
                StudySuggestion(
                    icon: "doc.text.magnifyingglass",
                    title: "Unreviewed Mistakes".localized(),
                    description: String(format: "You have mistakes in %@ that haven't been reviewed. Go through them before the next exam.".localized(), unreviewedMistakes.joined(separator: ", ").localized()),
                    priority: .high,
                    color: .purple
                )
            )
        } else if dataManager.mistakeSets.count >= 5 {
            newSuggestions.append(
                StudySuggestion(
                    icon: "book.fill",
                    title: "Review Mistakes".localized(),
                    description: String(format: "You have %d mistake note(s). Regular review helps prevent similar errors.".localized(), dataManager.mistakeSets.count),
                    priority: .medium,
                    color: .purple
                )
            )
        }

        let upcomingExams = dataManager.filteredExamSets.filter {
            $0.examDate > Date() &&
            $0.examDate <= Calendar.current.date(byAdding: .day, value: 14, to: Date())!
        }
        if !upcomingExams.isEmpty {
            newSuggestions.append(
                StudySuggestion(
                    icon: "calendar",
                    title: "Upcoming Exams".localized(),
                    description: String(format: "%d exam(s) in the next 2 weeks. Organize your review by subject priority.".localized(), upcomingExams.count),
                    priority: .medium,
                    color: .blue
                )
            )
        }

        if let improving = findImprovingTrend() {
            newSuggestions.append(
                StudySuggestion(
                    icon: "chart.line.uptrend.xyaxis",
                    title: String(format: "%@ is improving!".localized(), improving.localized()),
                    description: "Your scores are trending upward. Keep the momentum!".localized(),
                    priority: .medium,
                    color: .green
                )
            )
        }

        if let mistakeHeavy = findMistakeHeavySubject() {
            newSuggestions.append(
                StudySuggestion(
                    icon: "text.badge.checkmark",
                    title: String(format: "Deep dive into %@".localized(), mistakeHeavy.localized()),
                    description: "You have many mistakes in this subject. Categorize your errors to find the root pattern.".localized(),
                    priority: .medium,
                    color: .orange
                )
            )
        }

        if let lastGradeDate = dataManager.grades.map({ $0.date }).max(),
           Calendar.current.dateComponents([.day], from: lastGradeDate, to: Date()).day ?? 0 >= 7 {
            newSuggestions.append(
                StudySuggestion(
                    icon: "clock.arrow.circlepath",
                    title: "Keep the streak going!".localized(),
                    description: "No new grades in the past week. Regular tracking helps you spot trends early.".localized(),
                    priority: .low,
                    color: .cyan
                )
            )
        }

        if let strongSubject = findStrongSubject() {
            newSuggestions.append(
                StudySuggestion(
                    icon: "hand.thumbsup.fill",
                    title: String(format: "Great at %@!".localized(), strongSubject.localized()),
                    description: "Keep up the good work! You're performing really well in this subject.".localized(),
                    priority: .low,
                    color: .green
                )
            )
        }

        if dataManager.grades.count < 5 {
            newSuggestions.append(
                StudySuggestion(
                    icon: "plus.circle.fill",
                    title: "Add More Grades".localized(),
                    description: "Tracking more grades will help you get better insights into your learning progress.".localized(),
                    priority: .low,
                    color: .cyan
                )
            )
        }

        if let imbalanced = findImbalancedStudy() {
            newSuggestions.append(
                StudySuggestion(
                    icon: "scalemass",
                    title: "Balance your subjects".localized(),
                    description: String(format: "You have significantly more grades in %@ than other subjects. Don't neglect the rest.".localized(), imbalanced.localized()),
                    priority: .low,
                    color: .teal
                )
            )
        }

        suggestions = newSuggestions
    }

    // MARK: - Body-status driven suggestions
    /// Delegate to `StudyReadinessAlgorithm` (see
    /// `Managers/StudyReadinessAlgorithm.swift`). The algorithm
    /// combines HRV (primary) with sleep, resting heart rate,
    /// respiratory rate, today's exercise and recent activity, then
    /// calibrates every signal against the user's 30-day personal
    /// baseline (preferred) and an age-adjusted reference range
    /// (fallback).
    private func makeBodyStatusSuggestion() -> StudySuggestion? {
        StudyReadinessAlgorithm.recommend(
            hrvEnabled: healthManager.hrvEnabled,
            hrvOnboardingCompleted: healthManager.hrvOnboardingCompleted,
            isAuthorized: healthManager.isAuthorized,
            hrv: healthManager.readiness,
            bodyStatus: healthManager.bodyStatus,
            baselines: healthManager.personalBaselines,
            age: dataManager.profile.age
        )
    }
    
    private func findWeakSubject() -> String? {
        let subjects = Set(dataManager.grades.map { $0.subject })
        guard subjects.count >= 2 else { return nil }
        let aggregates = subjectAggregates()
        var lowestScore = Double.infinity
        var lowestSubject: String? = nil
        for (subject, agg) in aggregates where agg.sortedAsc.count >= 2 {
            if agg.average < lowestScore {
                lowestScore = agg.average
                lowestSubject = subject
            }
        }
        return lowestSubject
    }

    private func findStrongSubject() -> String? {
        let subjects = Set(dataManager.grades.map { $0.subject })
        guard !subjects.isEmpty else { return nil }
        let aggregates = subjectAggregates()
        var highestScore = -Double.infinity
        var highestSubject: String? = nil
        for (subject, agg) in aggregates where agg.sortedAsc.count >= 2 {
            if agg.average > highestScore {
                highestScore = agg.average
                highestSubject = subject
            }
        }
        return highestSubject
    }

    private func findDecliningTrend() -> String? {
        // 取每个 subject 最近 3 次成绩(sortedAsc.suffix(3)):
        // 期望 s0 > s1 > s2 且 s0 - s2 >= 5 → 持续下滑
        let aggregates = subjectAggregates()
        for (subject, agg) in aggregates where agg.sortedAsc.count >= 3 {
            let last3 = Array(agg.sortedAsc.suffix(3))
            let s0 = last3[0].score, s1 = last3[1].score, s2 = last3[2].score
            if s0 > s1, s1 > s2, s0 - s2 >= 5 {
                return subject
            }
        }
        return nil
    }

    private func findImprovingTrend() -> String? {
        // 取每个 subject 最近 3 次成绩:
        // 期望 s0 < s1 < s2 且 s2 - s0 >= 5 → 持续进步
        let aggregates = subjectAggregates()
        for (subject, agg) in aggregates where agg.sortedAsc.count >= 3 {
            let last3 = Array(agg.sortedAsc.suffix(3))
            let s0 = last3[0].score, s1 = last3[1].score, s2 = last3[2].score
            if s0 < s1, s1 < s2, s2 - s0 >= 5 {
                return subject
            }
        }
        return nil
    }

    private func findUnreviewedMistakeSubjects() -> [String] {
        // 单次 group by subject mistakes,然后查 aggregates 取 grades 数量
        var mistakeCounts: [String: Int] = [:]
        for m in dataManager.mistakeSets {
            mistakeCounts[m.subject, default: 0] += 1
        }
        let aggregates = subjectAggregates()
        var unreviewed: [String] = []
        for (subject, count) in mistakeCounts where count >= 3 {
            let gradeCount = aggregates[subject]?.count ?? 0
            if gradeCount == 0 {
                unreviewed.append(subject)
            }
        }
        return Array(unreviewed.prefix(2))
    }

    private func findMistakeHeavySubject() -> String? {
        // mistakes group by subject 一次
        var mistakeCounts: [String: Int] = [:]
        for m in dataManager.mistakeSets {
            mistakeCounts[m.subject, default: 0] += 1
        }
        let aggregates = subjectAggregates()
        let allSubjects = Set(mistakeCounts.keys).union(aggregates.keys)
        for subject in allSubjects {
            let mc = mistakeCounts[subject] ?? 0
            let gc = aggregates[subject]?.count ?? 0
            if mc >= 5 && mc > gc * 2 {
                return subject
            }
        }
        return nil
    }

    private func findImbalancedStudy() -> String? {
        let aggregates = subjectAggregates()
        guard aggregates.count >= 3 else { return nil }
        let sorted = aggregates.map { ($0.key, $0.value.count) }.sorted { $0.1 > $1.1 }
        guard let max = sorted.first else { return nil }
        let others = Array(sorted.dropFirst())
        let total = others.reduce(0) { $0 + $1.1 }
        let avgOthers = others.isEmpty ? 0 : total / others.count
        guard max.1 > avgOthers * 3 else { return nil }
        return max.0
    }

    /// 单次 group by subject 聚合 grades,供 StudySuggestionsCard 7 个 find* 复用。
    /// 之前每个 find* 都 O(n*m) filter 整个 grades,合并后整体 O(n)。
    private func subjectAggregates() -> [String: (average: Double, count: Int, recentCount: Int, sortedAsc: [Grade])] {
        var groups: [String: [Grade]] = [:]
        for g in dataManager.grades {
            groups[g.subject, default: []].append(g)
        }
        var result: [String: (average: Double, count: Int, recentCount: Int, sortedAsc: [Grade])] = [:]
        for (subject, arr) in groups where !arr.isEmpty {
            let sortedAsc = arr.sorted { $0.date < $1.date }
            let total = sortedAsc.reduce(0.0) { $0 + $1.score }
            let average = total / Double(sortedAsc.count)
            result[subject] = (average, sortedAsc.count, 0, sortedAsc)
        }
        return result
    }
}

// MARK: - 学习建议模型
// (Types are defined in `StudyReadinessAlgorithm.swift`; see
// `StudySuggestion`, `StudyIntensity`, `StudyFocus`, and
// `StudyReadinessAlgorithm`.)

// MARK: - 建议行视图
struct SuggestionRowView: View {
    let suggestion: StudySuggestion
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(suggestion.color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: suggestion.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(suggestion.color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(suggestion.description)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(isExpanded ? nil : 2)
                }
                
                Spacer()
                
                PriorityIndicator(priority: suggestion.priority)
            }
            
            if !isExpanded {
                Button(action: { isExpanded = true }) {
                    Text("Read more".localized())
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(14)
        .background(Color(.systemBackground).opacity(0.6))
        .cornerRadius(14)
    }
}

// MARK: - 优先级指示器
struct PriorityIndicator: View {
    let priority: StudySuggestion.Priority
    
    var body: some View {
        ZStack {
            Capsule()
                .fill(color.opacity(0.15))
            
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
        }
        .frame(height: 20)
    }
    
    private var label: String {
        switch priority {
        case .high: return "HIGH".localized()
        case .medium: return "MED".localized()
        case .low: return "LOW".localized()
        }
    }
    
    private var color: Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .green
        }
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
    HomeView(selectedTab: .constant(0))
        .environmentObject(DataManager())
        .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    HomeView(selectedTab: .constant(0))
        .environmentObject(DataManager())
        .preferredColorScheme(.dark)
}
