//
//  MistakeToolbar.swift
//  StudyPulse
//
//  Created for the MistakeView refactoring.
//

import SwiftUI

struct TagDueEntry: Identifiable {
    var id: String { tag }
    let tag: String
    let count: Int
}

struct MistakeListToolbarLeading: ToolbarContent {
    let totalEnrolled: Int
    let dueCount: Int
    let dueTags: [TagDueEntry]
    let onFilterSelect: (FlashcardFilter) -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            if totalEnrolled > 0 {
                Menu {
                    Button {
                        onFilterSelect(.dueQueue)
                    } label: {
                        Label("Review All Due".localized(), systemImage: "rectangle.stack")
                    }
                    if !dueTags.isEmpty {
                        Divider()
                        Text("Review by Tag".localized())
                        ForEach(dueTags) { entry in
                            Button {
                                onFilterSelect(.tag(entry.tag))
                            } label: {
                                Label("#\(entry.tag) (\(entry.count))", systemImage: "tag")
                            }
                        }
                    }
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "rectangle.stack")
                        if dueCount > 0 {
                            Text("\(dueCount)")
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
    }
}

struct MistakeListToolbarTrailing: ToolbarContent {
    let hasMistakes: Bool
    let hasTags: Bool
    let onShowTagGraph: () -> Void
    let onShowPDFExport: () -> Void
    let onShowNewMistake: () -> Void
    let onShowAIQuiz: () -> Void
    let container: RepositoryContainer

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 12) {
                Button(action: onShowAIQuiz) {
                    Image(systemName: "sparkles.rectangle.stack")
                }
                .accessibilityLabel("AI Quiz".localized())

                if hasTags {
                    Button(action: onShowTagGraph) {
                        Image(systemName: "circle.hexagongrid")
                    }
                    .accessibilityLabel("Tag Graph".localized())
                }
                if hasMistakes {
                    Button(action: onShowPDFExport) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Export PDF".localized())
                }
                if UIDevice.current.userInterfaceIdiom == .pad {
                    NavigationLink {
                        NewMistakeSetView(container: container, usesInternalNavigationStack: false)
                            .environment(container)
                            .adaptiveSheet()
                    } label: {
                        Image(systemName: "plus")
                    }
                } else {
                    Button(action: onShowNewMistake) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

struct MistakeDetailToolbar: ToolbarContent {
    @Environment(RepositoryContainer.self) private var container
    let liveMistake: MistakeNote
    let isLLMConfigured: Bool
    let onEdit: () -> Void
    let onQuickReview: () -> Void
    let onAIAnalysis: () -> Void
    let onAISimilarQuestion: () -> Void

    var body: some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigationBarTrailing) {
                if UIDevice.current.userInterfaceIdiom == .pad {
                    NavigationLink {
                        MistakeDetailEditView(
                            container: container,
                            mistakeSet: liveMistake,
                            usesInternalNavigationStack: false
                        )
                        .adaptiveSheet()
                    } label: {
                        Text("Edit".localized())
                    }
                } else {
                    Button("Edit".localized(), action: onEdit)
                }
            }
            if liveMistake.isInReviewQueue {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: onQuickReview) {
                        Image(systemName: "rectangle.stack")
                    }
                    .accessibilityLabel("Quick Review".localized())
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: onAIAnalysis) {
                        Label("AI 解析错因".localized(), systemImage: "sparkles.magnifyingglass")
                    }
                    Button(action: onAISimilarQuestion) {
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
                        Capsule().fill(Color.teal.opacity(isLLMConfigured ? 0.18 : 0.08))
                    )
                    .foregroundColor(isLLMConfigured ? .teal : .secondary)
                }
                .accessibilityLabel("AI Analysis".localized())
            }
        }
    }
}
