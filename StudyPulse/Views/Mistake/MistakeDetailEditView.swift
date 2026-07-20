//
//  MistakeDetailEditView.swift
//  StudyPulse
//
//  错题详情/编辑页:展示 + 编辑错题的所有字段。
//  iPhone / iPad 共享(usesInternalNavigationStack 控制是否自己挂 NavigationStack)。
//  在 iPad 上的 split-view 用 no-stack 模式,在 iPhone sheet 上用 with-stack 模式。
//
//  Mistake detail / edit page: display and edit every field of a mistake.
//  Shared between iPhone and iPad (`usesInternalNavigationStack` decides
//  whether to host its own NavigationStack).
//  iPad split-view uses the no-stack mode; iPhone sheets use with-stack.
//

import SwiftUI

/// 错题详情/编辑页(view ↔ edit 切换),由 `MistakeView` 推入。
/// Mistake detail / edit page (view ↔ edit toggle), pushed by `MistakeView`.
struct MistakeDetailEditView: View {
    @Environment(RepositoryContainer.self) private var container
    @Environment(\.presentationMode) var presentationMode

    /// 是否自己挂 NavigationStack(iPad split-view 上为 false)
    /// Whether to host its own NavigationStack (false in iPad split-view).
    let usesInternalNavigationStack: Bool

    /// 内部 ViewModel,封装了"view / edit 切换 + draft 状态 + 保存"逻辑
    /// Internal view model encapsulating the view/edit toggle,
    /// draft state and save logic.
    @StateObject private var viewModel: MistakeDetailEditViewModel

    init(container: RepositoryContainer, mistakeSet: MistakeNote, usesInternalNavigationStack: Bool = true) {
        self.usesInternalNavigationStack = usesInternalNavigationStack
        self._viewModel = StateObject(wrappedValue: MistakeDetailEditViewModel(container: container, mistakeSet: mistakeSet))
    }

    /// 当前设备是否为 iPad
    /// Whether the current device is an iPad.
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    var body: some View {
        if usesInternalNavigationStack {
            NavigationStack {
                formContent
            }
        } else {
            formContent
        }
    }

