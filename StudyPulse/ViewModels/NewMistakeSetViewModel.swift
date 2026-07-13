//
//  NewMistakeSetViewModel.swift
//  StudyPulse
//
//  Created by Antigravity on 2026/7/12.
//
//  新增错题 ViewModel。负责"题面/错因/错误解法/正确解法"四区表单、
//  图片 / OCR / 手写 sheet,以及保存 + SRS 初始化。
//  New-mistake VM. Four-section form (question/reason/wrong/correct),
//  image/OCR/handwriting sheets, save + SRS init.
//

import Foundation
import SwiftUI
import Combine
import UIKit

@MainActor
final class NewMistakeSetViewModel: ObservableObject {
    // MARK: - 依赖项 / Dependencies
    private let container: RepositoryContainer

    // MARK: - 表单状态 / Form state
    @Published var editedTitle = ""
    @Published var selectedSubject = ""
    @Published var editedOriginalQuestion = ""
    @Published var editedSource = ""
    @Published var editedErrorReason = ""
    @Published var editedWrongSolution = ""
    @Published var editedCorrectSolution = ""
    @Published var editedDate = Date()
    @Published var editedDifficulty = 0
    @Published var editedTags: [String] = []

    /// 当前正在编辑的分区 / The section currently being edited.
    @Published var selectedSection: EditSection = .question

    // MARK: - 图片状态 / Image state
    @Published var questionImages: [UIImage] = []
    @Published var reasonImages: [UIImage] = []
    @Published var wrongSolutionImages: [UIImage] = []
    @Published var correctSolutionImages: [UIImage] = []

    // MARK: - OCR & 弹窗状态 / OCR & sheet state
    @Published var showingImagePicker = false
    @Published var showingPhotoCapture = false
    @Published var showingHandwritingSheet = false
    @Published var isProcessingOCR = false
    @Published var showingOCRAlert = false
    @Published var ocrErrorMessage = ""
    /// 新建错题是否直接加入复习队列 / Join the review queue immediately?
    @Published var reviewEnabled = true

    // MARK: - 初始化 / Initialization
    /// 默认选中第一个可用科目 / Pre-selects the first available subject.
    init(container: RepositoryContainer) {
        self.container = container
        if let first = availableSubjects.first {
            selectedSubject = first
        }
    }

    /// 从外部预填 subject + title(供 Siri / 快捷指令等入口)
    /// Pre-fills subject & title from an external entry (Siri / Shortcuts, etc.).
    func presetValues(subject: String, title: String) {
        self.selectedSubject = subject
        self.editedTitle = title
    }

    /// 用示例错题覆盖表单(模板/示例库使用)
    /// Overwrite the form with a sample mistake (for templates / sample library).
    func seedSampleMistake(_ sample: SampleMistake) {
        self.editedTitle = sample.title
        self.selectedSubject = sample.subject
        self.editedOriginalQuestion = sample.originalQuestion
        self.editedSource = sample.source
        self.editedErrorReason = sample.errorReason
        self.editedWrongSolution = sample.wrongSolution
        self.editedCorrectSolution = sample.correctSolution
        self.editedDate = sample.date
        self.selectedSection = sample.selectedSection
    }

    // MARK: - 计算属性 / Computed properties
    /// 启用的科目名列表 / Enabled subject names.
    var availableSubjects: [String] {
        container.subjectRepo.subjects.filter { $0.enabled }.map { $0.name }
    }

    /// 是否禁用"保存"按钮 / Whether the save button is disabled.
    var isSaveDisabled: Bool {
        editedTitle.isEmpty || editedOriginalQuestion.isEmpty
    }

    /// 当前选中分区的文字绑定(路由到对应字段)
    /// Text binding for the current section (routed to the matching field).
    var currentSectionTextBinding: Binding<String> {
        Binding(
            get: {
                switch self.selectedSection {
                case .question: return self.editedOriginalQuestion
                case .reason: return self.editedErrorReason
                case .wrong: return self.editedWrongSolution
                case .correct: return self.editedCorrectSolution
                }
            },
            set: { newValue in
                switch self.selectedSection {
                case .question: self.editedOriginalQuestion = newValue
                case .reason: self.editedErrorReason = newValue
                case .wrong: self.editedWrongSolution = newValue
                case .correct: self.editedCorrectSolution = newValue
                }
            }
        )
    }

