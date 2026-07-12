//
//  MistakeViewModel.swift
//  StudyPulse
//
//  Created by Antigravity on 2026/7/12.
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class MistakeViewModel: ObservableObject {
    // MARK: - Dependencies
    private let container: RepositoryContainer

    // MARK: - Input/UI States
    @Published var searchText: String = ""
    @Published var showingNewMistakeSet = false
    @Published var showingFlashcards = false
    @Published var flashcardFilter: FlashcardFilter = .dueQueue
    @Published var showingTagGraph = false

    // PDF Export States
    @Published var showingPDFExportSheet = false
    @Published var pendingPDFSnapshot: MistakePDFSnapshot?
    @Published var isExportingPDF = false
    @Published var pdfDocument: MistakePDFDocument?
    @Published var pdfErrorMessage: String? {
        didSet {
            if pdfErrorMessage != nil {
                showingExportError = true
            }
        }
    }
    @Published var showingExportError = false

    // MARK: - Output States
    @Published private(set) var groups: MistakeGroups = .empty
    @Published private(set) var srsOverview: SRSOverview = .empty

    // MARK: - Init
    init(container: RepositoryContainer) {
        self.container = container
    }

    static func makeDefault(container: RepositoryContainer) -> MistakeViewModel {
        MistakeViewModel(container: container)
    }

    // MARK: - Logic
    func recompute() {
        let filteredMistakes = container.mistakeRepo.filteredMistakeSets
        groups = MistakeFilter.group(
            mistakes: filteredMistakes,
            searchText: searchText
        )
        srsOverview = SRSAlgorithm.overview(from: filteredMistakes)
    }

    func searchInSubject(_ mistakes: [MistakeNote]) -> [MistakeNote] {
        MistakeFilter.searchInSubject(mistakes, searchText: searchText)
    }

    func suggestedForReview(_ mistakes: [MistakeNote]) -> [MistakeNote] {
        MistakeFilter.suggestedForReview(mistakes)
    }

    func topTagsDue() -> [TagDueEntry] {
        let due = SRSAlgorithm.dueMistakes(from: container.mistakeRepo.mistakeSets)
        let tags = MistakeFilter.allTags(container.mistakeRepo.filteredMistakeSets)
        var entries: [TagDueEntry] = []
        for tag in tags {
            let count = MistakeFilter.tagged(due, tag: tag).count
            if count > 0 {
                entries.append(TagDueEntry(tag: tag, count: count))
            }
        }
        return entries.sorted { $0.count > $1.count }
    }

    func handlePDFExport(options: MistakeExportOptions) {
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

    func presentPDFExportSheet(data: Data) {
        let fileName = "StudyPulse_Mistakes_\(DateFormatters.fileTimestamp.string(from: Date())).pdf"
        pdfDocument = MistakePDFDocument(data: data, fileName: fileName)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.isExportingPDF = true
        }
    }

    func viewModelSubjectMistakes(subject: String) -> [MistakeNote] {
        groups.bySubject[subject] ?? []
    }

    func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            Log.record(.info, category: "Export", message: "错题 PDF 分享成功 / Mistake PDF shared: url=\(url.path)")
        case .failure(let error):
            Log.record(.error, category: "Export", message: "错题 PDF 分享失败 / Mistake PDF share failed: \(error.localizedDescription)")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.pdfDocument = nil
        }
    }
}

private extension MistakeGroups {
    static let empty = MistakeGroups(
        bySubject: [:],
        sortedSubjects: [],
        filteredSubjects: [],
        totalCount: 0
    )
}