    @ViewBuilder
    private var formContent: some View {
        // 三大分区:basic info / content editor / images
        // Three top-level sections: basic info / content editor / images.
        Form {
            basicInfoSection
            contentEditorSection
            imagesSection
        }
        // 平台/外观自适应
        // Platform / appearance adaptive form styling.
        .adaptiveForm()
        .navigationTitle("Edit Mistake".localized())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        // 系统照片选择器 → 追加到当前选中 section 的图片数组
        // System photo picker → appended to the current section's image array.
        .sheet(isPresented: $viewModel.showingImagePicker) {
            ImagePickerWithCompletion(onDismiss: { image in
                if let image = image { viewModel.addImageToCurrentSection(image) }
            })
            .ignoresSafeArea()
        }
        // 相机拍照 → 同上
        // Camera capture → same as above.
        .sheet(isPresented: $viewModel.showingPhotoCapture) {
            PhotoCaptureWithCompletion(onDismiss: { image in
                if let image = image { viewModel.addImageToCurrentSection(image) }
            })
            .ignoresSafeArea()
        }
        // PencilKit 手写 → 直接把 PNG Data 追加(P1-3:不再 UIImage 中转)
        // PencilKit hand-drawn → append the PNG Data directly (P1-3: no UIImage round-trip).
        .sheet(isPresented: $viewModel.showingHandwritingSheet) {
            HandwritingSheet { pngData in
                if !pngData.isEmpty {
                    viewModel.addImageDataToCurrentSection(pngData)
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
        // 语音备忘录 → 只关联文件名,播放/删除走 viewModel
        // Voice memo → only links the file name; playback/deletion goes through viewModel.
        .sheet(isPresented: $viewModel.showingAudioRecordingSheet) {
            VoiceMemoRecordingSheet { filename in
                viewModel.audioFileName = filename
            }
        }
        // OCR 失败 alert
        // OCR failure alert.
        .alert("OCR Error".localized(), isPresented: $viewModel.showingOCRAlert) {
            Button("OK".localized()) { }
        } message: {
            Text(viewModel.ocrErrorMessage)
        }
        // AI 解析 sheet:"Insert into Correct Solution" 把 AI 输出塞进正解字段
        // AI analysis sheet: "Insert into Correct Solution" injects the AI
        // output into the correct-solution field (append or replace).
        .sheet(isPresented: $viewModel.showingAIAnalysis) {
            MistakeAIAnalysisSheet(
                subject: viewModel.selectedSubject,
                title: viewModel.editedTitle,
                question: viewModel.editedOriginalQuestion,
                wrongSolution: viewModel.editedWrongSolution,
                correctSolution: viewModel.editedCorrectSolution,
                reason: viewModel.editedErrorReason,
                onInsert: { insertText in
                    let correctApproach = MistakeAnalysisLLM.parseCorrectApproach(from: insertText)
                    if !correctApproach.isEmpty {
                        if viewModel.editedCorrectSolution.isEmpty {
                            viewModel.editedCorrectSolution = correctApproach
                        } else {
                            viewModel.editedCorrectSolution += "\n\n" + correctApproach
                        }
                    }
                    
                    let errorReason = MistakeAnalysisLLM.parseErrorReason(from: insertText)
                    if !errorReason.isEmpty {
                        if viewModel.editedErrorReason.isEmpty {
                            viewModel.editedErrorReason = errorReason
                        } else {
                            viewModel.editedErrorReason += "\n\n" + errorReason
                        }
                    }
                    
                    let extractedTags = MistakeAnalysisLLM.parseTags(from: insertText)
                    for tag in extractedTags {
                        if !viewModel.editedTags.contains(tag) {
                            viewModel.editedTags.append(tag)
                        }
                    }
                }
            )
            .environment(container)
        }
        // 在 iOS 26+ 上让 navigation bar 背景透明,避免和 form 重叠
        // On iOS 26+ make the nav-bar background transparent to avoid
        // overlapping the form.
        .containerBackground(.clear, for: .navigation)
        .debugModeContainer()
        .debugLayoutBoundsAuto()
        // OCR 全屏 loading 蒙层
        // Full-screen OCR loading overlay.
        .overlay {
            if viewModel.isProcessingOCR {
                ProgressView("Recognizing text...".localized())
                    .padding(20)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 10)
            }
        }
    }
}

// MARK: - Sections / 分组
private extension MistakeDetailEditView {
    
    var basicInfoSection: some View {
        // 基础信息:标题 / 学科 / 来源 / 难度 / 标签 / 日期 / 语音 / SRS
        // Basic info: title / subject / source / difficulty / tags /
        // date / voice memo / SRS toggle.
        Section(header: Text("Basic Info".localized())) {
            HStack {
                Text("Title".localized())
                TextField("Title".localized(), text: $viewModel.editedTitle)
                    .multilineTextAlignment(.trailing)
            }

            Picker("Subject".localized(), selection: $viewModel.selectedSubject) {
                Text("Select".localized()).tag("")
                // 只显示启用中的学科
                // Only show enabled subjects.
                ForEach(container.subjectRepo.subjects.filter { $0.enabled }, id: \.name) { subject in
                    Text(subject.name.localized()).tag(subject.name)
                }
            }

            HStack {
                Text("Source".localized())
                TextField("Source".localized(), text: $viewModel.editedSource)
                    .multilineTextAlignment(.trailing)
            }

            // 1-5 星难度自评
            // 1-5 star self-rated difficulty.
            DifficultyPicker(difficulty: $viewModel.editedDifficulty)

            // 标签编辑器(带建议)
            // Tag editor (with suggestions).
            TagEditorView(
                tags: $viewModel.editedTags,
                suggestedTags: container.mistakeRepo.allTags()
            )

            DatePicker("Date".localized(), selection: $viewModel.editedDate, displayedComponents: .date)

            // 语音备忘录:有则显示删除按钮,没有则显示录音按钮
            // Voice memo: show delete if attached, otherwise show the record button.
            HStack {
                Text("Voice Memo".localized())
                Spacer()
                if viewModel.audioFileName != nil {
                    Button(role: .destructive) {
                        viewModel.deleteVoiceMemo()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                    Text("Recorded".localized())
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Button {
                        viewModel.showingAudioRecordingSheet = true
                    } label: {
                        Label("Record".localized(), systemImage: "mic.fill")
                    }
                    .buttonStyle(.borderless)
                }
            }

            // SRS 开关:开启后,这条错题会进闪卡流水线
            // SRS toggle: when on, this mistake joins the flashcard pipeline.
            Toggle(isOn: $viewModel.reviewEnabled) {
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
        // 内容编辑器:四段可切换,共用一个 MarkdownEditor
        // Content editor: four switchable sections, sharing one MarkdownEditor.
        Section(header: Text(viewModel.selectedSection.title)) {
            // 段间切换 segmented picker
            // Section switcher (segmented picker).
            Picker("Section", selection: $viewModel.selectedSection) {
                ForEach(EditSection.allCases) { section in
                    Text(section.title).tag(section)
                }
            }
            .pickerStyle(.segmented)

            // 切换段时给 editor 一个新 id 强制重建,避免跨段内容粘连
            // When switching sections, give the editor a new id to force
            // a rebuild and prevent content from leaking between sections.
            Group {
                switch viewModel.selectedSection {
                case .question:
                    MarkdownEditorView(
                        text: $viewModel.editedOriginalQuestion,
                        placeholder: "Supports Markdown, math $...$ and chemistry $\\ce{...}$"
                    )
                case .reason:
                    MarkdownEditorView(
                        text: $viewModel.editedErrorReason,
                        placeholder: "Supports Markdown, math $...$ and chemistry $\\ce{...}$"
                    )
                case .wrong:
                    MarkdownEditorView(
                        text: $viewModel.editedWrongSolution,
                        placeholder: "Supports Markdown, math $...$ and chemistry $\\ce{...}$"
                    )
                case .correct:
                    MarkdownEditorView(
                        text: $viewModel.editedCorrectSolution,
                        placeholder: "Supports Markdown, math $...$ and chemistry $\\ce{...}$"
                    )
                }
            }
            .id(viewModel.selectedSection)
            .frame(minHeight: 620)
        }
    }
    
    var imagesSection: some View {
        Section(header: Text("Images".localized())) {
            HStack {
                Button(action: { viewModel.showingImagePicker = true }) {
                    Label("Library".localized(), systemImage: "photo.on.rectangle.angled")
                }
                Spacer()
                Button(action: { viewModel.showingPhotoCapture = true }) {
                    Label("Camera".localized(), systemImage: "camera.fill")
                }
                Spacer()
                Button(action: { viewModel.triggerOCR() }) {
                    Label("OCR".localized(), systemImage: "text.viewfinder")
                }
                .disabled(viewModel.currentSectionImagesBinding.wrappedValue.isEmpty)
                Spacer()
                if isIPad {
                    NavigationLink {
                        HandwritingView { pngData in
                            if !pngData.isEmpty {
                                viewModel.addImageDataToCurrentSection(pngData)
                            }
                        }
                    } label: {
                        Label("Draw".localized(), systemImage: "pencil.tip")
                    }
                } else {
                    Button(action: { viewModel.showingHandwritingSheet = true }) {
                        Label("Draw".localized(), systemImage: "pencil.tip")
                    }
                }
            }
            .buttonStyle(.borderless)
            
            if viewModel.currentSectionImagesBinding.wrappedValue.isEmpty {
                Text("No images".localized())
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.currentSectionImagesBinding.wrappedValue.indices, id: \.self) { index in
                            ZStack(alignment: .topTrailing) {
                                CachedAsyncImage(data: viewModel.currentSectionImagesBinding.wrappedValue[index])
                                    .frame(width: 80, height: 80)
                                    .clipped()
                                    .cornerRadius(8)

                                Button(action: {
                                    viewModel.currentSectionImagesBinding.wrappedValue.remove(at: index)
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
                    Button {
                        viewModel.showingAIAnalysis = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                            Text("AI".localized())
                                .font(.caption.weight(.bold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(Color.teal.opacity(container.envManager.llmConfig.isConfigured ? 0.18 : 0.08))
                        )
                        .foregroundColor(container.envManager.llmConfig.isConfigured ? .teal : .secondary)
                    }
                    .accessibilityLabel("AI Analysis".localized())

                    Button("Save".localized()) {
                        viewModel.saveChanges()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
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

    return MistakeDetailEditView(container: mockContainer, mistakeSet: mockMistake)
        .environment(mockContainer)
}
