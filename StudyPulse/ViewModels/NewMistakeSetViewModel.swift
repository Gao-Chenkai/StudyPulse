//
//  NewMistakeSetViewModel.swift
//  StudyPulse
//
//  Created by Antigravity on 2026/7/12.
//

import Foundation
import SwiftUI
import Combine
import UIKit

@MainActor
final class NewMistakeSetViewModel: ObservableObject {
    // MARK: - Dependencies
    private let container: RepositoryContainer

    // MARK: - Form States
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
    
    @Published var selectedSection: EditSection = .question
    
    // Image states
    @Published var questionImages: [UIImage] = []
    @Published var reasonImages: [UIImage] = []
    @Published var wrongSolutionImages: [UIImage] = []
    @Published var correctSolutionImages: [UIImage] = []
    
    // OCR & Sheet states
    @Published var showingImagePicker = false
    @Published var showingPhotoCapture = false
    @Published var showingHandwritingSheet = false
    @Published var isProcessingOCR = false
    @Published var showingOCRAlert = false
    @Published var ocrErrorMessage = ""
    @Published var reviewEnabled = true

    // MARK: - Init
    init(container: RepositoryContainer) {
        self.container = container
        if let first = availableSubjects.first {
            selectedSubject = first
        }
    }

    func presetValues(subject: String, title: String) {
        self.selectedSubject = subject
        self.editedTitle = title
    }

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

    // MARK: - Computed Properties
    var availableSubjects: [String] {
        container.subjectRepo.subjects.filter { $0.enabled }.map { $0.name }
    }

    var isSaveDisabled: Bool {
        editedTitle.isEmpty || editedOriginalQuestion.isEmpty
    }

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

    // MARK: - Actions
    func addImageToCurrentSection(_ image: UIImage) {
        switch selectedSection {
        case .question: questionImages.append(image)
        case .reason: reasonImages.append(image)
        case .wrong: wrongSolutionImages.append(image)
        case .correct: correctSolutionImages.append(image)
        }
    }

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
                        currentSectionTextBinding.wrappedValue = currentText + "\n\n" + recognizedText
                    } else {
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
            questionImages: questionImages.compactMap { $0.jpegData(compressionQuality: 0.8) },
            reasonImages: reasonImages.compactMap { $0.jpegData(compressionQuality: 0.8) },
            wrongSolutionImages: wrongSolutionImages.compactMap { $0.jpegData(compressionQuality: 0.8) },
            correctSolutionImages: correctSolutionImages.compactMap { $0.jpegData(compressionQuality: 0.8) },
            reviewState: reviewEnabled ? .initial() : nil,
            difficulty: max(0, min(DifficultyPicker.maxStars, editedDifficulty)),
            tags: editedTags
        )
        container.addMistake(newMistake)

        // Reschedule reviews
        if reviewEnabled {
            SRSReviewNotifications.shared.rescheduleAll(mistakes: container.mistakeRepo.mistakeSets)
        }
    }
}