    /// 当前选中分区的图片数组绑定
    /// Image-array binding for the current section.
    var currentSectionImagesBinding: Binding<[UIImage]> {
        Binding(
            get: {
                switch self.selectedSection {
                case .question: return self.questionImages
                case .reason: return self.reasonImages
                case .wrong: return self.wrongSolutionImages
                case .correct: return self.correctSolutionImages
                }
            },
            set: { newValue in
                switch self.selectedSection {
                case .question: self.questionImages = newValue
                case .reason: self.reasonImages = newValue
                case .wrong: self.wrongSolutionImages = newValue
                case .correct: self.correctSolutionImages = newValue
                }
            }
        )
    }

    // MARK: - 操作 / Actions
    /// 把图片追加到当前选中分区
    /// Append an image to the current section.
    func addImageToCurrentSection(_ image: UIImage) {
        switch selectedSection {
        case .question: questionImages.append(image)
        case .reason: reasonImages.append(image)
        case .wrong: wrongSolutionImages.append(image)
        case .correct: correctSolutionImages.append(image)
        }
    }

    /// 触发 OCR:取当前分区的最后一张图片,识别文字并追加到该分区的文字字段
    /// Trigger OCR: take the last image, recognize, append to text field.
    func triggerOCR() {
        let currentImages = currentSectionImagesBinding.wrappedValue
        guard let lastImage = currentImages.last else { return }
        isProcessingOCR = true

        Task {
            do {
                let recognizedText = try await OCRManager.recognizeText(in: lastImage)
                if !recognizedText.isEmpty {
                    let currentText = currentSectionTextBinding.wrappedValue
                    if !currentText.isEmpty {
                        // 已有内容 → 空行分隔追加 / Append with blank-line sep.
                        currentSectionTextBinding.wrappedValue = currentText + "\n\n" + recognizedText
                    } else {
                        // 空白 → 直接填充 / Fill directly when empty.
                        currentSectionTextBinding.wrappedValue = recognizedText
                    }
                }
            } catch {
                ocrErrorMessage = error.localizedDescription
                showingOCRAlert = true
            }
            isProcessingOCR = false
        }
    }

    /// 把当前表单保存为新错题:可选初始化 SRS 状态 + 通知重排
    /// Persist the form as a new mistake: optionally init SRS + reschedule.
    func saveMistake() {
        let newMistake = MistakeNote(
            title: editedTitle.isEmpty ? "Untitled".localized() : editedTitle,
            subject: selectedSubject,
            originalQuestion: editedOriginalQuestion,
            source: editedSource,
            date: editedDate,
            errorReason: editedErrorReason,
            wrongSolution: editedWrongSolution,
            correctSolution: editedCorrectSolution,
            // UIImage → JPEG Data,0.8 是质量 / 体积折中值
            // 0.8 is a quality / size trade-off.
            questionImages: questionImages.compactMap { $0.jpegData(compressionQuality: 0.8) },
            reasonImages: reasonImages.compactMap { $0.jpegData(compressionQuality: 0.8) },
            wrongSolutionImages: wrongSolutionImages.compactMap { $0.jpegData(compressionQuality: 0.8) },
            correctSolutionImages: correctSolutionImages.compactMap { $0.jpegData(compressionQuality: 0.8) },
            // 启用复习 → 用 .initial() 初始化 SRS;否则不进入复习队列
            // Review enabled → init SRS with .initial(); else skip the queue.
            reviewState: reviewEnabled ? .initial() : nil,
            // 难度裁剪到合法范围 / Clamp difficulty to legal range.
            difficulty: max(0, min(DifficultyPicker.maxStars, editedDifficulty)),
            tags: editedTags
        )
        container.addMistake(newMistake)

        // 重排复习通知 / Reschedule review notifications.
        if reviewEnabled {
            SRSReviewNotifications.shared.rescheduleAll(mistakes: container.mistakeRepo.mistakeSets)
        }
    }
}
