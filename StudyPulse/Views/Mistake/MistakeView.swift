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
    @EnvironmentObject var dataManager: DataManager
    @State private var showingNewMistakeSet = false
    @State private var showingFlashcards = false
    @State private var searchText = ""

    // PDF 导出状态
    @State private var showingPDFExportSheet = false
    @State private var pendingPDFSnapshot: MistakePDFSnapshot?
    @State private var isExportingPDF = false
    @State private var pdfDocument: MistakePDFDocument?
    @State private var pdfErrorMessage: String?

    // 按科目分组错题
    var subjectGroups: [String: [MistakeNote]] {
        Dictionary(grouping: dataManager.filteredMistakeSets) { $0.subject.isEmpty ? "Uncategorized" : $0.subject }
    }

    // 科目列表（按错题数降序排列）
    var sortedSubjects: [String] {
        subjectGroups.keys.sorted { a, b in
            let countA = subjectGroups[a]?.count ?? 0
            let countB = subjectGroups[b]?.count ?? 0
            if countA != countB {
                return countA > countB
            }
            return a.localizedCompare(b) == .orderedAscending
        }
    }

    // 搜索过滤
    var filteredSubjects: [String] {
        if searchText.isEmpty {
            return sortedSubjects
        }
        return sortedSubjects.filter { subject in
            subject.localizedCaseInsensitiveContains(searchText) ||
            (subjectGroups[subject]?.contains {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.originalQuestion.localizedCaseInsensitiveContains(searchText)
            } ?? false)
        }
    }

    var totalMistakeCount: Int {
        dataManager.filteredMistakeSets.count
    }

    /// SRS 队列总览
    var srsOverview: SRSOverview {
        SRSAlgorithm.overview(from: dataManager.filteredMistakeSets)
    }

    var body: some View {
        NavigationStack {
            Group {
                if dataManager.filteredMistakeSets.isEmpty {
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
                            if searchText.isEmpty {
                                OverviewStatsCard(totalCount: totalMistakeCount, subjectCount: sortedSubjects.count)
                                    .padding(.horizontal)
                            }

                            // SRS 待复习入口
                            if searchText.isEmpty && srsOverview.dueCount > 0 {
                                DueReviewBanner(overview: srsOverview) {
                                    showingFlashcards = true
                                }
                                .padding(.horizontal)
                            }

                            // 科目列表
                            VStack(alignment: .leading, spacing: 12) {
                                Text(searchText.isEmpty ? "Subjects".localized() : "Search Results".localized())
                                    .font(.headline)
                                    .padding(.horizontal)

                                LazyVStack(spacing: 12) {
                                    ForEach(filteredSubjects, id: \.self) { subject in
                                        NavigationLink(destination: SubjectMistakesView(subject: subject, mistakes: subjectGroups[subject] ?? [])) {
                                            SubjectCardView(subject: subject, mistakes: subjectGroups[subject] ?? [])
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
            .navigationTitle("Mistakes".localized())
            .searchable(text: $searchText, prompt: "Search subjects or mistakes...".localized())
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if srsOverview.totalEnrolled > 0 {
                        Button {
                            showingFlashcards = true
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "rectangle.stack")
                                if srsOverview.dueCount > 0 {
                                    Text("\(srsOverview.dueCount)")
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
                        if !dataManager.filteredMistakeSets.isEmpty {
                            Button {
                                showingPDFExportSheet = true
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                            }
                            .accessibilityLabel("Export PDF".localized())
                        }
                        Button(action: { showingNewMistakeSet = true }) {
                            Image(systemName: "plus")
                        }
                    }
                }
                ToolbarItem(placement: .principal) {
                    PhaseSelectorView()
                }
            }
            .sheet(isPresented: $showingNewMistakeSet) {
                NewMistakeSetView()
                    .environmentObject(dataManager)
                    .adaptiveSheet()
            }
            .sheet(isPresented: $showingPDFExportSheet) {
                MistakePDFExportSheet { options in
                    handlePDFExport(options: options)
                }
                .environmentObject(dataManager)
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
                .environmentObject(dataManager)
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
            .background(Color(.systemGroupedBackground))
        }
    }

    // MARK: - PDF Export flow

    /// 选项 sheet 回调：构建快照并弹出进度 sheet。
    private func handlePDFExport(options: MistakeExportOptions) {
        guard let snapshot = MistakePDFSnapshot.make(
            from: dataManager,
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
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let fileName = "StudyPulse_Mistakes_\(formatter.string(from: Date())).pdf"
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
    }
}

// MARK: - 二级菜单：科目下的错题列表
struct SubjectMistakesView: View {
    let subject: String
    let mistakes: [MistakeNote]
    @EnvironmentObject var dataManager: DataManager
    @State private var searchText = ""
    
    var filteredMistakes: [MistakeNote] {
        if searchText.isEmpty {
            return mistakes.sorted { $0.date > $1.date }
        }
        return mistakes.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.originalQuestion.localizedCaseInsensitiveContains(searchText) ||
            $0.source.localizedCaseInsensitiveContains(searchText)
        }.sorted { $0.date > $1.date }
    }
    
    var sortedMistakes: [MistakeNote] {
        filteredMistakes.sorted { $0.date > $1.date }
    }
    
    // 建议复习的题目
    var suggestedForReview: [MistakeNote] {
        let allMistakes = sortedMistakes
        
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        
        return allMistakes.sorted { a, b in
            let priorityA = (a.date > oneWeekAgo ? 2 : a.date < oneMonthAgo ? 1 : 0)
            let priorityB = (b.date > oneWeekAgo ? 2 : b.date < oneMonthAgo ? 1 : 0)
            
            if priorityA != priorityB {
                return priorityA > priorityB
            }
            return a.date > b.date
        }.prefix(4).map { $0 }
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                // 科目统计卡片
                SubjectOverviewCard(subject: subject, mistakes: sortedMistakes)
                    .padding(.horizontal)

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
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var envManager: AppEnvironmentManager
    @State private var showingEditSheet = false
    @State private var showingQuickReview = false

    /// 始终从 dataManager 里取最新快照（错题标题/内容/掌握度等可能
    /// 在闪卡复习后被异步更新），这样 MasteryCurveView 才会随 review 实时刷新。
    private var liveMistake: MistakeNote {
        dataManager.mistakeSets.first(where: { $0.id == mistakeSet.id }) ?? mistakeSet
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
                Button("Edit".localized()) {
                    showingEditSheet = true
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
        .sheet(isPresented: $showingEditSheet) {
            MistakeDetailEditView(mistakeSet: liveMistake)
                .adaptiveSheet()
        }
        .fullScreenCover(isPresented: $showingQuickReview) {
            NavigationStack {
                FlashcardStudyView(filter: .single(liveMistake))
                    .environmentObject(dataManager)
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
            dataManager.recordMistakeExposure(mistakeSet.id)
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
    MistakeView()
        .environmentObject(DataManager())
}
