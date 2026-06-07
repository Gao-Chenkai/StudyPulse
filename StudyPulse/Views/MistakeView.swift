//
//  MistakeView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import SwiftUI
import Combine
import UIKit

struct MistakeView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingNewMistakeSet = false
    @State private var searchText = ""
    
    var filteredMistakes: [MistakeNote] {
        if searchText.isEmpty {
            return dataManager.mistakeSets.sorted { $0.date > $1.date }
        }
        return dataManager.mistakeSets.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.originalQuestion.localizedCaseInsensitiveContains(searchText) ||
            $0.source.localizedCaseInsensitiveContains(searchText) ||
            $0.subject.localizedCaseInsensitiveContains(searchText)
        }.sorted { $0.date > $1.date }
    }
    
    // 建议复习的题目
    var suggestedForReview: [MistakeNote] {
        let allMistakes = dataManager.mistakeSets.sorted { $0.date > $1.date }
        
        // 按照优先级排序：
        // 1. 最近一周添加的
        // 2. 超过一个月的
        // 3. 其他
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
        NavigationView {
            Group {
                if filteredMistakes.isEmpty && searchText.isEmpty {
                    VStack(spacing: 24) {
                        ContentUnavailableView(
                            "No Mistakes",
                            systemImage: "exclamationmark.triangle",
                            description: Text("Tap '+' to add a new mistake note.")
                        )
                        
                        Spacer()
                    }
                    .background(Color(.systemGroupedBackground))
                    
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 24) {
                            // 建议复习的题目
                            if !suggestedForReview.isEmpty && searchText.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "book.circle.fill")
                                            .foregroundColor(.purple)
                                        Text("Suggested for Review")
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
                            
                            // 所有错题列表
                            VStack(alignment: .leading, spacing: 12) {
                                Text(searchText.isEmpty ? "All Mistakes" : "Search Results")
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
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("Mistakes")
            .searchable(text: $searchText, prompt: "Search mistakes...")
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
            }
            .background(Color(.systemGroupedBackground))
        }
    }
    
    private func deleteMistakeSets(offsets: IndexSet) {
        for index in offsets {
            let mistake = filteredMistakes[index]
            dataManager.deleteMistake(mistake)
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
                Text("Source: \(mistake.source)")
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
            Section(header: Text("Details")) {
                HStack {
                    Text("Title")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(mistakeSet.title)
                        .fontWeight(.medium)
                }
                
                if !mistakeSet.subject.isEmpty {
                    HStack {
                        Text("Subject")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(mistakeSet.subject.localized())
                            .fontWeight(.medium)
                    }
                }
                
                if !mistakeSet.source.isEmpty {
                    HStack {
                        Text("Source")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(mistakeSet.source)
                    }
                }
                
                HStack {
                    Text("Date")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(mistakeSet.date.formatted(date: .abbreviated, time: .omitted))
                }
            }
            
            // Question Section
            if !mistakeSet.originalQuestion.isEmpty {
                Section(header: Text("Original Question")) {
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
                Section(header: Text("Error Reason")) {
                    Text(mistakeSet.errorReason)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if !mistakeSet.reasonImages.isEmpty {
                        imageScrollView(images: mistakeSet.reasonImages)
                    }
                }
            }
            
            // Wrong Solution Section
            if !mistakeSet.wrongSolution.isEmpty {
                Section(header: Text("Wrong Solution")) {
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
                Section(header: Text("Correct Solution")) {
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            MistakeDetailEditView(dataManager: dataManager, mistakeSet: mistakeSet)
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
    @State private var animateIn = false
    
    var reviewPriority: String {
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        
        if mistake.date > oneWeekAgo {
            return "🔴 High Priority"
        } else if mistake.date < oneMonthAgo {
            return "🟡 Review Soon"
        } else {
            return "🟢 Normal"
        }
    }
    
    var daysSinceAdded: String {
        let components = Calendar.current.dateComponents([.day], from: mistake.date, to: Date())
        let days = components.day ?? 0
        if days == 0 {
            return "Today"
        } else if days == 1 {
            return "Yesterday"
        } else {
            return "\(days) days ago"
        }
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
        .frame(width: 180)
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
