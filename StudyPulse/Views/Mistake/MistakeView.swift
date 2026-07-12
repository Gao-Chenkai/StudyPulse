//
//  MistakeView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import SwiftUI
import Combine
import UIKit
import SwiftStreamingMarkdown
import UniformTypeIdentifiers

// MARK: - 一级菜单：科目列表
struct MistakeView: View {
    @Environment(RepositoryContainer.self) private var container
    @StateObject private var viewModel: MistakeViewModel
    @State private var showingNewMistakeSet = false
    @State private var showingFlashcards = false
    /// 闪卡过滤模式（默认 .dueQueue，复习入口按钮 / 工具栏切换可改）
    @State private var flashcardFilter: FlashcardFilter = .dueQueue
    /// 标签图谱 full-screen
    @State private var showingTagGraph = false

    // PDF 导出状态
    @State private var showingPDFExportSheet = false
    @State private var pendingPDFSnapshot: MistakePDFSnapshot?
    @State private var isExportingPDF = false
    @State private var pdfDocument: MistakePDFDocument?
    @State private var pdfErrorMessage: String?

    // 派生数据已迁移到 MistakeViewModel。View 通过 $viewModel.searchText 与 VM 双向绑定搜索词。

    init(container: RepositoryContainer) {
        _viewModel = StateObject(wrappedValue: MistakeViewModel.makeDefault(container: container))
    }

