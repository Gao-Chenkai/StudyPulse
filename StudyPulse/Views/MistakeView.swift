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
    
    var body: some View {
        NavigationView {
            Group {
                if filteredMistakes.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty ? "No Mistakes" : "No Results",
                        systemImage: "exclamationmark.triangle",
                        description: Text(searchText.isEmpty ? "Tap '+' to add a new mistake note." : "Try adjusting your search.")
                    )
                    .background(Color(.systemGroupedBackground))
                    
                } else {
                    List {
                        ForEach(filteredMistakes) { mistake in
                            NavigationLink(destination: MistakeSetDetailView(mistakeSet: mistake)) {
                                MistakeCardView(mistake: mistake)
                            }
                        }
                        .onDelete(perform: deleteMistakeSets)
                    }
                    .listStyle(.insetGrouped)
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
    
    var totalImageCount: Int {
        mistake.questionImages.count + mistake.reasonImages.count +
        mistake.wrongSolutionImages.count + mistake.correctSolutionImages.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title and date row
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mistake.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if !mistake.subject.isEmpty {
                        Text(mistake.subject.localized())
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemPurple).opacity(0.15))
                            .foregroundColor(Color(.systemPurple))
                            .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(mistake.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if totalImageCount > 0 {
                        Label("\(totalImageCount)", systemImage: "photo")
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
            }
            
            // Source
            if !mistake.source.isEmpty {
                Text("Source: \(mistake.source)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
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

#Preview {
    MistakeView()
        .environmentObject(DataManager())
}
