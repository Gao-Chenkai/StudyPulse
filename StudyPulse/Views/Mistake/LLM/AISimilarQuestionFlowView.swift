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

/// 答题方式:手写(PencilKit)或打字(Markdown)。
private enum AnswerMode: String, CaseIterable, Identifiable {
    case typing = "Typing"
    case handwriting = "Handwriting"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .typing: return "Markdown 作答".localized()
        case .handwriting: return "Handwriting".localized()
        }
    }

    var systemImage: String {
        switch self {
        case .typing: return "keyboard"
        case .handwriting: return "pencil.tip"
        }
    }
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

    // 模式选择
    @State private var answerMode: AnswerMode = .typing
    @State private var typedAnswer: String = ""
    @State private var showingSolution = false
    @State private var drawing = PKDrawing()

    // AI 判分状态
    @State private var isGrading = false
    @State private var gradingError: String? = nil
    @State private var gradingResult: SimilarQuestionGradingLLM.GradingResult? = nil
    @State private var gradingStreamedText: String = ""

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
                    MarkdownView(text: generatedQuestion.normalisingSingleDollarMath(), config: .previewConfig)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                }
                .padding(.horizontal)

                // 答题/草稿区
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: answerMode.systemImage)
                            .foregroundColor(.orange)
                        Text("Draft / Answer".localized())
                            .font(.headline)
                        Spacer()
                        Picker("Mode", selection: $answerMode) {
                            ForEach(AnswerMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .fixedSize()
                    }

                    switch answerMode {
                    case .handwriting:
                        handwritingCanvas
                    case .typing:
                        typingEditor
                    }
                }
                .padding(.horizontal)

                // 判分结果区(打字模式 + 已判分后展示)
                if answerMode == .typing, let result = gradingResult {
                    gradingResultSection(result)
                        .padding(.horizontal)
                } else if answerMode == .typing, isGrading {
                    gradingLoadingSection
                        .padding(.horizontal)
                } else if answerMode == .typing, let gradingError = gradingError {
                    gradingErrorSection(gradingError)
                        .padding(.horizontal)
                }

                // 解析区(查看正解 / 标准解法)
                if showingSolution {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Correct Solution".localized())
                                .font(.headline)
                        }
                        MarkdownView(text: generatedSolution.normalisingSingleDollarMath(), config: .previewConfig)
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

    // MARK: - Answer Input

    @ViewBuilder
    private var handwritingCanvas: some View {
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

    @ViewBuilder
    private var typingEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            MarkdownEditorView(
                text: $typedAnswer,
                placeholder: "Supports Markdown, math $...$ and chemistry $\\ce{...}$"
            )
            .frame(minHeight: 360)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)

            HStack(spacing: 12) {
                Button {
                    typedAnswer = ""
                    gradingResult = nil
                    gradingError = nil
                    gradingStreamedText = ""
                } label: {
                    Label("Clear".localized(), systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(typedAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && gradingResult == nil)

                Button {
                    if envManager.llmConfig.isConfigured {
                        startGrading()
                    } else {
                        // 未配置 LLM → 退化为"查看正解"
                        showingSolution = true
                    }
                } label: {
                    if envManager.llmConfig.isConfigured {
                        Label("AI 判分".localized(), systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Check Solution".localized(), systemImage: "checkmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(envManager.llmConfig.isConfigured ? .teal : .blue)
                .disabled(typedAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGrading)
            }
        }
    }

    // MARK: - Grading UI

    @ViewBuilder
    private func gradingResultSection(_ result: SimilarQuestionGradingLLM.GradingResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: result.isCorrect ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(result.isCorrect ? .green : .orange)
                Text("AI 判分".localized())
                    .font(.headline)
                Spacer()
                Text("\(result.score) / 100")
                    .font(.title3.weight(.bold))
                    .foregroundColor(result.isCorrect ? .green : .orange)
            }

            // 详细 Markdown 反馈
            if !result.detail.isEmpty {
                MarkdownView(text: result.detail.normalisingSingleDollarMath(), config: .previewConfig)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
            }

            HStack(spacing: 12) {
                Button {
                    gradingResult = nil
                    gradingStreamedText = ""
                } label: {
                    Label("Retry".localized(), systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    showingSolution = true
                } label: {
                    Label("View Solution".localized(), systemImage: "lightbulb")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    @ViewBuilder
    private var gradingLoadingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.teal)
                Text("AI 判分中...".localized())
                    .font(.headline)
                Spacer()
                ProgressView()
            }
            if !gradingStreamedText.isEmpty {
                MarkdownView(text: gradingStreamedText.normalisingSingleDollarMath(), config: .previewConfig)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
            }
        }
    }

    @ViewBuilder
    private func gradingErrorSection(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("判分失败".localized())
                    .font(.headline)
            }
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
            HStack {
                Button {
                    gradingError = nil
                    startGrading()
                } label: {
                    Label("Retry".localized(), systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    showingSolution = true
                } label: {
                    Label("View Solution".localized(), systemImage: "lightbulb")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Generate

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

    // MARK: - Grading

    private func startGrading() {
        gradingResult = nil
        gradingError = nil
        gradingStreamedText = ""
        isGrading = true
        let prompt = SimilarQuestionGradingLLM.makePrompt(
            subject: originalMistake.subject,
            question: generatedQuestion,
            correctSolution: generatedSolution,
            userAnswer: typedAnswer
        )
        let config = envManager.llmConfig
        Task { @MainActor in
            do {
                let streamed = try await LLMClient.shared.stream(
                    prompt: prompt,
                    config: config,
                    caller: "AISimilarGrading"
                ) { snapshot in
                    gradingStreamedText = snapshot
                }
                isGrading = false
                if let parsed = SimilarQuestionGradingLLM.parse(streamed) {
                    gradingResult = parsed
                } else {
                    // 解析失败:把流式原样作为 detail 给出,让用户至少能看到反馈
                    gradingError = "无法解析评分,请重试".localized()
                }
            } catch is CancellationError {
                isGrading = false
            } catch {
                isGrading = false
                gradingError = (error as? LLMError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    // MARK: - Persist

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