    var body: some View {
        NavigationStack {
            Group {
                if container.mistakeRepo.filteredMistakeSets.isEmpty {
                    VStack(spacing: 24) {
                        ContentUnavailableView(
                            "No Mistakes".localized(),
                            systemImage: "exclamationmark.triangle",
                            description: Text("Tap '+' to add a new mistake note.".localized())
                        )

                        Spacer()
                    }
                    .background(Color(.systemGroupedBackground))

                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 24) {
                            // 待复习横幅（搜索时不显示）
                            if viewModel.searchText.isEmpty {
                                OverviewStatsCard(totalCount: viewModel.groups.totalCount, subjectCount: viewModel.groups.sortedSubjects.count)
                                    .padding(.horizontal)
                            }

                            // SRS 待复习入口
                            if viewModel.searchText.isEmpty && viewModel.srsOverview.dueCount > 0 {
                                DueReviewBanner(overview: viewModel.srsOverview) {
                                    flashcardFilter = .dueQueue
                                    showingFlashcards = true
                                }
                                .padding(.horizontal)
                            }

                            // 标签横向 chip section(顶部)
                            // 出现在非搜索场景下。点击 chip 把搜索词设为 #tag,
                            // 复用已有搜索过滤逻辑(由 MistakeFilter + searchInSubject 识别)
                            let allTags = MistakeFilter.allTags(container.mistakeRepo.filteredMistakeSets)
                            if !allTags.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "tag.fill")
                                            .foregroundColor(.purple)
                                        Text("Tags".localized())
                                            .font(.headline)
                                        Spacer()
                                        if allTags.count > 0 {
                                            Button {
                                                showingTagGraph = true
                                            } label: {
                                                Label("Tag Graph".localized(), systemImage: "circle.hexagongrid")
                                                    .font(.caption.weight(.medium))
                                                    .foregroundStyle(Color.purple)
                                            }
                                        }
                                    }
                                    .padding(.horizontal)

                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(Array(allTags.enumerated()), id: \.element) { _, tag in
                                                Button {
                                                    viewModel.searchText = "#\(tag)"
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
                                .padding(.horizontal)
                            }

                            // 科目列表
                            VStack(alignment: .leading, spacing: 12) {
                                Text(viewModel.searchText.isEmpty ? "Subjects".localized() : "Search Results".localized())
                                    .font(.headline)
                                    .padding(.horizontal)

                                LazyVStack(spacing: 12) {
                                    ForEach(viewModel.groups.filteredSubjects, id: \.self) { subject in
                                        NavigationLink(destination: SubjectMistakesView(subject: subject, mistakes: viewModel.groups.bySubject[subject] ?? [])) {
                                            SubjectCardView(subject: subject, mistakes: viewModel.groups.bySubject[subject] ?? [])
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                        // iPad 上撑满 detail 区宽度
                        .frame(maxWidth: .infinity)
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .containerBackground(.clear, for: .navigation)
            .debugModeContainer()
            .debugLayoutBoundsAuto()
            .navigationTitle("Mistakes".localized())
            .searchable(text: $viewModel.searchText, prompt: "Search subjects or mistakes...".localized())
            // 派生数据重算:搜索/数据源变化时触发
            .onAppear { viewModel.recompute() }
            .onChange(of: viewModel.searchText) { _, _ in viewModel.recompute() }
            .onChange(of: container.mistakeRepo.filteredMistakeSets) { _, _ in viewModel.recompute() }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if viewModel.srsOverview.totalEnrolled > 0 {
                        Menu {
                            Button {
                                flashcardFilter = .dueQueue
                                showingFlashcards = true
                            } label: {
                                Label("Review All Due".localized(), systemImage: "rectangle.stack")
                            }
                            let dueByTag = topTagsDue(tagFilter: { tag in
                                let due = SRSAlgorithm.dueMistakes(from: container.mistakeRepo.mistakeSets)
                                return MistakeFilter.tagged(due, tag: tag)
                            })
                            if !dueByTag.isEmpty {
                                Divider()
                                Text("Review by Tag".localized())
                                ForEach(Array(dueByTag.prefix(5)), id: \.tag) { entry in
                                    Button {
                                        flashcardFilter = .tag(entry.tag)
                                        showingFlashcards = true
                                    } label: {
                                        Label("#\(entry.tag) (\(entry.count))", systemImage: "tag")
                                    }
                                }
                            }
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "rectangle.stack")
                                if viewModel.srsOverview.dueCount > 0 {
                                    Text("\(viewModel.srsOverview.dueCount)")
                                        .font(.system(size: 10).weight(.bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(
                                            Capsule().fill(Color.red)
                                        )
                                        .offset(x: 8, y: -6)
                                }
                            }
                        }
                        .accessibilityLabel("Flashcard Review".localized())
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        if !MistakeFilter.allTags(container.mistakeRepo.filteredMistakeSets).isEmpty {
                            Button {
                                showingTagGraph = true
                            } label: {
                                Image(systemName: "circle.hexagongrid")
                            }
                            .accessibilityLabel("Tag Graph".localized())
                        }
                        if !container.mistakeRepo.filteredMistakeSets.isEmpty {
                            Button {
                                showingPDFExportSheet = true
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                            }
                            .accessibilityLabel("Export PDF".localized())
                        }
                        // iPad 用 NavigationLink 推到 NewMistakeSetView(传 false 让它别再包自己的 stack);
                        // iPhone 继续走 Button + sheet(sheet 仍然挂在下方 modifier)。
                        // iPad: NavigationLink to NewMistakeSetView (pass false so it
                        // doesn't double-wrap the stack); iPhone: Button + .sheet below.
                        if UIDevice.current.userInterfaceIdiom == .pad {
                            NavigationLink {
                                NewMistakeSetView(usesInternalNavigationStack: false)
                                    .environment(container)
                                    .adaptiveSheet()
                            } label: {
                                Image(systemName: "plus")
                            }
                        } else {
                            Button(action: { showingNewMistakeSet = true }) {
                                Image(systemName: "plus")
                            }
                        }
                    }
                }
                ToolbarItem(placement: .principal) {
                    PhaseSelectorView()
                }
            }
            .sheet(isPresented: $showingNewMistakeSet) {
                NewMistakeSetView()
                    .adaptiveSheet()
            }
            .sheet(isPresented: $showingPDFExportSheet) {
                MistakePDFExportSheet { options in
                    handlePDFExport(options: options)
                }
                .adaptiveSheet()
            }
            .sheet(item: $pendingPDFSnapshot) { snapshot in
                MistakePDFGenerationView(
                    snapshot: snapshot,
                    onCompleted: { data in
                        presentPDFExportSheet(data: data)
                    },
                    onError: { message in
                        pdfErrorMessage = message
                    }
                )
                .interactiveDismissDisabled(true)
            }
            .alert("Export Failed".localized(), isPresented: Binding(
                get: { pdfErrorMessage != nil },
                set: { if !$0 { pdfErrorMessage = nil } }
            )) {
                Button("OK".localized()) { pdfErrorMessage = nil }
            } message: {
                Text(pdfErrorMessage ?? "")
            }
            .fileExporter(
                isPresented: $isExportingPDF,
                document: pdfDocument,
                contentType: .pdf,
                defaultFilename: pdfDocument?.fileName
            ) { result in
                switch result {
                case .success(let url):
                    Log.record(.info, category: "Export", message: "错题 PDF 分享成功 / Mistake PDF shared: url=\(url.path)")
                case .failure(let error):
                    Log.record(.error, category: "Export", message: "错题 PDF 分享失败 / Mistake PDF share failed: \(error.localizedDescription)")
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    pdfDocument = nil
                }
            }
            .fullScreenCover(isPresented: $showingFlashcards) {
                NavigationStack {
                    FlashcardStudyView(filter: flashcardFilter)
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
            .fullScreenCover(isPresented: $showingTagGraph) {
                TagGraphView(
                    mistakes: container.mistakeRepo.filteredMistakeSets,
                    onSelectTag: { tag in
                        viewModel.searchText = "#\(tag)"
                        showingTagGraph = false
                    }
                )
            }
            .background(Color(.systemGroupedBackground))
        }
    }

    // MARK: - Tag helpers

    /// 顶 5 个有 due 错题的标签 + 数量
    private struct TagDueEntry {
        let tag: String
        let count: Int
    }

    private func topTagsDue(tagFilter: (String) -> [MistakeNote]) -> [TagDueEntry] {
        let tags = MistakeFilter.allTags(container.mistakeRepo.filteredMistakeSets)
        var entries: [TagDueEntry] = []
        for tag in tags {
            let count = tagFilter(tag).count
            if count > 0 {
                entries.append(TagDueEntry(tag: tag, count: count))
            }
        }
        return entries.sorted { $0.count > $1.count }
    }

    // MARK: - PDF Export flow

    /// 选项 sheet 回调：构建快照并弹出进度 sheet。
    private func handlePDFExport(options: MistakeExportOptions) {
        guard let snapshot = MistakePDFSnapshot.make(
            from: container,
            selection: options.selection,
            includeImages: options.includeImages
        ) else {
            pdfErrorMessage = "No mistakes match the current selection.".localized()
            return
        }
        pendingPDFSnapshot = snapshot
    }

    /// 进度 sheet 回调：弹 fileExporter 分享 PDF。
    private func presentPDFExportSheet(data: Data) {
        let fileName = "StudyPulse_Mistakes_\(DateFormatters.fileTimestamp.string(from: Date())).pdf"
        pdfDocument = MistakePDFDocument(data: data, fileName: fileName)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isExportingPDF = true
        }
    }
}

// MARK: - Due Review Banner

/// 「待复习」横幅：突出显示到期的错题数量，引导用户进入闪卡模式
struct DueReviewBanner: View {
    let overview: SRSOverview
    let onStart: () -> Void

    var body: some View {
        Button(action: onStart) {
            HStack(spacing: 14) {
                // 图标
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
                    Text(String(format: "%d due · %d upcoming this week".localized(), overview.dueCount, overview.upcomingCount))
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
        .buttonStyle(.plain)
        .debugLayoutBoundsAuto()
    }
}

// MARK: - 二级菜单：科目下的错题列表
struct SubjectMistakesView: View {
    let subject: String
    let mistakes: [MistakeNote]
    @StateObject private var viewModel: SubjectMistakesViewModel
    @State private var searchText = ""

    init(subject: String, mistakes: [MistakeNote]) {
        self.subject = subject
        self.mistakes = mistakes
        _viewModel = StateObject(wrappedValue: SubjectMistakesViewModel(initialMistakes: mistakes))
    }

    // filteredMistakes / sortedMistakes / suggestedForReview 全部迁移到 SubjectMistakesViewModel
    private var filteredMistakes: [MistakeNote] {
        viewModel.searchInSubject(mistakes, searchText: searchText)
    }
    private var sortedMistakes: [MistakeNote] { filteredMistakes }
    private var suggestedForReview: [MistakeNote] {
        viewModel.suggestedForReview(mistakes)
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                // 科目统计卡片
                SubjectOverviewCard(subject: subject, mistakes: sortedMistakes)
                    .padding(.horizontal)

                // 科目下所有 tag 横向 chip section(未搜索时显示)
                // 点击 chip → 把搜索词设为 #tag
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

                // 建议复习的题目
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

                // 错题列表
                VStack(alignment: .leading, spacing: 12) {
                    Text(searchText.isEmpty ? String(format: "All Mistakes (%d)".localized(), sortedMistakes.count) : String(format: "Search Results (%d)".localized(), filteredMistakes.count))
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
            .padding(.vertical)
            // iPad 上限制最大宽度并居中
            .adaptiveMaxWidth(900)
        }
        .navigationTitle(subject.localized())
        .searchable(text: $searchText, prompt: "Search mistakes...".localized())
        .background(Color(.systemGroupedBackground))
        .debugLayoutBoundsAuto()
    }
}

// MARK: - 概览统计卡片
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
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

// MARK: - 科目概览卡片
struct SubjectOverviewCard: View {
    let subject: String
    let mistakes: [MistakeNote]
    
    var lastWeekCount: Int {
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return mistakes.filter { $0.date > oneWeekAgo }.count
    }
    
    var oldestDate: Date? {
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
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

// MARK: - 统计项组件
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

// MARK: - 科目卡片组件
struct SubjectCardView: View {
    let subject: String
    let mistakes: [MistakeNote]
    @State private var animateIn = false

    /// 随机主题色：基于科目名哈希在调色板中取色，每次启动 App 会重新分配
    private static let palette: [Color] = [
        .red, .orange, .yellow, .green, .mint, .teal,
        .blue, .indigo, .purple, .pink, .brown, .cyan
    ]

    private var iconColor: Color {
        let hash = abs(subject.hashValue)
        return Self.palette[hash % Self.palette.count]
    }

    var recentCount: Int {
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return mistakes.filter { $0.date > oneWeekAgo }.count
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // 图标
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                iconColor,
                                iconColor.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)

                Image(systemName: "folder.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            
            // 内容
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
            
            // 箭头
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Color(UIColor.tertiaryLabel))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
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

// MARK: - Mistake Card View
struct MistakeCardView: View {
    let mistake: MistakeNote
    @State private var animateIn = false
    
    var totalImageCount: Int {
        mistake.questionImages.count + mistake.reasonImages.count +
        mistake.wrongSolutionImages.count + mistake.correctSolutionImages.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title and date row
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

                    // 标签胶囊(列表紧凑模式,最多 3 个)
                    if !mistake.tags.isEmpty {
                        TagChipsView(tags: mistake.tags, compact: true, maxVisible: 3)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(mistake.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if totalImageCount > 0 {
                        Label("\(totalImageCount)", systemImage: "photo.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // 难度小星条(右上角,5 颗)
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

            // Preview of original question
            if !mistake.originalQuestion.isEmpty {
                Text(mistake.originalQuestion)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .padding(.top, 2)
            }

            // Source
            if !mistake.source.isEmpty {
                Text(String(format: "Source: %@".localized(), mistake.source))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
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

// MARK: - Mistake Detail View
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

    /// 始终从 mistakeRepo 里取最新快照（错题标题/内容/掌握度等可能
    /// 在闪卡复习后被异步更新），这样 MasteryCurveView 才会随 review 实时刷新。
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
            ToolbarItem(placement: .navigationBarTrailing) {
                // iPad 用 NavigationLink 推到 MistakeDetailEditView(传 false 让它别再包自己的 stack);
                // iPhone 继续走 Button + sheet。
                // iPad: NavigationLink to MistakeDetailEditView (pass false so it
                // doesn't double-wrap the stack); iPhone: Button + .sheet below.
                if UIDevice.current.userInterfaceIdiom == .pad {
                    NavigationLink {
                        MistakeDetailEditView(
                            mistakeSet: liveMistake,
                            usesInternalNavigationStack: false
                        )
                        .adaptiveSheet()
                    } label: {
                        Text("Edit".localized())
                    }
                } else {
                    Button("Edit".localized()) {
                        showingEditSheet = true
                    }
                }
            }
        }
        .toolbar {
            if liveMistake.isInReviewQueue {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingQuickReview = true
                    } label: {
                        Image(systemName: "rectangle.stack")
                    }
                    .accessibilityLabel("Quick Review".localized())
                }
            }
        }
        .toolbar {
            // AI 解析按钮(直接显示在详情页,无需进入编辑页)
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingAIAnalysis = true
                    } label: {
                        Label("AI 解析错因".localized(), systemImage: "sparkles.magnifyingglass")
                    }
                    Button {
                        showingAISimilarQuestion = true
                    } label: {
                        Label("AI 相似题组卷".localized(), systemImage: "doc.badge.gearshape")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("AI".localized())
                            .font(.caption.weight(.bold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(Color.teal.opacity(envManager.llmConfig.isConfigured ? 0.18 : 0.08))
                    )
                    .foregroundColor(envManager.llmConfig.isConfigured ? .teal : .secondary)
                }
                .accessibilityLabel("AI Analysis".localized())
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            MistakeDetailEditView(mistakeSet: liveMistake)
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
                    // 把"正确思路"段写回错题数据库(详情页直接写)
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
                    // 稍微延迟,等 sheet 关闭动画完成
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
                FlashcardStudyView(filter: .single(liveMistake))
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
            // 每次进入详情页曝光 +1
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

    /// 为"AI 解析 · 深入探讨" sheet 构造上下文
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

/// 缩略图组件：使用缓存避免重复解码
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
        // 先查缓存
        if let cached = ImageCache.shared.getImage(data) {
            uiImage = cached
            return
        }
        // 后台生成缩略图
        let task = Task.detached(priority: .userInitiated) {
            ImageCache.thumbnail(from: data, maxDimension: 300)
        }
        let thumbnail = await task.value
        guard let thumb = thumbnail else { return }
        ImageCache.shared.putImage(thumb, data)
        await MainActor.run { uiImage = thumb }
    }
}

// MARK: - 建议复习的错题卡片
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

                // 难度小星条
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

            // 标签胶囊(紧凑)
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

#Preview {
    MistakeView(container: RepositoryContainer())
        .environment(RepositoryContainer())
}
