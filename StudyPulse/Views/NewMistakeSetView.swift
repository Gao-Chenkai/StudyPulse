//
//  NewMistakeSetView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import SwiftUI
import MarkdownUI

// MARK: - EditSection Enum
enum EditSection: String, CaseIterable, Identifiable {
    case question = "Question"
    case reason = "Reason"
    case wrong = "Wrong"
    case correct = "Correct"
    
    var id: String { self.rawValue }
    
    var icon: String {
        if self == .question { return "doc.text" }
        if self == .reason { return "exclamationmark.triangle" }
        if self == .wrong { return "xmark.circle" }
        if self == .correct { return "checkmark.circle" }
        return "questionmark"
    }
    
    var title: String {
        if self == .question { return "题目" }
        if self == .reason { return "错因" }
        if self == .wrong { return "错解" }
        if self == .correct { return "正解" }
        return ""
    }
    
    var color: Color {
        if self == .question { return .blue }
        if self == .reason { return .orange }
        if self == .wrong { return .red }
        if self == .correct { return .green }
        return .gray
    }
}

struct NewMistakeSetView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.presentationMode) var presentationMode
    
    // MARK: - State Properties
    @State private var editedTitle = ""
    @State private var selectedSubject = ""
    @State private var editedOriginalQuestion = ""
    @State private var editedSource = ""
    @State private var editedErrorReason = ""
    @State private var editedWrongSolution = ""
    @State private var editedCorrectSolution = ""
    @State private var editedDate = Date()
    
    @State private var selectedSection: EditSection = .question
    
    // Image states for each section
    @State private var questionImages: [UIImage] = []
    @State private var reasonImages: [UIImage] = []
    @State private var wrongSolutionImages: [UIImage] = []
    @State private var correctSolutionImages: [UIImage] = []
    
    // Image picker states
    @State private var showingImagePicker = false
    @State private var showingPhotoCapture = false
    
    @State private var showMarkdownPreview = false
    @State private var isProcessingOCR = false
    @State private var showingOCRAlert = false
    @State private var ocrErrorMessage = ""
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    
                    // --- Basic Info ---
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
                    
                    // --- Segmented Control ---
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
                    
                    // --- Editor Area (Split: Input + Preview) ---
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
                        
                        // Image section for current selected section
                        imageSectionForCurrentSection
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("New Mistake")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveMistake()
                    }
                    .fontWeight(.semibold)
                    .disabled(editedTitle.isEmpty || editedOriginalQuestion.isEmpty)
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
        if let imageData = image.jpegData(compressionQuality: 0.8) {
            switch selectedSection {
            case .question: questionImages.append(image)
            case .reason: reasonImages.append(image)
            case .wrong: wrongSolutionImages.append(image)
            case .correct: correctSolutionImages.append(image)
            }
        }
    }
    
    private func triggerOCR() {
        guard let lastImage = currentSectionImages.wrappedValue.last else { return }
        isProcessingOCR = true
        
        Task {
            do {
                let recognizedText = try await OCRManager.recognizeText(in: lastImage)
                // Append OCR text to current editor
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
    
    // MARK: - Subviews
    
    /// 构建单行信息输入
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
    
    /// 构建日期选择行
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
    
    /// 动态获取当前选中部分的文本绑定
    private var currentBinding: Binding<String> {
        switch selectedSection {
        case .question: return $editedOriginalQuestion
        case .reason: return $editedErrorReason
        case .wrong: return $editedWrongSolution
        case .correct: return $editedCorrectSolution
        }
    }
    
    /// 保存逻辑
    private func saveMistake() {
        let newMistake = MistakeNote(
            title: editedTitle.isEmpty ? "Untitled Mistake" : editedTitle,
            subject: selectedSubject,
            originalQuestion: editedOriginalQuestion,
            source: editedSource,
            date: editedDate,
            errorReason: editedErrorReason,
            wrongSolution: editedWrongSolution,
            correctSolution: editedCorrectSolution,
            questionImages: questionImages.compactMap { $0.jpegData(compressionQuality: 0.8) },
            reasonImages: reasonImages.compactMap { $0.jpegData(compressionQuality: 0.8) },
            wrongSolutionImages: wrongSolutionImages.compactMap { $0.jpegData(compressionQuality: 0.8) },
            correctSolutionImages: correctSolutionImages.compactMap { $0.jpegData(compressionQuality: 0.8) }
        )
        dataManager.addMistake(newMistake)
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Image Picker with Completion Handler
struct ImagePickerWithCompletion: UIViewControllerRepresentable {
    var onDismiss: (UIImage?) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePickerWithCompletion
        
        init(_ parent: ImagePickerWithCompletion) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.onDismiss(uiImage)
            } else {
                parent.onDismiss(nil)
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onDismiss(nil)
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Photo Capture with Completion Handler
struct PhotoCaptureWithCompletion: UIViewControllerRepresentable {
    var onDismiss: (UIImage?) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: PhotoCaptureWithCompletion
        
        init(_ parent: PhotoCaptureWithCompletion) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.onDismiss(uiImage)
            } else {
                parent.onDismiss(nil)
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onDismiss(nil)
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Markdown Preview Sheet (kept for backward compat)
struct MarkdownPreviewSheet: View {
    @Environment(\.dismiss) var dismiss
    let title: String
    let content: String
    let tintColor: Color
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(tintColor)
                    
                    Divider()
                    
                    if content.isEmpty {
                        Text("No content to preview")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        MarkdownPreviewView(text: content)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Markdown Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Inline Markdown Preview View
struct MarkdownPreviewView: View {
    let text: String
    
    var body: some View {
        if text.isEmpty {
            Text("No content to preview")
                .foregroundColor(.secondary)
                .italic()
                .frame(maxWidth: .infinity, alignment: .center)
        } else {
            Markdown(text)
                .markdownTheme(.gitHub)
        }
    }
}

#Preview {
    NewMistakeSetView()
        .environmentObject(DataManager())
}
