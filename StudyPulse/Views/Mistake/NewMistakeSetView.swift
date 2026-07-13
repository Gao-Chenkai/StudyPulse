//
//  NewMistakeSetView.swift
//  StudyPulse
//
//  新建错题页:basic info(标题/学科/难度/状态)+ 编辑 sections
//  (原题 / 错因 / 错解 / 正解) + 配图。
//  iPhone / iPad 共享(usesInternalNavigationStack)。
//
//  New mistake page: basic info (title / subject / difficulty / status) +
//  editable sections (question / reason / wrong / correct) + images.
//  Shared between iPhone and iPad (`usesInternalNavigationStack`).
//

import SwiftUI

// MARK: - EditSection Enum / 编辑分节枚举

/// "哪一段"被选中(决定 toolbar / OCR 作用到哪个 markdown 字段)
/// Which section is currently selected (drives which markdown field
/// the toolbar / OCR actions apply to).
enum EditSection: String, CaseIterable, Identifiable {
    case question = "Question"
    case reason = "Reason"
    case wrong = "Wrong"
    case correct = "Correct"

    var id: String { self.rawValue }

    /// SF Symbol 图标
    /// SF Symbol for the section.
    var icon: String {
        switch self {
        case .question: return "doc.text"
        case .reason: return "exclamationmark.triangle"
        case .wrong: return "xmark.circle"
        case .correct: return "checkmark.circle"
        }
    }

    /// 本地化标题
    /// Localized title.
    var title: String {
        switch self {
        case .question: return "Question".localized()
        case .reason: return "Error Reason".localized()
        case .wrong: return "Wrong Solution".localized()
        case .correct: return "Correct Solution".localized()
        }
    }
}

/// 新建错题主表单
/// New mistake main form.
struct NewMistakeSetView: View {
    @Environment(RepositoryContainer.self) private var container
    @Environment(\.presentationMode) var presentationMode

    /// 是否自己挂 NavigationStack(iPad split-view 上为 false)
    /// Whether to host its own NavigationStack (false in iPad split-view).
    let usesInternalNavigationStack: Bool

    /// 内部 ViewModel(表单字段 + 图片 + 验证)
    /// Internal view model (form fields + images + validation).
    @StateObject private var viewModel: NewMistakeSetViewModel

    /// 默认空态初始化
    /// Default empty-state initializer.
    init(container: RepositoryContainer, usesInternalNavigationStack: Bool = true) {
        self.usesInternalNavigationStack = usesInternalNavigationStack
        self._viewModel = StateObject(wrappedValue: NewMistakeSetViewModel(container: container))
    }

    /// 让 Siri 提供的值预填表单的便捷初始化
    /// Convenience init that seeds the form with Siri-provided values.
    init(container: RepositoryContainer, presetSubject: String, presetTitle: String, usesInternalNavigationStack: Bool = true) {
        self.usesInternalNavigationStack = usesInternalNavigationStack
        let vm = NewMistakeSetViewModel(container: container)
        vm.presetValues(subject: presetSubject, title: presetTitle)
        self._viewModel = StateObject(wrappedValue: vm)
    }

