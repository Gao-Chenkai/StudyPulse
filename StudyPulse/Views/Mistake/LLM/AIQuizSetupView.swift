//
//  AIQuizSetupView.swift
//  StudyPulse
//
//  Created for AI Quiz feature.
//

import SwiftUI
import os

struct AIQuizSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(RepositoryContainer.self) private var container
    @EnvironmentObject private var envManager: AppEnvironmentManager

    @State private var selectedSubject: String = ""
    @State private var scope: QuizScope = .mistakes
    @State private var useAllMistakes = true
    @State private var selectedMistakeIds: Set<UUID> = []
    @State private var chapterTopic: String = ""
    @State private var questionCount = 5
    @State private var timeLimitMinutes = 15 // 15 mins default
    @State private var hasNoTimeLimit = false

    // Loading & navigation states
    @State private var isGenerating = false
    @State private var errorMessage: String? = nil
    @State private var generatedQuestions: [QuizQuestion] = []
    @State private var showingLLMAlert = false
    @State private var step: AIQuizStep = .setup

    enum AIQuizStep {
        case setup
        case quiz(questions: [QuizQuestion], subject: String, timeLimitMinutes: Int?)
        case result(subject: String, questions: [QuizQuestion], userAnswers: [UUID: String], gradingResponse: QuizGradingResponse)
    }
    
    enum QuizScope: String, CaseIterable, Identifiable {
        case mistakes = "mistakes"
        case chapter = "chapter"
        
        var id: String { rawValue }
        
        var title: String {
            switch self {
            case .mistakes: return "基于错题".localized()
            case .chapter: return "基于章节/知识点".localized()
            }
        }
    }

    private var activeSubjects: [Subject] {
        container.subjectRepo.subjects.filter { $0.enabled }
    }

    private var availableMistakes: [MistakeNote] {
        container.mistakeRepo.filteredMistakeSets.filter { $0.subject == selectedSubject }
    }

    var body: some View {
        Group {
            switch step {
            case .setup:
                setupNavigationStack
            case .quiz(let questions, let subject, let timeLimit):
                NavigationStack {
                    AIQuizView(
                        subject: subject,
                        questions: questions,
                        timeLimitMinutes: timeLimit,
                        onFinish: { answers, response in
                            self.step = .result(subject: subject, questions: questions, userAnswers: answers, gradingResponse: response)
                        },
                        onExit: {
                            dismiss()
                        }
                    )
                    .environment(container)
                    .environmentObject(envManager)
                }
            case .result(let subject, let questions, let userAnswers, let gradingResponse):
                NavigationStack {
                    AIQuizResultView(
                        subject: subject,
                        questions: questions,
                        userAnswers: userAnswers,
                        gradingResponse: gradingResponse,
                        onDismiss: {
                            dismiss()
                        }
                    )
                    .environment(container)
                    .environmentObject(envManager)
                }
            }
        }
    }

    @ViewBuilder
    private var setupNavigationStack: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isGenerating {
                    generatingView
                } else {
                    setupFormView
                }
            }
            .navigationTitle("AI 自测出题".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isGenerating {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close".localized()) {
                            dismiss()
                        }
                    }
                }
            }
            .onAppear {
                initializeDefaultSubject()
            }
            .alert("大模型未配置".localized(), isPresented: $showingLLMAlert) {
                Button("OK".localized()) { }
            } message: {
                Text("请先前往 [系统设置 > LLM设置] 配置您的 API Key 与模型。".localized())
            }
        }
    }

    // MARK: - Views

    @ViewBuilder
    private var setupFormView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 顶部说明
                VStack(alignment: .leading, spacing: 8) {
                    Text("AI 智能自测".localized())
                        .font(.title2.bold())
                    Text("基于您的历史错题或指定的知识章节，由 AI 命题专家为您定制 5-10 道精选练习题，涵盖选择题与填空题。限时作答，答后 AI 自动评分。".localized())
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 10)

                // 核心配置卡片
                VStack(spacing: 16) {
                    // 科目选择
                    VStack(alignment: .leading, spacing: 8) {
                        Label("选择学科".localized(), systemImage: "book.closed.fill")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Picker("学科".localized(), selection: $selectedSubject) {
                            if activeSubjects.isEmpty {
                                Text("无启用学科".localized()).tag("")
                            } else {
                                ForEach(activeSubjects) { subject in
                                    Text(subject.displayName).tag(subject.name)
                                }
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(10)
                    }

                    Divider()

                    // 自测范围选择
                    VStack(alignment: .leading, spacing: 8) {
                        Label("出题范围".localized(), systemImage: "scope")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Picker("范围".localized(), selection: $scope) {
                            ForEach(QuizScope.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // 范围相关详情
                    switch scope {
                    case .mistakes:
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("使用该科目所有错题".localized(), isOn: $useAllMistakes)
                                .font(.subheadline)
                            
                            if !useAllMistakes {
                                if availableMistakes.isEmpty {
                                    Text("本科目下暂无错题记录，建议选择“基于章节/知识点”出题。".localized())
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                        .padding(.vertical, 4)
                                } else {
                                    Text("选择特定错题 (已选 \(selectedMistakeIds.count) 项):".localized())
                                        .font(.subheadline.bold())
                                        .foregroundColor(.secondary)
                                    
                                    ScrollView(.vertical, showsIndicators: true) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            ForEach(availableMistakes) { mistake in
                                                Button {
                                                    if selectedMistakeIds.contains(mistake.id) {
                                                        selectedMistakeIds.remove(mistake.id)
                                                    } else {
                                                        selectedMistakeIds.insert(mistake.id)
                                                    }
                                                } label: {
                                                    HStack {
                                                        Image(systemName: selectedMistakeIds.contains(mistake.id) ? "checkmark.square.fill" : "square")
                                                            .foregroundColor(selectedMistakeIds.contains(mistake.id) ? .blue : .secondary)
                                                        VStack(alignment: .leading) {
                                                            Text(mistake.title)
                                                                .font(.subheadline)
                                                                .foregroundColor(.primary)
                                                                .lineLimit(1)
                                                            Text(mistake.originalQuestion)
                                                                .font(.caption)
                                                                .foregroundColor(.secondary)
                                                                .lineLimit(1)
                                                        }
                                                        Spacer()
                                                    }
                                                    .padding(.vertical, 6)
                                                    .padding(.horizontal, 8)
                                                }
                                                .buttonStyle(.plain)
                                                
                                                Divider()
                                            }
                                        }
                                    }
                                    .frame(maxHeight: 180)
                                    .background(Color(.secondarySystemBackground).opacity(0.5))
                                    .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.top, 4)
                        
                    case .chapter:
                        VStack(alignment: .leading, spacing: 8) {
                            Text("输入章节或知识点名称:".localized())
                                .font(.subheadline.bold())
                                .foregroundColor(.secondary)
                            
                            TextField("例如：高中数学人教A版必修一 第三章函数性质".localized(), text: $chapterTopic)
                                .textFieldStyle(.roundedBorder)
                                .font(.subheadline)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(16)
                .padding(.horizontal)

                // 题目数量与限时卡片
                VStack(spacing: 16) {
                    // 题量
                    HStack {
                        Label("出题数量".localized(), systemImage: "list.number")
                            .font(.headline)
                        Spacer()
                        Picker("题量", selection: $questionCount) {
                            ForEach(5...10, id: \.self) { num in
                                Text("\(num) 题").tag(num)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    Divider()
                    
                    // 限时
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("作答时限".localized(), systemImage: "timer")
                                .font(.headline)
                            Spacer()
                            Toggle("不限时".localized(), isOn: $hasNoTimeLimit)
                                .labelsHidden()
                        }
                        
                        if !hasNoTimeLimit {
                            Picker("限时", selection: $timeLimitMinutes) {
                                Text("5 分钟").tag(5)
                                Text("10 分钟").tag(10)
                                Text("15 分钟").tag(15)
                                Text("20 分钟").tag(20)
                                Text("30 分钟").tag(30)
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(16)
                .padding(.horizontal)

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // 开始按钮
                Button {
                    startGeneratingQuiz()
                } label: {
                    Text("开始 AI 出题".localized())
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isStartButtonDisabled ? Color.secondary : Color.blue)
                        )
                }
                .disabled(isStartButtonDisabled)
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
    }

    @ViewBuilder
    private var generatingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("AI 命题专家正在为您组卷...".localized())
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("这可能需要 15-30 秒，请稍后。基于错题时将融入错因定制题目；基于章节时将直接针对该章节出题。".localized())
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helper Functions

    private var isStartButtonDisabled: Bool {
        if selectedSubject.isEmpty { return true }
        if scope == .chapter && chapterTopic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        if scope == .mistakes && !useAllMistakes && selectedMistakeIds.isEmpty { return true }
        return false
    }

    private func initializeDefaultSubject() {
        if let first = activeSubjects.first {
            selectedSubject = first.name
        }
    }

    private func startGeneratingQuiz() {
        guard envManager.llmConfig.isConfigured else {
            showingLLMAlert = true
            return
        }

        isGenerating = true
        errorMessage = nil

        // 收集错题背景
        var refMistakes: [MistakeNote] = []
        if scope == .mistakes {
            if useAllMistakes {
                refMistakes = availableMistakes
            } else {
                refMistakes = availableMistakes.filter { selectedMistakeIds.contains($0.id) }
            }
        }

        let prompt = QuizGenerationLLM.makePrompt(
            subject: selectedSubject,
            scope: scope.rawValue,
            referenceMistakes: refMistakes,
            chapterTopic: chapterTopic,
            count: questionCount
        )

        Task {
            do {
                let jsonString = try await LLMClient.shared.complete(
                    prompt: prompt,
                    config: envManager.llmConfig,
                    caller: "QuizGeneration"
                )

                if let questions = parseQuizJSON(jsonString) {
                    await MainActor.run {
                        self.generatedQuestions = questions
                        self.isGenerating = false
                        self.step = .quiz(
                            questions: questions,
                            subject: selectedSubject,
                            timeLimitMinutes: hasNoTimeLimit ? nil : timeLimitMinutes
                        )
                    }
                } else {
                    await MainActor.run {
                        self.errorMessage = "解析题目数据失败，AI 返回格式不正确。请重试。".localized()
                        self.isGenerating = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isGenerating = false
                }
            }
        }
    }

    private func parseQuizJSON(_ rawText: String) -> [QuizQuestion]? {
        var cleaned = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        // 剥离 Markdown 代码块包裹
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = cleaned.data(using: .utf8) else { return nil }
        do {
            let decoder = JSONDecoder()
            return try decoder.decode([QuizQuestion].self, from: data)
        } catch {
            Log.llm.error("Failed to parse Quiz JSON: \(error.localizedDescription, privacy: .public). Raw string was: \(cleaned, privacy: .public)")
            return nil
        }
    }
}
