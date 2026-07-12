//
//  MistakeView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/23.
//

import SwiftUI
import UniformTypeIdentifiers

/// 错题列表主视图
struct MistakeView: View {
    @Environment(RepositoryContainer.self) private var container
    @StateObject private var viewModel: MistakeViewModel

    init(container: RepositoryContainer) {
        _viewModel = StateObject(wrappedValue: MistakeViewModel.makeDefault(container: container))
    }

    // MARK: - Empty State

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
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - List Content

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

                tagSection

                subjectsList
            }
            .padding(.vertical)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
    }

    @ViewBuilder
    private var srsBanner: some View {
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
            let headerText: String = viewModel.searchText.isEmpty
                ? "Subjects".localized()
                : "Search Results".localized()
            Text(headerText)
                .font(.headline)
                .padding(.horizontal)

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

    // MARK: - Sheets & Covers

    @ViewBuilder
    private var sheetsAndCovers: some View {
        Color.clear
            .sheet(isPresented: $viewModel.showingNewMistakeSet) {
                NewMistakeSetView(container: container)
                    .adaptiveSheet()
            }
            .sheet(isPresented: $viewModel.showingPDFExportSheet) {
                MistakePDFExportSheet { options in
                    viewModel.handlePDFExport(options: options)
                }
                .adaptiveSheet()
            }
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
            .alert("Export Failed".localized(), isPresented: $viewModel.showingExportError) {
                Button("OK".localized()) { viewModel.pdfErrorMessage = nil }
            } message: {
                Text(viewModel.pdfErrorMessage ?? "")
            }
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
        Color.clear
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
            .fullScreenCover(isPresented: $viewModel.showingTagGraph) {
                TagGraphView(
                    mistakes: container.mistakeRepo.filteredMistakeSets,
                    onSelectTag: { tag in
                        viewModel.searchText = "#\(tag)"
                        viewModel.showingTagGraph = false
                    }
                )
            }
    }

    // MARK: - Plus Button (View, for ToolbarItem)

    @ViewBuilder
    private var plusButton: some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            NavigationLink {
                NewMistakeSetView(container: container, usesInternalNavigationStack: false)
                    .environment(container)
                    .adaptiveSheet()
            } label: {
                Image(systemName: "plus")
            }
        } else {
            Button(action: { viewModel.showingNewMistakeSet = true }) {
                Image(systemName: "plus")
            }
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Group {
                    if container.mistakeRepo.filteredMistakeSets.isEmpty {
                        emptyView
                    } else {
                        listView
                    }
                }

                sheetsAndCovers.frame(width: 0, height: 0).hidden()
                fullScreenCovers.frame(width: 0, height: 0).hidden()
            }
            .containerBackground(.clear, for: .navigation)
            .debugModeContainer()
            .debugLayoutBoundsAuto()
            .navigationTitle("Mistakes".localized())
            .searchable(text: $viewModel.searchText, prompt: "Search subjects or mistakes...".localized())
            .onAppear { viewModel.recompute() }
            .onChange(of: viewModel.searchText) { _, _ in viewModel.recompute() }
            .onChange(of: container.mistakeRepo.filteredMistakeSets) { _, _ in viewModel.recompute() }
            .toolbar {
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
                MistakeListToolbarTrailing(
                    hasMistakes: !container.mistakeRepo.filteredMistakeSets.isEmpty,
                    hasTags: !MistakeFilter.allTags(container.mistakeRepo.filteredMistakeSets).isEmpty,
                    onShowTagGraph: { viewModel.showingTagGraph = true },
                    onShowPDFExport: { viewModel.showingPDFExportSheet = true },
                    onShowNewMistake: { viewModel.showingNewMistakeSet = true },
                    container: container
                )
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    plusButton
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    PhaseSelectorView()
                }
            }
            .background(Color(.systemGroupedBackground))
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
            cardHeader
            cardDetails
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
                Text(mistake.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)

                if totalImageCount > 0 {
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
