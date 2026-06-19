//
//  MistakeView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import SwiftUI
import Combine
import UIKit

// MARK: - 一级菜单：科目列表
struct MistakeView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingNewMistakeSet = false
    @State private var searchText = ""
    
    // 按科目分组错题
    var subjectGroups: [String: [MistakeNote]] {
        Dictionary(grouping: dataManager.mistakeSets) { $0.subject.isEmpty ? "Uncategorized" : $0.subject }
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
        dataManager.mistakeSets.count
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if dataManager.mistakeSets.isEmpty {
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
                            // 统计概览
                            if searchText.isEmpty {
                                OverviewStatsCard(totalCount: totalMistakeCount, subjectCount: sortedSubjects.count)
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewMistakeSet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewMistakeSet) {
                NewMistakeSetView()
                    .environmentObject(dataManager)
                    .adaptiveSheet()
            }
            .background(Color(.systemGroupedBackground))
        }
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
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
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
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
                
                LinearGradient(
                    colors: [
                        Color(.systemPurple).opacity(0.08),
                        Color(.systemPurple).opacity(0.02)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        )
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
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
                                Color(.systemPurple),
                                Color(.systemPurple).opacity(0.7)
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
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
                
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(.systemPurple).opacity(0.25),
                                Color(.systemPurple).opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
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
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemGroupedBackground))
                
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(.systemPurple).opacity(0.25),
                                Color(.systemPurple).opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .shadow(
            color: Color.black.opacity(0.05),
            radius: 6,
            x: 0,
            y: 3
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
    @State private var showingEditSheet = false
    
    var body: some View {
        List {
            // Basic Info Section
            Section(header: Text("Details".localized())) {
                HStack {
                    Text("Title".localized())
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(mistakeSet.title)
                        .fontWeight(.medium)
                }
                
                if !mistakeSet.subject.isEmpty {
                    HStack {
                        Text("Subject".localized())
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(mistakeSet.subject.localized())
                            .fontWeight(.medium)
                    }
                }
                
                if !mistakeSet.source.isEmpty {
                    HStack {
                        Text("Source".localized())
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(mistakeSet.source)
                    }
                }
                
                HStack {
                    Text("Date".localized())
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(mistakeSet.date.formatted(date: .abbreviated, time: .omitted))
                }
            }
            
            // Question Section
            if !mistakeSet.originalQuestion.isEmpty {
                Section(header: Text("Original Question".localized())) {
                    if #available(iOS 15.0, *) {
                        Text(mistakeSet.originalQuestion)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(mistakeSet.originalQuestion)
                    }
                    
                    if !mistakeSet.questionImages.isEmpty {
                        imageScrollView(images: mistakeSet.questionImages)
                    }
                }
            }
            
            // Error Reason Section
            if !mistakeSet.errorReason.isEmpty {
                Section(header: Text("Error Reason".localized())) {
                    Text(mistakeSet.errorReason)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if !mistakeSet.reasonImages.isEmpty {
                        imageScrollView(images: mistakeSet.reasonImages)
                    }
                }
            }
            
            // Wrong Solution Section
            if !mistakeSet.wrongSolution.isEmpty {
                Section(header: Text("Wrong Solution".localized())) {
                    Text(mistakeSet.wrongSolution)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(.red)
                    
                    if !mistakeSet.wrongSolutionImages.isEmpty {
                        imageScrollView(images: mistakeSet.wrongSolutionImages)
                    }
                }
            }
            
            // Correct Solution Section
            if !mistakeSet.correctSolution.isEmpty {
                Section(header: Text("Correct Solution".localized())) {
                    Text(mistakeSet.correctSolution)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(.green)
                    
                    if !mistakeSet.correctSolutionImages.isEmpty {
                        imageScrollView(images: mistakeSet.correctSolutionImages)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(mistakeSet.title)
        .navigationBarTitleDisplayMode(.inline)
        .adaptiveMaxWidth(820)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit".localized()) {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            MistakeDetailEditView(mistakeSet: mistakeSet)
                .adaptiveSheet()
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
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
                
                LinearGradient(
                    colors: [
                        Color(.systemPurple).opacity(0.08),
                        Color(.systemPurple).opacity(0.02)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemPurple).opacity(0.25), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
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
