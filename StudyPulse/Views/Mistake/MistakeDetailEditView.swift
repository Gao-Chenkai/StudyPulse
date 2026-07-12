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

    let usesInternalNavigationStack: Bool
    
    @StateObject private var viewModel: MistakeDetailEditViewModel

    init(container: RepositoryContainer, mistakeSet: MistakeNote, usesInternalNavigationStack: Bool = true) {
        self.usesInternalNavigationStack = usesInternalNavigationStack
        self._viewModel = StateObject(wrappedValue: MistakeDetailEditViewModel(container: container, mistakeSet: mistakeSet))
    }
    
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
        Form {
            basicInfoSection
            contentEditorSection
            imagesSection
        }
        .adaptiveForm()
        .navigationTitle("Edit Mistake".localized())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .sheet(isPresented: $viewModel.showingImagePicker) {
            ImagePickerWithCompletion(onDismiss: { image in
                if let image = image { viewModel.addImageToCurrentSection(image) }
            })
            .ignoresSafeArea()
        }
        .sheet(isPresented: $viewModel.showingPhotoCapture) {
            PhotoCaptureWithCompletion(onDismiss: { image in
                if let image = image { viewModel.addImageToCurrentSection(image) }
            })
            .ignoresSafeArea()
        }
        .sheet(isPresented: $viewModel.showingHandwritingSheet) {
            HandwritingSheet { pngData in
                if !pngData.isEmpty, let image = UIImage(data: pngData) {
                    viewModel.addImageToCurrentSection(image)
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .sheet(isPresented: $viewModel.showingAudioRecordingSheet) {
            VoiceMemoRecordingSheet { filename in
                viewModel.audioFileName = filename
            }
        }
        .alert("OCR Error".localized(), isPresented: $viewModel.showingOCRAlert) {
            Button("OK".localized()) { }
        } message: {
            Text(viewModel.ocrErrorMessage)
        }
        .sheet(isPresented: $viewModel.showingAIAnalysis) {
            MistakeAIAnalysisSheet(
                subject: viewModel.selectedSubject,
                title: viewModel.editedTitle,
                question: viewModel.editedOriginalQuestion,
                wrongSolution: viewModel.editedWrongSolution,
                correctSolution: viewModel.editedCorrectSolution,
                reason: viewModel.editedErrorReason,
                onInsert: { insertText in
                    if viewModel.editedCorrectSolution.isEmpty {
                        viewModel.editedCorrectSolution = insertText
                    } else {
                        viewModel.editedCorrectSolution += "\n\n" + insertText
                    }
                }
            )
            .environmentObject(envManager)
        }
        .containerBackground(.clear, for: .navigation)
        .debugModeContainer()
        .debugLayoutBoundsAuto()
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

// MARK: - Sections
private extension MistakeDetailEditView {
    
    var basicInfoSection: some View {
        Section(header: Text("Basic Info".localized())) {
            HStack {
                Text("Title".localized())
                TextField("Title".localized(), text: $viewModel.editedTitle)
                    .multilineTextAlignment(.trailing)
            }

            Picker("Subject".localized(), selection: $viewModel.selectedSubject) {
                Text("Select".localized()).tag("")
                ForEach(container.subjectRepo.subjects.filter { $0.enabled }, id: \.name) { subject in
                    Text(subject.name.localized()).tag(subject.name)
                }
            }

            HStack {
                Text("Source".localized())
                TextField("Source".localized(), text: $viewModel.editedSource)
                    .multilineTextAlignment(.trailing)
            }

            DifficultyPicker(difficulty: $viewModel.editedDifficulty)

            TagEditorView(
                tags: $viewModel.editedTags,
                suggestedTags: container.mistakeRepo.allTags()
            )

            DatePicker("Date".localized(), selection: $viewModel.editedDate, displayedComponents: .date)

            HStack {
                Text("Voice Memo".localized())
                Spacer()
                if let audioFileName = viewModel.audioFileName {
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
        Section(header: Text(viewModel.selectedSection.title)) {
            Picker("Section", selection: $viewModel.selectedSection) {
                ForEach(EditSection.allCases) { section in
                    Text(section.title).tag(section)
                }
            }
            .pickerStyle(.segmented)

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
                            if !pngData.isEmpty, let image = UIImage(data: pngData) {
                                viewModel.addImageToCurrentSection(image)
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
                                Image(uiImage: viewModel.currentSectionImagesBinding.wrappedValue[index])
                                    .resizable()
                                    .scaledToFill()
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
                            Capsule().fill(Color.teal.opacity(envManager.llmConfig.isConfigured ? 0.18 : 0.08))
                        )
                        .foregroundColor(envManager.llmConfig.isConfigured ? .teal : .secondary)
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
