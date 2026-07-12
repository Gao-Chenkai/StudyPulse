//
//  AISimilarQuestionFlowView.swift
//  StudyPulse
//
//  Created for AI Similar Question feature.
//

import SwiftUI
import PencilKit
import SwiftStreamingMarkdown

struct SimilarQuestionResult: Codable {
    let question: String
    let correctSolution: String
}

struct AISimilarQuestionFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(RepositoryContainer.self) private var container
    @EnvironmentObject private var envManager: AppEnvironmentManager
    
    let originalMistake: MistakeNote
    
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    
    @State private var generatedQuestion: String = ""
    @State private var generatedSolution: String = ""
    
    @State private var showingSolution = false
    @State private var drawing = PKDrawing()
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("AI 正在构思变式题...".localized())
                            .foregroundColor(.secondary)
                    }
                } else if let errorMessage = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        Text(errorMessage)
                            .multilineTextAlignment(.center)
                            .padding()
                        Button("Retry".localized()) {
                            generate()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    quizContent
                }
            }
            .navigationTitle("AI 变式题".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close".localized()) { dismiss() }
                }
            }
        }
        .onAppear {
            if generatedQuestion.isEmpty {
                generate()
            }
        }
    }
    
    @ViewBuilder
    private var quizContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 题目区
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "q.circle.fill")
                            .foregroundColor(.blue)
                        Text("Question".localized())
                            .font(.headline)
                    }
                    MarkdownView(text: generatedQuestion, config: .previewConfig)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // 答题/草稿区
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "pencil.tip")
                            .foregroundColor(.orange)
                        Text("Draft / Answer".localized())
                            .font(.headline)
                    }
                    FlashcardHandwritingCanvasView(
                        drawing: $drawing,
                        hasContent: { !drawing.bounds.isEmpty },
                        onSubmit: { _ in showingSolution = true },
                        onClear: { drawing = PKDrawing() },
                        minHeight: 300,
                        labels: FlashcardHandwritingCanvasView.Labels(
                            header: "草稿区".localized(),
                            hint: "双指滑动/缩放".localized(),
                            clear: "Clear".localized(),
                            submit: "Check Solution".localized()
                        )
                    )
                }
                .padding(.horizontal)
                
                // 解析区
                if showingSolution {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Correct Solution".localized())
                                .font(.headline)
                        }
                        MarkdownView(text: generatedSolution, config: .previewConfig)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                        
                        // 底部操作
                        HStack(spacing: 16) {
                            Button {
                                updateOriginalMastery()
                                dismiss()
                            } label: {
                                Text("Done".localized())
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            
                            Button {
                                saveAsNewMistake()
                                updateOriginalMastery()
                                dismiss()
                            } label: {
                                Text("Save to Mistakes".localized())
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.top, 16)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
    
    private func generate() {
        isLoading = true
        errorMessage = nil
        
        Task {
            let prompt = SimilarQuestionLLM.makePrompt(
                subject: originalMistake.subject,
                title: originalMistake.title,
                originalQuestion: originalMistake.originalQuestion,
                correctSolution: originalMistake.correctSolution,
                errorReason: originalMistake.errorReason
            )
            
            do {
                let jsonString = try await LLMClient.shared.complete(
                    prompt: prompt,
                    config: envManager.llmConfig,
                    caller: "AISimilarQuestion"
                )
                
                if let data = jsonString.data(using: .utf8),
                   let result = try? JSONDecoder().decode(SimilarQuestionResult.self, from: data) {
                    self.generatedQuestion = result.question
                    self.generatedSolution = result.correctSolution
                } else {
                    // Fallback string matching if JSON parsing fails
                    self.generatedQuestion = jsonString
                    self.generatedSolution = ""
                }
                self.isLoading = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func saveAsNewMistake() {
        let newMistake = MistakeNote(
            title: "【AI变式】" + originalMistake.title,
            subject: originalMistake.subject,
            originalQuestion: generatedQuestion,
            source: "AI Generated",
            date: Date(),
            errorReason: "",
            wrongSolution: "",
            correctSolution: generatedSolution,
            reviewState: nil,
            phaseId: originalMistake.phaseId,
            tags: ["AI变式题"]
        )
        container.mistakeRepo.add(newMistake)
    }
    
    private func updateOriginalMastery() {
        // 轻微增加原题掌握度作为复习奖励
        var updated = originalMistake
        let newEntry = MasteryHistoryEntry(score: min(1.0, updated.masteryScore + 0.1), quality: 4)
        updated.masteryHistory.append(newEntry)
        updated.masteryScore = newEntry.score
        updated.exposureCount += 1
        container.mistakeRepo.update(updated)
    }
}
