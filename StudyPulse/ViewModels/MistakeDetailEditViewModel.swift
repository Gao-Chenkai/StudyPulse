//
//  MistakeDetailEditViewModel.swift
//  StudyPulse
//
//  Created by Antigravity on 2026/7/12.
//

import Foundation
import SwiftUI
import Combine
import UIKit

@MainActor
final class MistakeDetailEditViewModel: ObservableObject {
    // MARK: - Dependencies
    private let container: RepositoryContainer
    let mistakeSet: MistakeNote

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
    @Published var audioFileName: String?
    
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
    @Published var showingAudioRecordingSheet = false
    @Published var isProcessingOCR = false
    @Published var showingOCRAlert = false
    @Published var ocrErrorMessage = ""
    @Published var reviewEnabled = false
    @Published var showingAIAnalysis = false

    // MARK: - Init
    init(container: RepositoryContainer, mistakeSet: MistakeNote) {
        self.container = container
        self.mistakeSet = mistakeSet
        initializeData()
    }

    private func initializeData() {
        editedTitle = mistakeSet.title
        selectedSubject = mistakeSet.subject
        editedOriginalQuestion = mistakeSet.originalQuestion
        editedSource = mistakeSet.source
        editedErrorReason = mistakeSet.errorReason
        editedWrongSolution = mistakeSet.wrongSolution
        editedCorrectSolution = mistakeSet.correctSolution
        editedDate = mistakeSet.date
        editedDifficulty = mistakeSet.difficulty
        editedTags = mistakeSet.tags
        audioFileName = mistakeSet.audioFileName

        questionImages = mistakeSet.questionImages.compactMap { UIImage(data: $0) }
        reasonImages = mistakeSet.reasonImages.compactMap { UIImage(data: $0) }
        wrongSolutionImages = mistakeSet.wrongSolutionImages.compactMap { UIImage(data: $0) }
        correctSolutionImages = mistakeSet.correctSolutionImages.compactMap { UIImage(data: $0) }

        reviewEnabled = mistakeSet.isInReviewQueue
    }

    // MARK: - Computed Properties
    var availableSubjects: [String] {
        container.subjectRepo.subjects.filter { $0.enabled }.map { $0.name }
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

    func deleteVoiceMemo() {
        if let filename = audioFileName {
            AudioStorage.delete(filename: filename)
            audioFileName = nil
        }
    }

    func saveChanges() {
        var updatedMistake = mistakeSet
        updatedMistake.title = editedTitle
        updatedMistake.subject = selectedSubject
        updatedMistake.originalQuestion = editedOriginalQuestion
        updatedMistake.source = editedSource
        updatedMistake.errorReason = editedErrorReason
        updatedMistake.wrongSolution = editedWrongSolution
        updatedMistake.correctSolution = editedCorrectSolution
        updatedMistake.date = editedDate
        updatedMistake.difficulty = max(0, min(DifficultyPicker.maxStars, editedDifficulty))
        updatedMistake.tags = editedTags
        updatedMistake.audioFileName = audioFileName

        updatedMistake.questionImages = questionImages.compactMap { $0.jpegData(compressionQuality: 0.8) }
        updatedMistake.reasonImages = reasonImages.compactMap { $0.jpegData(compressionQuality: 0.8) }
        updatedMistake.wrongSolutionImages = wrongSolutionImages.compactMap { $0.jpegData(compressionQuality: 0.8) }
        updatedMistake.correctSolutionImages = correctSolutionImages.compactMap { $0.jpegData(compressionQuality: 0.8) }

        // Sync SRS
        if reviewEnabled && !updatedMistake.isInReviewQueue {
            updatedMistake.reviewState = .initial()
        } else if !reviewEnabled && updatedMistake.isInReviewQueue {
            if var state = updatedMistake.reviewState {
                state.nextReviewDate = Date.distantFuture
                updatedMistake.reviewState = state
            }
        }

        container.mistakeRepo.update(updatedMistake)

        // Reschedule/cancel notification
        if reviewEnabled {
            SRSReviewNotifications.shared.rescheduleAll(mistakes: container.mistakeRepo.mistakeSets)
        } else {
            SRSReviewNotifications.shared.cancel(for: updatedMistake.id)
        }
    }
}