    /// 用 sample content 预填字段的初始化
    /// Initialiser that seeds the editable fields with sample content.
    init(container: RepositoryContainer, sampleMistake: SampleMistake, usesInternalNavigationStack: Bool = true) {
        self.usesInternalNavigationStack = usesInternalNavigationStack
        let vm = NewMistakeSetViewModel(container: container)
        vm.seedSampleMistake(sampleMistake)
        self._viewModel = StateObject(wrappedValue: vm)
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
        // 表单三段:basic / content / images
        // The form is split into three sections: basic / content / images.
        Form {
            basicInfoSection
            contentEditorSection
            imagesSection
        }
        .adaptiveForm()
        .navigationTitle("New Mistake".localized())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        // 系统图库 → 当前 section 的图片数组
        // System photo library → the current section's image array.
        .sheet(isPresented: $viewModel.showingImagePicker) {
            ImagePickerWithCompletion(onDismiss: { image in
                if let image = image { viewModel.addImageToCurrentSection(image) }
            })
            .ignoresSafeArea()
        }
        // 相机拍照 → 同上
        // Camera capture → same.
        .sheet(isPresented: $viewModel.showingPhotoCapture) {
            PhotoCaptureWithCompletion(onDismiss: { image in
                if let image = image { viewModel.addImageToCurrentSection(image) }
            })
            .ignoresSafeArea()
        }
        // PencilKit 手写 → 转 UIImage 追加
        // PencilKit hand-drawing → convert to UIImage and append.
        .sheet(isPresented: $viewModel.showingHandwritingSheet) {
            HandwritingSheet { pngData in
                if !pngData.isEmpty, let image = UIImage(data: pngData) {
                    viewModel.addImageToCurrentSection(image)
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
        // OCR 失败 alert
        // OCR failure alert.
        .alert("OCR Error".localized(), isPresented: $viewModel.showingOCRAlert) {
            Button("OK".localized()) { }
        } message: {
            Text(viewModel.ocrErrorMessage)
        }
        // OCR 进行中的全屏 loading 蒙层
        // Full-screen overlay shown while OCR is in progress.
        .overlay {
            if viewModel.isProcessingOCR {
                ProgressView("Recognizing text...".localized())
                    .padding(20)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 10)
            }
        }
        // iOS 26+ 上让 nav bar 背景透明
        // On iOS 26+ make the nav bar background transparent.
        .containerBackground(.clear, for: .navigation)
        .debugModeContainer()
        .debugLayoutBoundsAuto()
    }
}

// MARK: - Sections / 分组
private extension NewMistakeSetView {
    
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
        Section(header: Text(viewModel.selectedSection.title.localized())) {
            Picker("Section".localized(), selection: $viewModel.selectedSection) {
                ForEach(EditSection.allCases) { section in
                    Text(section.title.localized()).tag(section)
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
        // 图片区:四种来源(图库 / 拍照 / OCR / 手写)+ 横滑预览
        // Image section: four sources (library / camera / OCR / handwriting)
        // + horizontal preview strip.
        Section(header: Text("Images".localized())) {
            HStack {
                // 系统图库
                // System photo library.
                Button(action: { viewModel.showingImagePicker = true }) {
                    Label("Library".localized(), systemImage: "photo.on.rectangle.angled")
                }
                Spacer()
                // 相机拍照
                // Camera capture.
                Button(action: { viewModel.showingPhotoCapture = true }) {
                    Label("Camera".localized(), systemImage: "camera.fill")
                }
                Spacer()
                // OCR:把当前 section 的图 → 文本写回 markdown
                // OCR: convert the current section's images into text written back into the markdown.
                Button(action: { viewModel.triggerOCR() }) {
                    Label("OCR".localized(), systemImage: "text.viewfinder")
                }
                .disabled(viewModel.currentSectionImagesBinding.wrappedValue.isEmpty)
                Spacer()
                // iPad:手写页用 NavigationLink;iPhone:用 sheet
                // iPad: NavigationLink to the handwriting page; iPhone: sheet.
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

            // 当前 section 还没有图片 → 占位
            // Empty placeholder when there are no images in the current section.
            if viewModel.currentSectionImagesBinding.wrappedValue.isEmpty {
                Text("No images".localized())
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                // 横滑条:每张图右上角带红色删除按钮
                // Horizontal scroller: each thumbnail has a red delete button in the top-right.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.currentSectionImagesBinding.wrappedValue.indices, id: \.self) { index in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: viewModel.currentSectionImagesBinding.wrappedValue[index])
                                    .resizable()
                                    .scaledToFill()
                                    // 80x80 缩略图,cornerRadius 让圆角统一
                                    // 80x80 thumbnail, with a unified corner radius.
                                    .frame(width: 80, height: 80)
                                    .clipped()
                                    .cornerRadius(8)

                                // 红圈删除按钮
                                // Red-circle delete button.
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
        // 顶部 toolbar:Cancel + Save
        // Top toolbar: Cancel + Save.
        Group {
            ToolbarItem(placement: .navigationBarLeading) {
                // 直接 dismiss,无确认(用户随时可重开新增页)
                // Dismiss directly, no confirm (the user can always re-open the new page).
                Button("Cancel".localized()) { presentationMode.wrappedValue.dismiss() }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                // Save 按钮:viewModel.isSaveDisabled 已做必填校验
                // Save button: viewModel.isSaveDisabled already gates the required fields.
                Button("Save".localized()) {
                    viewModel.saveMistake()
                    presentationMode.wrappedValue.dismiss()
                }
                .fontWeight(.semibold)
                .disabled(viewModel.isSaveDisabled)
            }
        }
    }
}

// MARK: - Sample Mistake (for previews) / 示例错题(用于预览)

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
    let mockContainer = RepositoryContainer()
    // Seed a few default subjects so the subject picker isn't empty in
    // the preview canvas. The view's @State text fields are still empty
    // — type into the editor to see the markdown render in the live
    // preview pane below.
    mockContainer.subjectRepo.subjects = [
        Subject(name: "Mathematics", displayName: "Math", enabled: true, fullScore: 150),
        Subject(name: "Physics", displayName: "Physics", enabled: true, fullScore: 100),
        Subject(name: "Chemistry", displayName: "Chemistry", enabled: true, fullScore: 100),
        Subject(name: "English", displayName: "English", enabled: true, fullScore: 150)
    ]

    return NewMistakeSetView(container: mockContainer)
        .environment(mockContainer)
}

#Preview("New Mistake — Wrong Solution Sample") {
    let mockContainer = RepositoryContainer()
    mockContainer.subjectRepo.subjects = [
        Subject(name: "Mathematics", displayName: "Math", enabled: true, fullScore: 150),
        Subject(name: "Physics", displayName: "Physics", enabled: true, fullScore: 100),
        Subject(name: "Chemistry", displayName: "Chemistry", enabled: true, fullScore: 100),
        Subject(name: "English", displayName: "English", enabled: true, fullScore: 150)
    ]

    return NewMistakeSetView(container: mockContainer, sampleMistake: .quadratic)
        .environment(mockContainer)
}

// MARK: - Image Picker with Completion Handler / 带回调的图片选择器
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

// MARK: - Photo Capture with Completion Handler / 带回调的拍照
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
