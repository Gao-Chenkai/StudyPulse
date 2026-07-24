//
//  AIQuizView.swift
//  StudyPulse
//
//  AI 自测答题页:逐题作答 + 倒计时 + 自动阅卷 + 自动收录错题。
//  AI self-test answering page: per-question input + countdown timer
//  + auto-grading + auto-save incorrect questions to the mistake library.
//

import SwiftUI
import os
import SwiftStreamingMarkdown

/// AI 自测答题页(由 AIQuizSetupView 驱动到 quiz 阶段)。
/// AI self-test answering page (pushed by AIQuizSetupView in the quiz step).
struct AIQuizView: View {
    @Environment(RepositoryContainer.self) private var container

    /// 学科
    /// Subject.
    let subject: String
    /// 题目列表
    /// Question list.
    let questions: [QuizQuestion]
    /// 时限(分钟,nil = 不限时)
    /// Time limit in minutes (nil = untimed).
    let timeLimitMinutes: Int?
    /// 答完所有题后的回调
    /// Callback when the user finishes all questions.
    let onFinish: ([UUID: String], QuizGradingResponse) -> Void
    /// 退出按钮回调
    /// Exit button callback.
    let onExit: () -> Void

    // Answering state
    /// 当前题号(0-based)
    /// Current question index (0-based).
    @State private var currentIndex = 0
    /// 用户作答(题 id -> 答案)
    /// User answers (question id -> answer).
    @State private var userAnswers: [UUID: String] = [:]

