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
        switch self {
        case .question: return "doc.text"
        case .reason: return "exclamationmark.triangle"
        case .wrong: return "xmark.circle"
        case .correct: return "checkmark.circle"
        }
    }
    
    var title: String {
        switch self {
        case .question: return "Question".localized()
        case .reason: return "Error Reason".localized()
        case .wrong: return "Wrong Solution".localized()
        case .correct: return "Correct Solution".localized()
        }
    }
}

struct NewMistakeSetView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var editedTitle = ""
    @State private var selectedSubject = ""
    @State private var editedOriginalQuestion = ""
    @State private var editedSource = ""
    @State private var editedErrorReason = ""
    @State private var editedWrongSolution = ""
    @State private var editedCorrectSolution = ""
    @State private var editedDate = Date()
    
    @State private var selectedSection: EditSection = .question
    
    @State private var questionImages: [UIImage] = []
    @State private var reasonImages: [UIImage] = []
    @State private var wrongSolutionImages: [UIImage] = []
    @State private var correctSolutionImages: [UIImage] = []
    
    @State private var showingImagePicker = false
    @State private var showingPhotoCapture = false
    
    @State private var showMarkdownPreview = false
    @State private var isProcessingOCR = false
    @State private var showingOCRAlert = false
    @State private var ocrErrorMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                basicInfoSection
                contentEditorSection
                imagesSection
            }
            .adaptiveForm()
            .navigationTitle("New Mistake".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
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
private extension NewMistakeSetView {
    
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
        }
    }
    
    var contentEditorSection: some View {
        Section(header: Text(selectedSection.title.localized())) {
            Picker("Section".localized(), selection: $selectedSection) {
                ForEach(EditSection.allCases) { section in
                    Text(section.title.localized()).tag(section)
                }
            }
            .pickerStyle(.segmented)

            TextEditor(text: currentBinding)
                .frame(minHeight: 160)
                .font(.body)

            Toggle(isOn: $showMarkdownPreview) {
                Label(showMarkdownPreview ? "Hide Preview".localized() : "Show Preview".localized(),
                      systemImage: showMarkdownPreview ? "eye.slash" : "eye")
            }

            if showMarkdownPreview {
                MarkdownPreviewView(text: currentBinding.wrappedValue)
                    .frame(minHeight: 100)
            }
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
                    saveMistake()
                    presentationMode.wrappedValue.dismiss()
                }
                .fontWeight(.semibold)
                .disabled(editedTitle.isEmpty || editedOriginalQuestion.isEmpty)
            }
        }
    }
}

// MARK: - Helpers
private extension NewMistakeSetView {
    
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
    
    func saveMistake() {
        let newMistake = MistakeNote(
            title: editedTitle.isEmpty ? "Untitled".localized() : editedTitle,
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
        init(_ parent: ImagePickerWithCompletion) { self.parent = parent }
        
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
        init(_ parent: PhotoCaptureWithCompletion) { self.parent = parent }
        
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

// MARK: - Markdown Preview
struct MarkdownPreviewView: View {
    let text: String

    var body: some View {
        if text.isEmpty {
            Text("No content to preview".localized())
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
