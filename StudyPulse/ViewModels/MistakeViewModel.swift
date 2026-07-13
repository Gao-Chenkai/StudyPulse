//
//  MistakeViewModel.swift
//  StudyPulse
//
//  Created by Antigravity on 2026/7/12.
//
//  错题列表页 ViewModel。负责按搜索词分组 + SRS 总览 + PDF 导出流。
//  Mistake-list page VM. Search grouping, SRS overview, PDF export flow.
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class MistakeViewModel: ObservableObject {
    // MARK: - 依赖项 / Dependencies
    private let container: RepositoryContainer

    // MARK: - 输入 & 界面状态 / Input & UI states
    /// 顶部搜索框的当前文本 / Current search field text.
    @Published var searchText: String = ""
    /// 是否显示"新增错题"弹窗 / Show the "new mistake" sheet?
    @Published var showingNewMistakeSet = false
    /// 是否显示闪卡学习页 / Show flashcard study page?
    @Published var showingFlashcards = false
    /// 闪卡页的筛选器 / Flashcard filter.
    @Published var flashcardFilter: FlashcardFilter = .dueQueue
    /// 是否显示标签关系图 sheet / Show tag-graph sheet?
    @Published var showingTagGraph = false
    /// 是否显示智能思维导图 sheet / Show Auto Mind Map sheet?
    @Published var showingAutoMindMap = false

    // MARK: - PDF 导出状态 / PDF export state
    @Published var showingPDFExportSheet = false
    @Published var pendingPDFSnapshot: MistakePDFSnapshot?
    @Published var isExportingPDF = false
    @Published var pdfDocument: MistakePDFDocument?
    @Published var pdfErrorMessage: String? {
        didSet {
            if pdfErrorMessage != nil {
                // 任意错误都会自动打开错误 alert / Auto-open alert on error.
                showingExportError = true
            }
        }
    }
    @Published var showingExportError = false

    // MARK: - 输出状态 / Output states
    /// 当前过滤 + 搜索后的分组结果(按科目分桶)
    /// Filtered + searched group result (bucketed by subject).
    @Published private(set) var groups: MistakeGroups = .empty
    /// SRS 总览 / SRS overview.
    @Published private(set) var srsOverview: SRSOverview = .empty

    // MARK: - 初始化 / Initialization
    init(container: RepositoryContainer) {
        self.container = container
    }

    /// 工厂方法 / Factory.
    static func makeDefault(container: RepositoryContainer) -> MistakeViewModel {
        MistakeViewModel(container: container)
    }

    // MARK: - 业务逻辑 / Business logic
    /// 集中重算 `groups` + `srsOverview` / Recompute groups & srsOverview.
    func recompute() {
        let filteredMistakes = container.mistakeRepo.filteredMistakeSets
        groups = MistakeFilter.group(
            mistakes: filteredMistakes,
            searchText: searchText
        )
        srsOverview = SRSAlgorithm.overview(from: filteredMistakes)
    }

    /// 单科目内的搜索(代理到 Service) / Per-subject search (delegated).
    func searchInSubject(_ mistakes: [MistakeNote]) -> [MistakeNote] {
        MistakeFilter.searchInSubject(mistakes, searchText: searchText)
    }

    /// 复习建议(代理到 Service) / Review suggestions (delegated).
    func suggestedForReview(_ mistakes: [MistakeNote]) -> [MistakeNote] {
        MistakeFilter.suggestedForReview(mistakes)
    }

    /// 各标签下"到期可复习"的错题计数(按数量降序)
    /// Per-tag counts of "due for review" (descending).
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

    /// 处理 PDF 导出:先尝试生成 snapshot,失败时记录错误
    /// Handle PDF export: try to build the snapshot, log error on failure.
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

    /// 准备好 PDF 文档并延迟一帧后打开分享 sheet
    /// Prepare the PDF doc and open the share sheet after a 1-frame delay.
    func presentPDFExportSheet(data: Data) {
        let fileName = "StudyPulse_Mistakes_\(DateFormatters.fileTimestamp.string(from: Date())).pdf"
        pdfDocument = MistakePDFDocument(data: data, fileName: fileName)
        // 50ms 延迟:等 SwiftUI 绑定到 pdfDocument 完成后再开 sheet
        // 50ms delay: let SwiftUI finish binding before opening the sheet.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.isExportingPDF = true
        }
    }

    /// 取出某科目下的错题(SubjectMistakesView 用)
    /// Return mistakes under a subject (used by SubjectMistakesView).
    func viewModelSubjectMistakes(subject: String) -> [MistakeNote] {
        groups.bySubject[subject] ?? []
    }

    /// 记录导出 / 分享结果(成功 / 失败)
    /// Log the export / share result.
    func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            Log.record(.info, category: "Export", message: "错题 PDF 分享成功 / Mistake PDF shared: url=\(url.path)")
        case .failure(let error):
            Log.record(.error, category: "Export", message: "错题 PDF 分享失败 / Mistake PDF share failed: \(error.localizedDescription)")
        }
        // 100ms 延迟:让分享 sheet 关闭动画结束后再清掉 pdfDocument
        // 100ms delay: wait for share-sheet close animation to finish.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.pdfDocument = nil
        }
    }
}

private extension MistakeGroups {
    /// 空分组占位(初始值) / Empty-group placeholder (initial value).
    static let empty = MistakeGroups(
        bySubject: [:],
        sortedSubjects: [],
        filteredSubjects: [],
        totalCount: 0
    )
}
