//
//  MistakeDetailEditView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import SwiftUI

struct MistakeDetailEditView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.presentationMode) var presentationMode
    let mistakeSet: MistakeNote
    
    @State private var editedTitle = ""
    @State private var selectedSubject = ""
    @State private var editedOriginalQuestion = ""
    @State private var editedSource = ""
    @State private var editedErrorReason = ""
    @State private var editedWrongSolution = ""
    @State private var editedCorrectSolution = ""
    @State private var editedDate = Date()
    
    @State private var questionImages: [UIImage] = []
    @State private var reasonImages: [UIImage] = []
    @State private var wrongSolutionImages: [UIImage] = []
    @State private var correctSolutionImages: [UIImage] = []
    
    @State private var showingImagePicker = false
    @State private var showingPhotoCapture = false

    @State private var selectedSection: EditSection = .question
    @State private var isProcessingOCR = false
    @State private var showingOCRAlert = false
    @State private var ocrErrorMessage = ""

    /// 是否加入 SRS 复习队列（opt-in）
    @State private var reviewEnabled: Bool = false
    
    var body: some View {
        NavigationStack {
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
            .alert("OCR Error".localized(), isPresented: $showingOCRAlert) {
                Button("OK".localized()) { }
            } message: {
                Text(ocrErrorMessage)
            }
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
                ForEach(dataManager.subjects.filter { $0.enabled }, id: \.name) { subject in
                    Text(subject.name.localized()).tag(subject.name)
                }
            }

            HStack {
                Text("Source".localized())
                TextField("Source".localized(), text: $editedSource)
                    .multilineTextAlignment(.trailing)
            }

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
                Button("Save".localized()) {
                    saveChanges()
                    presentationMode.wrappedValue.dismiss()
                }
                .fontWeight(.semibold)
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

        dataManager.updateMistake(updatedMistake)

        // 重调度该错题的通知
        if reviewEnabled {
            // 重新调度所有（简化：调 rescheduleAll）
            SRSReviewNotifications.shared.rescheduleAll(mistakes: dataManager.mistakeSets)
        } else {
            SRSReviewNotifications.shared.cancel(for: updatedMistake.id)
        }
    }
}

#Preview {
    let mockDataManager = DataManager()
    
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
        .environmentObject(mockDataManager)
}
