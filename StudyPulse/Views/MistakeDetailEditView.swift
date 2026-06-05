//
//  MistakeDetailEditView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import SwiftUI
import MarkdownUI

struct MistakeDetailEditView: View {
    @ObservedObject var dataManager: DataManager
    @Environment(\.presentationMode) var presentationMode
    let mistakeSet: MistakeNote
    
    // 编辑状态变量
    @State private var editedTitle = ""
    @State private var selectedSubject = ""
    @State private var editedOriginalQuestion = ""
    @State private var editedSource = ""
    @State private var editedErrorReason = ""
    @State private var editedWrongSolution = ""
    @State private var editedCorrectSolution = ""
    @State private var editedDate = Date()
    
    // Image states
    @State private var questionImages: [UIImage] = []
    @State private var reasonImages: [UIImage] = []
    @State private var wrongSolutionImages: [UIImage] = []
    @State private var correctSolutionImages: [UIImage] = []
    
    // Image picker states
    @State private var showingImagePicker = false
    @State private var showingPhotoCapture = false
    
    // 控制当前显示哪个编辑区域的状态
    @State private var selectedSection: EditSection = .question
    
    @State private var showMarkdownPreview = false
    @State private var isProcessingOCR = false
    @State private var showingOCRAlert = false
    @State private var ocrErrorMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    
                    // --- 第一部分：Basic Info ---
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Basic Info")
                            .font(.callout)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 16)
                            .padding(.bottom, 8)
                        
                        VStack(spacing: 0) {
                            let leftPadding: CGFloat = 16
                            let labelWidth: CGFloat = 60
                            let iconWidth: CGFloat = 30
                            let iconLabelSpacing: CGFloat = 12
                            
                            // Title
                            buildInfoRow(icon: "rectangle.and.pencil.and.ellipsis", color: .yellow, label: "Title", text: $editedTitle, leftPadding: leftPadding, labelWidth: labelWidth, iconWidth: iconWidth, iconLabelSpacing: iconLabelSpacing)
                            
                            Divider().padding(.leading, leftPadding + iconWidth + iconLabelSpacing + labelWidth)
                            
                            // Subject
                            HStack(spacing: iconLabelSpacing) {
                                Image(systemName: "book.fill")
                                    .foregroundColor(.purple)
                                    .frame(width: iconWidth, alignment: .center)
                                Text("Subject")
                                    .frame(width: labelWidth, alignment: .leading)
                                Picker("", selection: $selectedSubject) {
                                    Text("Select").tag("")
                                    ForEach(dataManager.subjects.filter { $0.enabled }, id: \.name) { subject in
                                        Text(subject.name.localized()).tag(subject.name)
                                    }
                                }
                                .labelsHidden()
                            }
                            .padding(leftPadding)
                            
                            Divider().padding(.leading, leftPadding + iconWidth + iconLabelSpacing + labelWidth)
                            
                            // Source
                            buildInfoRow(icon: "list.bullet.clipboard", color: .green, label: "Source", text: $editedSource, leftPadding: leftPadding, labelWidth: labelWidth, iconWidth: iconWidth, iconLabelSpacing: iconLabelSpacing)
                            
                            Divider().padding(.leading, leftPadding + iconWidth + iconLabelSpacing + labelWidth)
                            
                            // Date
                            buildDateRow(leftPadding: leftPadding, labelWidth: labelWidth, iconWidth: iconWidth, iconLabelSpacing: iconLabelSpacing)
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    }
                    .padding(.horizontal)

                    // --- 第二部分：顶部横条切换按钮 ---
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            ForEach(EditSection.allCases) { section in
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedSection = section
                                    }
                                } label: {
                                    VStack {
                                        Image(systemName: section.icon)
                                            .font(.system(size: 18, weight: .medium))
                                            .foregroundColor(selectedSection == section ? section.color : .gray)
                                            .padding(.bottom, 4)
                                        
                                        Text(section.title)
                                            .font(.caption)
                                            .fontWeight(selectedSection == section ? .semibold : .regular)
                                            .foregroundColor(selectedSection == section ? section.color : .gray)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .contentShape(Rectangle())
                                }
                                
                                if section != EditSection.allCases.last {
                                    Divider()
                                        .frame(height: 30)
                                        .padding(.horizontal, 4)
                                }
                            }
                        }
                        .padding(.vertical, 12)
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    }
                    .padding(.horizontal)

                    // --- 第三部分：下方输入区域 (Split: Input + Preview) ---
                    VStack(alignment: .leading, spacing: 12) {
                        // Toolbar: OCR + Preview toggle
                        HStack {
                            Button(action: { showMarkdownPreview.toggle() }) {
                                Label(showMarkdownPreview ? "Hide Preview" : "Show Preview", systemImage: showMarkdownPreview ? "eye.slash" : "eye")
                                    .font(.callout)
                                    .fontWeight(.medium)
                                    .foregroundColor(selectedSection.color)
                            }
                            Spacer()
                            Button(action: { triggerOCR() }) {
                                Label("OCR", systemImage: "text.viewfinder")
                                    .font(.callout)
                                    .fontWeight(.medium)
                                    .foregroundColor(.orange)
                            }
                            .disabled(currentSectionImages.wrappedValue.isEmpty)
                        }
                        .padding(.horizontal)
                        
                        // Text Input (Top)
                        TextEditor(text: currentBinding)
                            .frame(minHeight: 180)
                            .font(.body)
                            .padding(8)
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(selectedSection.color.opacity(0.5), lineWidth: 2)
                            )
                            .padding(.horizontal)
                        
                        // Live Markdown Preview (Bottom)
                        if showMarkdownPreview {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Preview")
                                    .font(.callout)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                
                                MarkdownPreviewView(text: currentBinding.wrappedValue)
                                    .frame(minHeight: 120)
                                    .padding(8)
                                    .background(Color(.systemGroupedBackground))
                                    .cornerRadius(8)
                            }
                            .padding(.horizontal)
                        }
                        
                        // Image section
                        imageSectionForCurrentSection
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 40)
                }
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Edit Mistake")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                initializeData()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePickerWithCompletion(onDismiss: { image in
                    if let image = image {
                        addImageToCurrentSection(image)
                    }
                })
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showingPhotoCapture) {
                PhotoCaptureWithCompletion(onDismiss: { image in
                    if let image = image {
                        addImageToCurrentSection(image)
                    }
                })
                .ignoresSafeArea()
            }
            .alert("OCR Error", isPresented: $showingOCRAlert) {
                Button("OK") { }
            } message: {
                Text(ocrErrorMessage)
            }
            .overlay {
                if isProcessingOCR {
                    ProgressView("Recognizing text...")
                        .padding(20)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 10)
                }
            }
        }
    }
    
    // MARK: - Image Section Builder
    @ViewBuilder
    private var imageSectionForCurrentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Images")
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
                HStack(spacing: 12) {
                    Button(action: {
                        showingImagePicker = true
                    }) {
                        Label("Library", systemImage: "photo.on.rectangle.angled")
                            .foregroundColor(selectedSection.color)
                    }
                    Button(action: {
                        showingPhotoCapture = true
                    }) {
                        Label("Camera", systemImage: "camera.fill")
                            .foregroundColor(selectedSection.color)
                    }
                }
            }
            
            // Display images for current section
            if currentSectionImages.isEmpty {
                Text("No images added")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(currentSectionImages.indices, id: \.self) { index in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: currentSectionImages.wrappedValue[index])
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipped()
                                    .cornerRadius(8)
                                
                                Button(action: {
                                    currentSectionImages.wrappedValue.remove(at: index)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                        .background(Circle().fill(Color.white))
                                }
                                .padding(4)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Image Helpers
    private var currentSectionImages: Binding<[UIImage]> {
        switch selectedSection {
        case .question: return $questionImages
        case .reason: return $reasonImages
        case .wrong: return $wrongSolutionImages
        case .correct: return $correctSolutionImages
        }
    }
    
    private func addImageToCurrentSection(_ image: UIImage) {
        switch selectedSection {
        case .question: questionImages.append(image)
        case .reason: reasonImages.append(image)
        case .wrong: wrongSolutionImages.append(image)
        case .correct: correctSolutionImages.append(image)
        }
    }
    
    private func triggerOCR() {
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
    
    private func initializeData() {
        editedTitle = mistakeSet.title
        selectedSubject = mistakeSet.subject
        editedOriginalQuestion = mistakeSet.originalQuestion
        editedSource = mistakeSet.source
        editedErrorReason = mistakeSet.errorReason
        editedWrongSolution = mistakeSet.wrongSolution
        editedCorrectSolution = mistakeSet.correctSolution
        editedDate = mistakeSet.date
        
        // Load existing images
        questionImages = mistakeSet.questionImages.compactMap { UIImage(data: $0) }
        reasonImages = mistakeSet.reasonImages.compactMap { UIImage(data: $0) }
        wrongSolutionImages = mistakeSet.wrongSolutionImages.compactMap { UIImage(data: $0) }
        correctSolutionImages = mistakeSet.correctSolutionImages.compactMap { UIImage(data: $0) }
    }
    
    // 保存逻辑
    private func saveChanges() {
        var updatedMistake = mistakeSet
        updatedMistake.title = editedTitle
        updatedMistake.subject = selectedSubject
        updatedMistake.originalQuestion = editedOriginalQuestion
        updatedMistake.source = editedSource
        updatedMistake.errorReason = editedErrorReason
        updatedMistake.wrongSolution = editedWrongSolution
        updatedMistake.correctSolution = editedCorrectSolution
        updatedMistake.date = editedDate
        
        // Save images
        updatedMistake.questionImages = questionImages.compactMap { $0.jpegData(compressionQuality: 0.8) }
        updatedMistake.reasonImages = reasonImages.compactMap { $0.jpegData(compressionQuality: 0.8) }
        updatedMistake.wrongSolutionImages = wrongSolutionImages.compactMap { $0.jpegData(compressionQuality: 0.8) }
        updatedMistake.correctSolutionImages = correctSolutionImages.compactMap { $0.jpegData(compressionQuality: 0.8) }
        
        dataManager.updateMistake(updatedMistake)
        presentationMode.wrappedValue.dismiss()
    }
    
    // MARK: - Subviews
    
    private func buildInfoRow(icon: String, color: Color, label: String, text: Binding<String>, leftPadding: CGFloat, labelWidth: CGFloat, iconWidth: CGFloat, iconLabelSpacing: CGFloat) -> some View {
        HStack(spacing: iconLabelSpacing) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: iconWidth, alignment: .center)
            
            Text(label)
                .frame(width: labelWidth, alignment: .leading)
            
            TextField(label, text: text)
                .multilineTextAlignment(.trailing)
        }
        .padding(leftPadding)
    }
    
    private func buildDateRow(leftPadding: CGFloat, labelWidth: CGFloat, iconWidth: CGFloat, iconLabelSpacing: CGFloat) -> some View {
        HStack(spacing: iconLabelSpacing) {
            Image(systemName: "calendar")
                .foregroundColor(.pink)
                .frame(width: iconWidth, alignment: .center)
            
            Text("Date")
                .frame(width: labelWidth, alignment: .leading)
            
            Spacer()
            
            DatePicker("", selection: $editedDate, displayedComponents: .date)
                .labelsHidden()
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(leftPadding)
    }
    
    private var currentBinding: Binding<String> {
        switch selectedSection {
        case .question: return $editedOriginalQuestion
        case .reason: return $editedErrorReason
        case .wrong: return $editedWrongSolution
        case .correct: return $editedCorrectSolution
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
    
    return MistakeDetailEditView(
        dataManager: mockDataManager,
        mistakeSet: mockMistake
    )
}
