//
//  MistakeDetailEditView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import SwiftUI

struct MistakeDetailEditView: View {
    @Environment(RepositoryContainer.self) private var container
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var envManager: AppEnvironmentManager
    let mistakeSet: MistakeNote

    /// 是否在内部包一层 NavigationStack。
    /// iPhone sheet 场景需要自己提供 stack(.navigationTitle / .toolbar 才能生效),
    /// iPad 走 NavigationLink 推到父级 stack 时必须传 false,否则会出现双重 stack。
    /// Whether to wrap the body in its own NavigationStack. Mirrors the
    /// `NewMistakeSetView` flag so the edit view behaves identically in both
    /// sheet (iPhone) and push (iPad) contexts.
    let usesInternalNavigationStack: Bool

    /// Default sheet initializer: provides its own NavigationStack.
    init(mistakeSet: MistakeNote, usesInternalNavigationStack: Bool = true) {
        self.mistakeSet = mistakeSet
        self.usesInternalNavigationStack = usesInternalNavigationStack
    }
    
    @State private var editedTitle = ""
    @State private var selectedSubject = ""
    @State private var editedOriginalQuestion = ""
    @State private var editedSource = ""
    @State private var editedErrorReason = ""
    @State private var editedWrongSolution = ""
    @State private var editedCorrectSolution = ""
    @State private var editedDate = Date()
    /// 难度自评 0-5
    @State private var editedDifficulty: Int = 0
    /// 自由标签
    @State private var editedTags: [String] = []
    
    @State private var questionImages: [UIImage] = []
    @State private var reasonImages: [UIImage] = []
    @State private var wrongSolutionImages: [UIImage] = []
    @State private var correctSolutionImages: [UIImage] = []
    
    @State private var showingImagePicker = false
    @State private var showingPhotoCapture = false
    @State private var showingHandwritingSheet = false

    @State private var selectedSection: EditSection = .question

    /// iPad 检测:用 userInterfaceIdiom 匹配用户说的「iPad」
    /// iPad detection via userInterfaceIdiom (matches the user's "iPad" wording).
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    @State private var isProcessingOCR = false
    @State private var showingOCRAlert = false
    @State private var ocrErrorMessage = ""

    /// 是否加入 SRS 复习队列（opt-in）
    @State private var reviewEnabled: Bool = false

    /// AI 解析 sheet
    @State private var showingAIAnalysis = false
    
    var body: some View {
        // 根据调用场景决定是否包自己的 NavigationStack:
        // - sheet 场景包一层,让 .navigationTitle / .toolbar 生效;
        // - iPad NavigationLink 推到父级 stack 时不再包,避免双重 stack。
        // Conditionally wrap in NavigationStack (mirrors NewMistakeSetView).
        if usesInternalNavigationStack {
            NavigationStack {
                formContent
            }
        } else {
            formContent
        }
    }

