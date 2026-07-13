//
//  ExamReviewView.swift
//  StudyPulse
//
//  考试复盘编辑器：4 段 Markdown 模板（考了什么/错什么/学到什么/下次策略）
//  + 关联同科目错题 + 一键生成错题。
//  Exam review editor: 4-section Markdown template + linked mistakes
//  from the same subject + one-click "generate mistake note".
//
//  Created by Chenkai Gao on 2026/7/5.
//

import SwiftUI
import SwiftStreamingMarkdown
import os

// MARK: - 复盘段落（与 ExamReview 字段对应）
// MARK: - Review section (maps 1:1 to ExamReview fields)

/// 复盘编辑器中的 4 个段落(与 `ExamReview` 字段一一对应)
/// Four review sections, one per `ExamReview` field.
private enum ReviewSection: String, CaseIterable, Identifiable {
    case tested, wrong, learned, strategy

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .tested:  return "doc.text.magnifyingglass"
        case .wrong:    return "exclamationmark.triangle"
        case .learned:  return "lightbulb"
        case .strategy: return "arrow.uturn.forward"
        }
    }

    var title: String {
        switch self {
        case .tested:  return "What Was Tested"
        case .wrong:    return "What Went Wrong"
        case .learned:  return "What I Learned"
        case .strategy: return "Next Strategy"
        }
    }

    var placeholder: String {
        switch self {
        case .tested:  return "List the topics / question types / difficulty level covered…"
        case .wrong:    return "Specific mistakes, root causes, knowledge gaps…"
        case .learned:  return "Insights, methods you finally understand, things to remember…"
        case .strategy: return "Concrete plan for the next exam (study / sleep / pacing)…"
        }
    }
}

// MARK: - Exam Review View
// MARK: - Exam review view

/// 考试复盘编辑器(4 段 Markdown)
/// Exam review editor (4-section Markdown).
struct ExamReviewView: View {
    let exam: Exam

    @Environment(RepositoryContainer.self) private var container
    @Environment(\.presentationMode) var presentationMode

    /// 4 段 Markdown 文本(初值取自已有复盘)
    /// 4-section Markdown text (seeded from any existing review).
    @State private var whatWasTested: String
    @State private var whatWentWrong: String
    @State private var whatLearned: String
    @State private var nextStrategy: String

    /// 关联的错题 id 集合(同 subject 范围内多选)
    /// Set of linked mistake IDs (multi-select within the same subject).
    @State private var linkedMistakeIds: Set<UUID>

    /// 顶部 segmented Picker 当前选中的段落
    /// Top picker — currently selected review section.
    @State private var selectedSection: ReviewSection = .tested

    /// 一键生成错题的反馈
    /// One-click "generate mistake note" feedback.
    @State private var showingGenerateAlert = false
    @State private var generateAlertMessage = ""
    @State private var didGenerateNote = false

    /// 关联错题列表(同 subject)
    /// Linked-mistake list (same subject, newest first).
    private var relatedMistakes: [MistakeNote] {
        container.mistakeRepo.mistakeSets
            .filter { $0.subject == exam.subject }
            .sorted { $0.date > $1.date }
    }

    /// 当前 draft 是否为空(全空 + 无关联错题)
    /// Whether the current draft is empty (all 4 sections empty + no linked mistakes).
    private var draftIsEmpty: Bool {
        whatWasTested.isEmpty &&
        whatWentWrong.isEmpty &&
        whatLearned.isEmpty &&
        nextStrategy.isEmpty &&
        linkedMistakeIds.isEmpty
    }

    init(exam: Exam) {
        self.exam = exam
        let review = exam.examReview
        _whatWasTested = State(initialValue: review?.whatWasTested ?? "")
        _whatWentWrong = State(initialValue: review?.whatWentWrong ?? "")
        _whatLearned   = State(initialValue: review?.whatLearned ?? "")
        _nextStrategy  = State(initialValue: review?.nextStrategy ?? "")
        _linkedMistakeIds = State(initialValue: Set(review?.linkedMistakeIds ?? []))
    }