    // Timer state
    /// 剩余秒数
    /// Remaining seconds.
    @State private var timeRemaining: Int = 0
    /// 计时器是否运行中
    /// Whether the countdown timer is running.
    @State private var timerActive = false
    // Submission states
    /// 是否正在提交阅卷
    /// Whether the grading request is in flight.
    @State private var isSubmitting = false
    /// 阅卷错误
    /// Grading error message.
    @State private var gradingError: String? = nil
    /// 阅卷结果(成功时)
    /// Grading response (on success).
    @State private var gradingResponse: QuizGradingResponse? = nil
    /// "确认提交" alert 触发
    /// "Confirm submit" alert flag.
    @State private var showingConfirmSubmit = false
    /// "确认退出" alert 触发
    /// "Confirm exit" alert flag.
    @State private var showingConfirmExit = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            if isSubmitting {
                submittingView
            } else {
                quizContentView
            }
        }
        .navigationTitle(subjectDisplayName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Exit".localized()) {
                    dismissKeyboard()
                    showingConfirmExit = true
                }
                .disabled(isSubmitting)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Submit".localized()) {
                    dismissKeyboard()
                    showingConfirmSubmit = true
                }
                .disabled(isSubmitting)
                .font(.headline)
            }
        }
        .onAppear {
            // 进入页面时启动倒计时(只在有限时模式下生效)
            // Start the countdown on appear (no-op in untimed mode).
            initializeTimer()
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                handleTimerTick()
            }
        }
        // 主动提交确认
        // Manual submit confirmation.
        .alert("提交自测".localized(), isPresented: $showingConfirmSubmit) {
            Button("Cancel".localized(), role: .cancel) { }
            Button("Submit Answer".localized(), role: .destructive) {
                submitQuiz()
            }
        } message: {
            Text("确定提交本次自测吗？未答题目的得分为0。提交后AI将对您的作答进行批改评分。".localized())
        }
        // 退出确认(避免误触丢失进度)
        // Exit confirmation (avoid losing progress by accident).
        .alert("退出自测".localized(), isPresented: $showingConfirmExit) {
            Button("Cancel".localized(), role: .cancel) { }
            Button("Exit".localized(), role: .destructive) {
                onExit()
            }
        } message: {
            Text("确定退出本次自测吗？您的答题进度将不会保存。".localized())
        }
    }

    // MARK: - Views / 子视图

    @ViewBuilder
    private var quizContentView: some View {
        VStack(spacing: 0) {
            // 计时器和进度条
            VStack(spacing: 8) {
                HStack {
                    // 题号进度
                    Text("Question \(currentIndex + 1) of \(questions.count)".localized())
                        .font(.subheadline.bold())
                        .foregroundColor(.secondary)

                    Spacer()

                    // 倒计时
                    if timeLimitMinutes != nil {
                        HStack(spacing: 4) {
                            Image(systemName: "timer")
                            Text(timeString(from: timeRemaining))
                                .monospacedDigit()
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(timeRemaining < 60 ? .red : .teal)
                    } else {
                        Text("不限时".localized())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)

                // 进度条
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 6)
                        
                        Capsule()
                            .fill(Color.blue)
                            .frame(width: geometry.size.width * CGFloat(currentIndex + 1) / CGFloat(questions.count), height: 6)
                    }
                }
                .frame(height: 6)
                .padding(.horizontal)
            }
            .background(Color(.secondarySystemGroupedBackground))

            // 题目区
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    let currentQuestion = questions[currentIndex]

                    // 题干
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: currentQuestion.type == "multiple_choice" ? "list.bullet.circle.fill" : "square.and.pencil")
                                .foregroundColor(.blue)
                            Text(currentQuestion.type == "multiple_choice" ? "选择题".localized() : "填空题".localized())
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.blue))
                        }

                        MarkdownView(text: currentQuestion.question.normalisingSingleDollarMath(), config: .previewConfig)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)

                    // 答题输入区
                    VStack(alignment: .leading, spacing: 12) {
                        Text("您的答案".localized())
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

                        if currentQuestion.type == "multiple_choice" {
                            multipleChoiceView(options: currentQuestion.options ?? [], questionId: currentQuestion.id)
                        } else {
                            fillInTheBlankView(questionId: currentQuestion.id)
                        }
                    }
                    .id(currentQuestion.id)
                }
                .padding(.vertical)
            }

            // 底部翻页栏
            HStack {
                Button {
                    dismissKeyboard()
                    if currentIndex > 0 { currentIndex -= 1 }
                } label: {
                    Label("Previous".localized(), systemImage: "chevron.left")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).stroke(Color.blue, lineWidth: 1))
                }
                .disabled(currentIndex == 0)

                Button {
                    dismissKeyboard()
                    if currentIndex < questions.count - 1 {
                        currentIndex += 1
                    } else {
                        showingConfirmSubmit = true
                    }
                } label: {
                    Text(currentIndex == questions.count - 1 ? "Submit".localized() : "Next Question".localized())
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(currentIndex == questions.count - 1 ? Color.green : Color.blue)
                        )
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
        }
    }

    @ViewBuilder
    private func multipleChoiceView(options: [String], questionId: UUID) -> some View {
        VStack(spacing: 12) {
            ForEach(options, id: \.self) { option in
                let optionLetter = String(option.prefix(1)) // "A", "B", "C", "D"
                let isSelected = userAnswers[questionId] == optionLetter

                Button {
                    userAnswers[questionId] = optionLetter
                } label: {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .stroke(isSelected ? Color.blue : Color.secondary.opacity(0.5), lineWidth: 2)
                                .frame(width: 24, height: 24)
                            
                            if isSelected {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 14, height: 14)
                            }
                        }

                        MarkdownView(text: option.normalisingSingleDollarMath(), config: .previewConfig)
                            .font(.body)
                            .foregroundColor(.primary)

                        Spacer()
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected ? Color.blue.opacity(0.1) : Color(.secondarySystemGroupedBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func fillInTheBlankView(questionId: UUID) -> some View {
        let answerBinding = Binding<String>(
            get: { userAnswers[questionId] ?? "" },
            set: { userAnswers[questionId] = $0 }
        )
        
        VStack(alignment: .leading, spacing: 8) {
            MarkdownEditorView(
                text: answerBinding,
                placeholder: "输入您的解答答案，支持 Markdown、化学式与 LaTeX 公式...".localized()
            )
            .frame(minHeight: 280)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var submittingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("AI 老师正在认真阅卷批改...".localized())
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("根据您的答案与解析，AI 将对每道题进行打分，并生成详细的评分建议。请稍候。".localized())
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            if let error = gradingError {
                Text(error)
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .padding()
                
                Button("重新提交评分".localized()) {
                    submitQuiz()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers / 辅助方法

    /// 学科展示名(本地化)
    /// Localized display name for the subject.
    private var subjectDisplayName: String {
        container.subjectRepo.displayName(for: subject)
    }

    /// 收键盘
    /// Dismiss the keyboard.
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    /// 进入页面时初始化倒计时(只在有限时模式下启动)
    /// Initialize the countdown on view appear (only when timed).
    private func initializeTimer() {
        if let minutes = timeLimitMinutes {
            timeRemaining = minutes * 60
            timerActive = true
        }
    }

    /// 计时器 tick:倒计时归零时触发自动交卷
    /// Timer tick: when the countdown reaches zero, auto-submit the quiz.
    private func handleTimerTick() {
        guard timerActive && timeLimitMinutes != nil else { return }
        if timeRemaining > 0 {
            timeRemaining -= 1
        } else {
            timerActive = false
            autoSubmitQuiz()
        }
    }

    /// 把秒数格式化为 "mm:ss"
    /// Format seconds as "mm:ss".
    private func timeString(from seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    /// 倒计时归零时自动交卷(先收键盘,再停计时,再提交)
    /// Auto-submit on timeout (dismiss keyboard, stop timer, submit).
    private func autoSubmitQuiz() {
        dismissKeyboard()
        // Stop timer
        // 关掉计时器
        timerActive = false
        // Submit immediately
        // 立刻提交
        submitQuiz()
    }

    private func submitQuiz() {
        isSubmitting = true
        gradingError = nil
        timerActive = false

        let prompt = QuizGradingLLM.makePrompt(
            subject: subject,
            questions: questions,
            userAnswers: userAnswers
        )

        Task {
            do {
                let jsonString = try await LLMClient.shared.complete(
                    prompt: prompt,
                    config: container.envManager.llmConfig,
                    caller: "QuizGrading"
                )

                if let response = parseGradingJSON(jsonString) {
                    // Step 1: Save incorrect ones to database
                    // Step 1: 把错题入库,方便后续 SRS 复习
                    await saveIncorrectQuestionsToLibrary(response: response)

                    await MainActor.run {
                        self.gradingResponse = response
                        self.isSubmitting = false
                        self.onFinish(self.userAnswers, response)
                    }
                } else {
                    await MainActor.run {
                        self.gradingError = "阅卷数据解析失败，请重试。".localized()
                        self.isSubmitting = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.gradingError = error.localizedDescription
                    self.isSubmitting = false
                }
            }
        }
    }

    /// 解析 LLM 阅卷 JSON,自动剥离 ```json / ``` 包裹
    /// Parse the LLM grading JSON, stripping ```json / ``` fences.
    private func parseGradingJSON(_ rawText: String) -> QuizGradingResponse? {
        var cleaned = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
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
            return try JSONDecoder().decode(QuizGradingResponse.self, from: data)
        } catch {
            Log.llm.error("Failed to parse Grading JSON: \(error.localizedDescription, privacy: .public). Raw was: \(cleaned, privacy: .public)")
            return nil
        }
    }

    /// 把阅卷判定为"不通过"的题目写入错题库
    /// Save the questions graded as "incorrect" into the mistake library.
    private func saveIncorrectQuestionsToLibrary(response: QuizGradingResponse) async {
        let activePhaseId = container.envManager.activePhaseId

        for index in questions.indices {
            guard let result = response.results.first(where: { $0.index == index }) else { continue }
            guard !result.isCorrect else { continue }
            let question = questions[index]
            let answer = userAnswers[question.id] ?? "(未作答)"

            let displayIndex = index + 1
            let title = "【自测错题】\(subjectDisplayName) Q\(displayIndex)：\(String(question.question.prefix(15)))"

            // Compose original question + options if MC
            // 拼装原题 + 选项(选择题时)
            var fullQuestionContent = question.question
            if question.type == "multiple_choice", let options = question.options {
                fullQuestionContent += "\n\n选项：\n" + options.joined(separator: "\n")
            }

            let mistake = MistakeNote(
                title: title,
                subject: subject,
                originalQuestion: fullQuestionContent,
                source: "AI 自测",
                date: Date(),
                errorReason: "自测得分率判定不通过（该题得分：\(result.score)分）。AI阅卷反馈：\(result.feedback)".localized(),
                wrongSolution: answer,
                correctSolution: "标准参考答案：\(question.correctAnswer)\n\n解析：\(question.solution)".localized(),
                reviewState: .initial(),
                phaseId: activePhaseId,
                tags: ["AI自测"]
            )

            await MainActor.run {
                container.addMistake(mistake)
            }
        }
    }
}