    /// Form + toolbar + sheets + alerts,shared by sheet and push contexts.
    /// All `.navigationTitle` / `.toolbar` / `.containerBackground` modifiers
    /// below operate on the nearest enclosing `NavigationStack`, which is
    /// either this view's own (sheet) or the parent's (NavigationLink).
    @ViewBuilder
    private var formContent: some View {
        Form {
            basicInfoSection
            contentEditorSection
            imagesSection
        }
        .adaptiveForm()
        .navigationTitle("Edit Mistake".localized())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .onAppear { initializeData() }
        .sheet(isPresented: $showingImagePicker) {
            ImagePickerWithCompletion(onDismiss: { image in
                if let image = image { addImageToCurrentSection(image) }
            })
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showingPhotoCapture) {
            PhotoCaptureWithCompletion(onDismiss: { image in
                if let image = image { addImageToCurrentSection(image) }
            })
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showingHandwritingSheet) {
            HandwritingSheet { pngData in
                if !pngData.isEmpty, let image = UIImage(data: pngData) {
                    addImageToCurrentSection(image)
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .alert("OCR Error".localized(), isPresented: $showingOCRAlert) {
            Button("OK".localized()) { }
        } message: {
            Text(ocrErrorMessage)
        }
        .sheet(isPresented: $showingAIAnalysis) {
            MistakeAIAnalysisSheet(
                subject: selectedSubject,
                title: editedTitle,
                question: editedOriginalQuestion,
                wrongSolution: editedWrongSolution,
                correctSolution: editedCorrectSolution,
                reason: editedErrorReason,
                onInsert: { insertText in
                    // 把 AI 解析结果拼接到 "正解" 段
                    if editedCorrectSolution.isEmpty {
                        editedCorrectSolution = insertText
                    } else {
                        editedCorrectSolution += "\n\n" + insertText
                    }
                }
            )
            .environmentObject(envManager)
        }
        .containerBackground(.clear, for: .navigation)
        .debugModeContainer()
        .debugLayoutBoundsAuto()
        .overlay {
            if isProcessingOCR {
                ProgressView("Recognizing text...".localized())
                    .padding(20)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 10)
            }
        }
    }
}

// MARK: - Sections
private extension MistakeDetailEditView {
    
    var basicInfoSection: some View {
        Section(header: Text("Basic Info".localized())) {
            HStack {
                Text("Title".localized())
                TextField("Title".localized(), text: $editedTitle)
                    .multilineTextAlignment(.trailing)
            }

            Picker("Subject".localized(), selection: $selectedSubject) {
                Text("Select".localized()).tag("")
                ForEach(container.subjectRepo.subjects.filter { $0.enabled }, id: \.name) { subject in
                    Text(subject.name.localized()).tag(subject.name)
                }
            }

            HStack {
                Text("Source".localized())
                TextField("Source".localized(), text: $editedSource)
                    .multilineTextAlignment(.trailing)
            }

            // 难度自评
            DifficultyPicker(difficulty: $editedDifficulty)

            // 自由标签
            TagEditorView(
                tags: $editedTags,
                suggestedTags: container.mistakeRepo.allTags()
            )

            DatePicker("Date".localized(), selection: $editedDate, displayedComponents: .date)

            // SRS opt-in 开关
            Toggle(isOn: $reviewEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Spaced Repetition".localized())
                    Text("Auto-schedule reviews using SM-2 algorithm".localized())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    var contentEditorSection: some View {
        Section(header: Text(selectedSection.title)) {
            Picker("Section", selection: $selectedSection) {
                ForEach(EditSection.allCases) { section in
                    Text(section.title).tag(section)
                }
            }
            .pickerStyle(.segmented)

            // 用 switch + 直接 binding，绑定到对应 State；
            // .id(selectedSection) 强制 SwiftUI 在切换栏目时重建 MarkdownTextEditor
            // 内部持有的 UITextView，避免计算属性 binding 在 UIViewRepresentable
            // 包裹层中无法正确切换 state 的问题。
            Group {
                switch selectedSection {
                case .question:
                    MarkdownEditorView(
                        text: $editedOriginalQuestion,
                        placeholder: "Supports Markdown, math $...$ and chemistry $\\ce{...}$"
                    )
                case .reason:
                    MarkdownEditorView(
                        text: $editedErrorReason,
                        placeholder: "Supports Markdown, math $...$ and chemistry $\\ce{...}$"
                    )
                case .wrong:
                    MarkdownEditorView(
                        text: $editedWrongSolution,
                        placeholder: "Supports Markdown, math $...$ and chemistry $\\ce{...}$"
                    )
                case .correct:
                    MarkdownEditorView(
                        text: $editedCorrectSolution,
                        placeholder: "Supports Markdown, math $...$ and chemistry $\\ce{...}$"
                    )
                }
            }
            .id(selectedSection)
            .frame(minHeight: 620)
        }
    }
    
    var imagesSection: some View {
        Section(header: Text("Images".localized())) {
            HStack {
                Button(action: { showingImagePicker = true }) {
                    Label("Library".localized(), systemImage: "photo.on.rectangle.angled")
                }
                Spacer()
                Button(action: { showingPhotoCapture = true }) {
                    Label("Camera".localized(), systemImage: "camera.fill")
                }
                Spacer()
                Button(action: { triggerOCR() }) {
                    Label("OCR".localized(), systemImage: "text.viewfinder")
                }
                .disabled(currentSectionImages.wrappedValue.isEmpty)
                Spacer()
                // iPad 用 NavigationLink 推到 HandwritingView(自带「Back」确认);
                // iPhone 仍走 sheet 弹出 HandwritingSheet(自带「Cancel」+ 滑动手势拦截)。
                // iPad uses NavigationLink → HandwritingView (Back button + confirm);
                // iPhone still uses sheet → HandwritingSheet (Cancel + swipe guard).
                if isIPad {
                    NavigationLink {
                        HandwritingView { pngData in
                            if !pngData.isEmpty, let image = UIImage(data: pngData) {
                                addImageToCurrentSection(image)
                            }
                        }
                    } label: {
                        Label("Draw".localized(), systemImage: "pencil.tip")
                    }
                } else {
                    Button(action: { showingHandwritingSheet = true }) {
                        Label("Draw".localized(), systemImage: "pencil.tip")
                    }
                }
            }
            .buttonStyle(.borderless)
            
            if currentSectionImages.wrappedValue.isEmpty {
                Text("No images".localized())
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(currentSectionImages.wrappedValue.indices, id: \.self) { index in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: currentSectionImages.wrappedValue[index])
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipped()
                                    .cornerRadius(8)
                                
                                Button(action: {
                                    currentSectionImages.wrappedValue.remove(at: index)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                        .background(Circle().fill(Color.white))
                                }
                                .padding(2)
                            }
                        }
                    }
                }
            }
        }
    }
    
    var toolbar: some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel".localized()) { presentationMode.wrappedValue.dismiss() }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    // AI 解析按钮 — LLM 未配置时按钮仍可点(打开 sheet 后有"去设置"入口)
                    // 用 Label 文本让按钮更显眼,不再只是个小图标
                    Button {
                        showingAIAnalysis = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                            Text("AI".localized())
                                .font(.caption.weight(.bold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(Color.teal.opacity(envManager.llmConfig.isConfigured ? 0.18 : 0.08))
                        )
                        .foregroundColor(envManager.llmConfig.isConfigured ? .teal : .secondary)
                    }
                    .accessibilityLabel("AI Analysis".localized())

                    Button("Save".localized()) {
                        saveChanges()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Helpers
private extension MistakeDetailEditView {
    
    var currentBinding: Binding<String> {
        switch selectedSection {
        case .question: return $editedOriginalQuestion
        case .reason: return $editedErrorReason
        case .wrong: return $editedWrongSolution
        case .correct: return $editedCorrectSolution
        }
    }
    
    var currentSectionImages: Binding<[UIImage]> {
        switch selectedSection {
        case .question: return $questionImages
        case .reason: return $reasonImages
        case .wrong: return $wrongSolutionImages
        case .correct: return $correctSolutionImages
        }
    }
    
    func addImageToCurrentSection(_ image: UIImage) {
        switch selectedSection {
        case .question: questionImages.append(image)
        case .reason: reasonImages.append(image)
        case .wrong: wrongSolutionImages.append(image)
        case .correct: correctSolutionImages.append(image)
        }
    }
    
    func triggerOCR() {
        guard let lastImage = currentSectionImages.wrappedValue.last else { return }
        isProcessingOCR = true
        
        Task {
            do {
                let recognizedText = try await OCRManager.recognizeText(in: lastImage)
                if !recognizedText.isEmpty {
                    if !currentBinding.wrappedValue.isEmpty {
                        currentBinding.wrappedValue += "\n\n" + recognizedText
                    } else {
                        currentBinding.wrappedValue = recognizedText
                    }
                }
            } catch {
                ocrErrorMessage = error.localizedDescription
                showingOCRAlert = true
            }
            isProcessingOCR = false
        }
    }
    
    func initializeData() {
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

        questionImages = mistakeSet.questionImages.compactMap { UIImage(data: $0) }
        reasonImages = mistakeSet.reasonImages.compactMap { UIImage(data: $0) }
        wrongSolutionImages = mistakeSet.wrongSolutionImages.compactMap { UIImage(data: $0) }
        correctSolutionImages = mistakeSet.correctSolutionImages.compactMap { UIImage(data: $0) }

        reviewEnabled = mistakeSet.isInReviewQueue
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

        updatedMistake.questionImages = questionImages.compactMap { $0.jpegData(compressionQuality: 0.8) }
        updatedMistake.reasonImages = reasonImages.compactMap { $0.jpegData(compressionQuality: 0.8) }
        updatedMistake.wrongSolutionImages = wrongSolutionImages.compactMap { $0.jpegData(compressionQuality: 0.8) }
        updatedMistake.correctSolutionImages = correctSolutionImages.compactMap { $0.jpegData(compressionQuality: 0.8) }

        // 同步 SRS 状态
        if reviewEnabled && !updatedMistake.isInReviewQueue {
            // 开启 opt-in：创建初始状态
            updatedMistake.reviewState = .initial()
        } else if !reviewEnabled && updatedMistake.isInReviewQueue {
            // 关闭 opt-in：保留复习历史但退出队列（设为 nextReviewDate = far future）
            // 注：保留 state 字段便于用户重新开启时复用
            if var state = updatedMistake.reviewState {
                state.nextReviewDate = Date.distantFuture
                updatedMistake.reviewState = state
            }
        }

        container.mistakeRepo.update(updatedMistake)

        // 重调度该错题的通知
        if reviewEnabled {
            // 重新调度所有（简化：调 rescheduleAll）
            SRSReviewNotifications.shared.rescheduleAll(mistakes: container.mistakeRepo.mistakeSets)
        } else {
            SRSReviewNotifications.shared.cancel(for: updatedMistake.id)
        }
    }
}

#Preview {
    let mockContainer = RepositoryContainer()

    let mockMistake = MistakeNote(
        title: "Calculus Example",
        subject: "Mathematics",
        originalQuestion: "Find the derivative of f(x) = x^2 at x=2.",
        source: "2023 Midterm Exam",
        date: Date(),
        errorReason: "Confused the power rule formula.",
        wrongSolution: "f'(x) = x^3 / 3",
        correctSolution: "f'(x) = 2x, so f'(2) = 4",
        questionImages: [],
        reasonImages: [],
        wrongSolutionImages: [],
        correctSolutionImages: []
    )

    return MistakeDetailEditView(mistakeSet: mockMistake)
        .environment(mockContainer)
}
