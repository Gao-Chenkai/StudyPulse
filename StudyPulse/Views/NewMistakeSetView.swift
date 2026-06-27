//
//  NewMistakeSetView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import SwiftUI

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

    @State private var isProcessingOCR = false
    @State private var showingOCRAlert = false
    @State private var ocrErrorMessage = ""

    /// Default empty-state initializer used by the app and previews that
    /// don't need to seed the form.
    init() {}

    /// Initialiser that seeds the editable fields with sample content.
    /// Used by the `#Preview` to demonstrate the editor + live preview
    /// without forcing the developer to type in the canvas first.
    init(sampleMistake: SampleMistake) {
        self._editedTitle = State(initialValue: sampleMistake.title)
        self._selectedSubject = State(initialValue: sampleMistake.subject)
        self._editedOriginalQuestion = State(initialValue: sampleMistake.originalQuestion)
        self._editedSource = State(initialValue: sampleMistake.source)
        self._editedErrorReason = State(initialValue: sampleMistake.errorReason)
        self._editedWrongSolution = State(initialValue: sampleMistake.wrongSolution)
        self._editedCorrectSolution = State(initialValue: sampleMistake.correctSolution)
        self._editedDate = State(initialValue: sampleMistake.date)
        self._selectedSection = State(initialValue: sampleMistake.selectedSection)
    }
    
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

            MarkdownEditorView(
                text: currentBinding,
                placeholder: "Supports Markdown, math $...$ and chemistry $\\ce{...}$"
            )
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

// MARK: - Sample Mistake (for previews)

/// A simple value type that carries the four editable markdown blocks
/// (plus title / subject / source / date) so the `#Preview` can open
/// the editor with realistic content and exercise the live preview
/// without forcing the developer to type in the canvas first.
struct SampleMistake {
    var title: String = ""
    var subject: String = ""
    var source: String = ""
    var date: Date = Date()
    var originalQuestion: String = ""
    var errorReason: String = ""
    var wrongSolution: String = ""
    var correctSolution: String = ""
    var selectedSection: EditSection = .question

    /// A representative problem that hits every rendering path:
    /// headings, lists, task lists, code blocks, tables, inline math
    /// (`$...$`), display math (`$$...$$`) and chemistry (`\ce`).
    static let quadratic = SampleMistake(
        title: "Quadratic Equation Mistake",
        subject: "Mathematics",
        source: "2026 Spring Midterm",
        date: Date(),
        originalQuestion: """
        # 二次方程求根

        解下列方程并写出 **判别式** 的值：

        $$x^2 - 5x + 6 = 0$$

        其中 $a = 1$，$b = -5$，$c = 6$。
        
        s
        """,
        errorReason: """
        ## 错误原因

        - 没有正确展开 $(x-1)(x-6)$
        - 把 $\\Delta = b^2 - 4ac$ 算成了 $5^2 + 4 \\cdot 1 \\cdot 6$
        - 忽略了 $\\ce{H2SO4}$ 这种化学式的下标
        """,
        wrongSolution: """
        ## 我的错误解法

        我直接因式分解成 $(x-1)(x-6) = 0$，于是得到

        $$x_1 = 1,\\quad x_2 = 6$$

        但是用求根公式再算一次才发现 $1 + 6 = 7 \\neq 5$，**两根之和不对**。
        """,
        correctSolution: """
        ## 正确解法

        使用求根公式：

        $$x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}
            = \\frac{5 \\pm \\sqrt{25 - 24}}{2}
            = \\frac{5 \\pm 1}{2}$$

        所以 $x_1 = 3$，$x_2 = 2$，因式分解应为 $(x-2)(x-3) = 0$。

        ### 验证

        - [x] 判别式 $\\Delta = 1 > 0$ ⇒ 两个不等实根
        - [x] $x_1 + x_2 = 5 = -b/a$ ✓
        - [x] $x_1 \\cdot x_2 = 6 = c/a$ ✓

        ```python
        import sympy as sp
        x = sp.symbols('x')
        print(sp.solve(x**2 - 5*x + 6, x))
        # [2, 3]
        ```

        | 步骤 | 结果 |
        |------|------|
        | 判别式 | $1$ |
        | $x_1$ | $3$ |
        | $x_2$ | $2$ |

        > 注意：化学里的 $\\ce{H2O}$ 与 $\\ce{2H2 + O2 -> 2H2O}$ 也要单独记一种格式。
        """,
        selectedSection: .wrong
    )

    /// A short snippet that just exercises the editor + preview path
    /// with a couple of inline formulas, a list and a code block — small
    /// enough to scan at a glance in the `#Preview` canvas.
    static let quick = SampleMistake(
        title: "Quick Test",
        subject: "Mathematics",
        source: "In-class Exercise",
        date: Date(),
        originalQuestion: "",
        errorReason: "",
        wrongSolution: """
        使用求根公式解 $x^2 - 5x + 6 = 0$：

        $$x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}$$

        - 判别式 $\\Delta = 1$
        - $x_1 = 3$, $x_2 = 2$

        ```swift
        let roots = (3, 2)
        ```
        """,
        correctSolution: "",
        selectedSection: .wrong
    )
}

#Preview("New Mistake") {
    let mockDataManager = DataManager()
    // Seed a few default subjects so the subject picker isn't empty in
    // the preview canvas. The view's @State text fields are still empty
    // — type into the editor to see the markdown render in the live
    // preview pane below.
    mockDataManager.subjects = [
        Subject(name: "Mathematics", displayName: "Math", enabled: true, fullScore: 150),
        Subject(name: "Physics", displayName: "Physics", enabled: true, fullScore: 100),
        Subject(name: "Chemistry", displayName: "Chemistry", enabled: true, fullScore: 100),
        Subject(name: "English", displayName: "English", enabled: true, fullScore: 150)
    ]

    return NewMistakeSetView()
        .environmentObject(mockDataManager)
}

#Preview("New Mistake — Wrong Solution Sample") {
    let mockDataManager = DataManager()
    mockDataManager.subjects = [
        Subject(name: "Mathematics", displayName: "Math", enabled: true, fullScore: 150),
        Subject(name: "Physics", displayName: "Physics", enabled: true, fullScore: 100),
        Subject(name: "Chemistry", displayName: "Chemistry", enabled: true, fullScore: 100),
        Subject(name: "English", displayName: "English", enabled: true, fullScore: 150)
    ]

    return NewMistakeSetView(sampleMistake: .quadratic)
        .environmentObject(mockDataManager)
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