    var body: some View {
        NavigationStack {
            Form {
                templateSection
                editorSection
                linkedMistakesSection
                generateSection
            }
            .adaptiveForm()
            .navigationTitle("Exam Review".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel".localized()) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save".localized()) {
                        saveReview()
                    }
                    .fontWeight(.semibold)
                    .disabled(draftIsEmpty)
                }
            }
            .alert("Mistake Note Added".localized(), isPresented: $showingGenerateAlert) {
                Button("OK".localized()) { }
            } message: {
                Text(generateAlertMessage)
            }
        }
    }

    // MARK: - Sections
    // MARK: - Sections

    /// 顶部模板提示(列出 4 段填写引导,首次进入时给个 visible cue)
    /// Top template hint — lists 4 section prompts as a visible cue on first open.
    private var templateSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "list.bullet.rectangle")
                        .foregroundColor(.accentColor)
                    Text("Template".localized())
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                Text(templateHint)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    /// 复盘 4 段编辑器(顶部 picker 切换)
    /// 4-section editor (top picker switches between sections).
    private var editorSection: some View {
        Section(header: Text(selectedSection.title.localized())) {
            Picker("Section".localized(), selection: $selectedSection) {
                ForEach(ReviewSection.allCases) { section in
                    HStack(spacing: 4) {
                        Image(systemName: section.icon)
                        Text(section.title.localized())
                    }
                    .tag(section)
                }
            }
            .pickerStyle(.menu)

            // 切换段落时强制重建 UIViewRepresentable,避免 binding 切换异常
            // Force-rebuild the UIViewRepresentable when switching sections to avoid binding glitches.
            Group {
                switch selectedSection {
                case .tested:
                    MarkdownEditorView(text: $whatWasTested, placeholder: selectedSection.placeholder)
                case .wrong:
                    MarkdownEditorView(text: $whatWentWrong, placeholder: selectedSection.placeholder)
                case .learned:
                    MarkdownEditorView(text: $whatLearned, placeholder: selectedSection.placeholder)
                case .strategy:
                    MarkdownEditorView(text: $nextStrategy, placeholder: selectedSection.placeholder)
                }
            }
            .id(selectedSection)
            .frame(minHeight: 480)
        }
    }

    /// 关联同科目错题多选
    /// Multi-select for related mistakes (same subject).
    private var linkedMistakesSection: some View {
        Section {
            if relatedMistakes.isEmpty {
                HStack {
                    Image(systemName: "tray")
                        .foregroundColor(.secondary)
                    Text("No related mistakes for this subject".localized())
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
            } else {
                ForEach(relatedMistakes) { mistake in
                    Toggle(isOn: Binding(
                        get: { linkedMistakeIds.contains(mistake.id) },
                        set: { isOn in
                            if isOn { linkedMistakeIds.insert(mistake.id) }
                            else    { linkedMistakeIds.remove(mistake.id) }
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mistake.title)
                                .font(.subheadline)
                                .lineLimit(1)
                            Text(mistake.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        } header: {
            HStack {
                Text("Linked Mistakes".localized())
                Spacer()
                if !linkedMistakeIds.isEmpty {
                    Text(String(format: "%d selected".localized(), linkedMistakeIds.count))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        } footer: {
            Text("Tick mistakes you made on this exam. They'll be linked to the review but won't change the original mistake notes.".localized())
        }
    }

    /// 一键生成错题
    /// One-click "generate mistake note" section.
    private var generateSection: some View {
        Section {
            Button {
                generateMistakeNote()
            } label: {
                HStack {
                    Image(systemName: "wand.and.stars")
                        .foregroundColor(.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Generate Mistake Note".localized())
                            .foregroundColor(.accentColor)
                            .fontWeight(.medium)
                        Text("Creates a new mistake note from this review, auto-enrolled in SRS.".localized())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .disabled(draftIsEmpty)
        } footer: {
            Text("Useful when you want to attach this review to your mistake notebook for spaced-repetition review.".localized())
        }
    }

    // MARK: - Logic
    // MARK: - Logic

    /// 顶部 4 段填写引导文本
    /// Top 4-section prompt text.
    private var templateHint: String {
        """
        • \(ReviewSection.tested.title.localized()): 列出考试涉及到的考点、题型、难度。
        • \(ReviewSection.wrong.title.localized()): 具体的错误、根本原因、知识盲点。
        • \(ReviewSection.learned.title.localized()): 这次搞懂的思路 / 题型套路 / 易错点。
        • \(ReviewSection.strategy.title.localized()): 下次考试的具体计划(复习/作息/时间分配)。
        """
    }

    /// 把当前 draft 写回 DataManager,并 dismiss
    /// Persist the current draft back to the DataManager and dismiss.
    private func saveReview() {
        let review = ExamReview(
            reviewedAt: Date(),
            whatWasTested: whatWasTested,
            whatWentWrong: whatWentWrong,
            whatLearned: whatLearned,
            nextStrategy: nextStrategy,
            linkedMistakeIds: Array(linkedMistakeIds)
        )
        container.examRepo.updateExamReview(exam.id, review: review)
        Log.data.info("复盘保存 / Review saved: exam=\(exam.id.uuidString, privacy: .public)")
        presentationMode.wrappedValue.dismiss()
    }

    /// 用当前 draft 生成一张 MistakeNote,自动入 SRS 队列
    /// Generate a MistakeNote from the current draft and auto-enrol in the SRS queue.
    private func generateMistakeNote() {
        // 标题去重:已有"复盘:<examName>"则追加日期后缀
        // De-dupe title: append a date suffix if "复盘:<examName>" already exists.
        let baseTitle = "复盘:\(exam.name)"
        var title = baseTitle
        let sameTitle = container.mistakeRepo.mistakeSets.filter { $0.title.hasPrefix(baseTitle) }
        if !sameTitle.isEmpty {
            let df = DateFormatter()
            df.dateFormat = "yyyyMMdd"
            title = "\(baseTitle) (\(df.string(from: Date())))"
        }

        let note = MistakeNote(
            title: title,
            subject: exam.subject,
            originalQuestion: whatWasTested,
            source: "Exam Review · \(exam.name)",
            date: Date(),
            errorReason: whatWentWrong,
            wrongSolution: "",
            correctSolution: ExamReview(
                reviewedAt: Date(),
                whatWasTested: whatWasTested,
                whatWentWrong: whatWentWrong,
                whatLearned: whatLearned,
                nextStrategy: nextStrategy,
                linkedMistakeIds: []
            ).composedMarkdown,
            reviewState: .initial(),
            phaseId: exam.phaseId
        )
        container.addMistake(note)
        // 调度 SRS 复习通知(沿用 NewMistakeSetView 的做法)
        // Reschedule SRS review notifications (same approach as NewMistakeSetView).
        SRSReviewNotifications.shared.rescheduleAll(mistakes: container.mistakeRepo.mistakeSets)

        didGenerateNote = true
        generateAlertMessage = String(
            format: "已创建错题 \"%@\",并加入 SRS 复习队列。".localized(),
            title
        )
        showingGenerateAlert = true
    }
}

// MARK: - Preview
// MARK: - Preview

#Preview {
    let container = RepositoryContainer()
    let testExam = Exam(
        name: "Math Midterm",
        date: Date().addingTimeInterval(-86400 * 1.5),
        importance: 5,
        subject: "Math",
        examName: "2026 春季期中",
        masteryDegree: 60
    )
    container.examRepo.add(single: [testExam], comprehensive: [])
    return ExamReviewView(exam: testExam)
        .environment(container)
}
