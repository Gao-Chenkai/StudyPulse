//
//  MistakePDFExportSheet.swift
//  StudyPulse
//
//  错题 PDF 导出选项 sheet：
//  - 模式（按科目 / 按时间范围 / 按具体错题）三选一
//  - 实时显示预计导出的错题数
//  - 包含图片开关（默认开）
//
//  按下 Generate 后回调到父视图（MistakeView），父视图负责创建
//  snapshot + 启动进度 sheet。
//

import SwiftUI

enum MistakeExportMode: String, CaseIterable, Identifiable {
    case bySubjects
    case byDateRange
    case byMistakes

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bySubjects: return "By Subjects".localized()
        case .byDateRange: return "By Date Range".localized()
        case .byMistakes: return "By Mistakes".localized()
        }
    }
}

struct MistakeExportOptions: Sendable {
    let selection: MistakePDFSelection
    let includeImages: Bool
}

struct MistakePDFExportSheet: View {
    let onGenerate: (MistakeExportOptions) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager

    @State private var mode: MistakeExportMode = .bySubjects

    // bySubjects
    @State private var selectedSubjects: Set<String> = []

    // byDateRange
    @State private var range: ReportTimeRange = .all
    @State private var customStart: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var customEnd: Date = Date()

    // byMistakes
    @State private var selectedMistakeIDs: Set<UUID> = []
    @State private var mistakeSearchText: String = ""

    // Common
    @State private var includeImages: Bool = true

    var body: some View {
        NavigationStack {
            Form {
                modeSection
                selectionSection
                imageSection
                summarySection
            }
            .navigationTitle("Export PDF".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel".localized()) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Generate PDF".localized(), action: generate)
                        .fontWeight(.semibold)
                        .disabled(previewCount == 0 || currentSelection == nil)
                }
            }
        }
        .onAppear {
            Log.record(.info, category: "Export", message: "打开错题 PDF 导出 sheet / Opened mistake PDF export sheet")
        }
    }

    // MARK: - Mode section

    private var modeSection: some View {
        Section {
            Picker("Mode".localized(), selection: $mode) {
                ForEach(MistakeExportMode.allCases) { m in
                    Text(m.displayName).tag(m)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Selection Mode".localized())
        }
    }

    // MARK: - Selection section (按 mode 切换)

    @ViewBuilder
    private var selectionSection: some View {
        switch mode {
        case .bySubjects:
            subjectSelectionSection
        case .byDateRange:
            dateRangeSection
        case .byMistakes:
            mistakeSelectionSection
        }
    }

    private var subjectSelectionSection: some View {
        Section {
            let subjects = dataManager.subjects.filter { $0.enabled }
            if subjects.isEmpty {
                Text("No subjects available".localized())
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(subjects, id: \.name) { subject in
                    Button {
                        toggleSubject(subject.name)
                    } label: {
                        HStack {
                            Image(systemName: selectedSubjects.contains(subject.name) ? "checkmark.square.fill" : "square")
                                .foregroundColor(selectedSubjects.contains(subject.name) ? .blue : .secondary)
                            Text(subject.displayName.localized())
                                .foregroundColor(.primary)
                            Spacer()
                            let count = dataManager.mistakeSets.filter { $0.subject == subject.name }.count
                            Text("\(count)")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        } header: {
            HStack {
                Text("Subjects".localized())
                Spacer()
                if !selectedSubjects.isEmpty {
                    Button("Select All".localized()) {
                        selectedSubjects = Set(dataManager.subjects.filter { $0.enabled }.map { $0.name })
                    }
                    .font(.caption)
                }
            }
        }
    }

    private var dateRangeSection: some View {
        Section {
            Picker("Time Range".localized(), selection: $range) {
                ForEach(ReportTimeRange.allCases) { r in
                    Text(r.displayName).tag(r)
                }
            }
            if range == .custom {
                DatePicker("Start".localized(), selection: $customStart, displayedComponents: .date)
                DatePicker("End".localized(), selection: $customEnd, in: ...Date(), displayedComponents: .date)
            }
        } header: {
            Text("Time Range".localized())
        }
    }

    private var mistakeSelectionSection: some View {
        Section {
            if dataManager.mistakeSets.isEmpty {
                Text("No mistakes available".localized())
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                let sorted = dataManager.mistakeSets.sorted { $0.date > $1.date }
                ForEach(filteredMistakes(sorted), id: \.id) { mistake in
                    Button {
                        toggleMistake(mistake.id)
                    } label: {
                        HStack(alignment: .top) {
                            Image(systemName: selectedMistakeIDs.contains(mistake.id) ? "checkmark.square.fill" : "square")
                                .foregroundColor(selectedMistakeIDs.contains(mistake.id) ? .blue : .secondary)
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mistake.title.isEmpty ? "Untitled".localized() : mistake.title)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                HStack(spacing: 6) {
                                    if !mistake.subject.isEmpty {
                                        Text(mistake.subject.localized())
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    Text(mistake.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                        }
                    }
                }
            }
        } header: {
            HStack {
                Text("Mistakes".localized())
                Spacer()
                if !selectedMistakeIDs.isEmpty {
                    Button("Clear".localized()) {
                        selectedMistakeIDs.removeAll()
                    }
                    .font(.caption)
                }
            }
        }
    }

    // MARK: - Image toggle

    private var imageSection: some View {
        Section {
            Toggle("Include Images".localized(), isOn: $includeImages)
        } header: {
            Text("Options".localized())
        } footer: {
            if includeImages {
                Text("Images embedded in each section will be included. Larger PDF size.".localized())
                    .font(.caption2)
            } else {
                Text("Only text content will be exported. Smaller PDF size.".localized())
                    .font(.caption2)
            }
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        Section {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.orange)
                Text(String(format: "%d mistakes will be exported".localized(), previewCount))
                    .font(.subheadline)
                Spacer()
            }
        }
    }

    // MARK: - Helpers

    private func filteredMistakes(_ mistakes: [MistakeNote]) -> [MistakeNote] {
        let trimmed = mistakeSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return mistakes }
        return mistakes.filter {
            $0.title.localizedCaseInsensitiveContains(trimmed) ||
            $0.subject.localizedCaseInsensitiveContains(trimmed) ||
            $0.originalQuestion.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private func toggleSubject(_ name: String) {
        if selectedSubjects.contains(name) {
            selectedSubjects.remove(name)
        } else {
            selectedSubjects.insert(name)
        }
    }

    private func toggleMistake(_ id: UUID) {
        if selectedMistakeIDs.contains(id) {
            selectedMistakeIDs.remove(id)
        } else {
            selectedMistakeIDs.insert(id)
        }
    }

    /// 实时计算错题数（不创建 snapshot）。
    private var previewCount: Int {
        guard let sel = currentSelection else { return 0 }
        return MistakePDFSnapshot.filter(dataManager.mistakeSets, with: sel).count
    }

    /// 根据当前 UI 状态生成 selection。
    private var currentSelection: MistakePDFSelection? {
        switch mode {
        case .bySubjects:
            guard !selectedSubjects.isEmpty else { return nil }
            return .bySubjects(selectedSubjects)
        case .byDateRange:
            let (start, end) = effectiveRange()
            return .byDateRange(start: start, end: end)
        case .byMistakes:
            guard !selectedMistakeIDs.isEmpty else { return nil }
            return .byIDs(selectedMistakeIDs)
        }
    }

    private func effectiveRange() -> (start: Date, end: Date) {
        switch range {
        case .custom:
            if customStart <= customEnd {
                return (customStart, customEnd)
            } else {
                return (customEnd, customStart)
            }
        default:
            return range.resolve()
        }
    }

    private func generate() {
        guard let sel = currentSelection, !dataManager.mistakeSets.isEmpty else { return }
        let options = MistakeExportOptions(selection: sel, includeImages: includeImages)
        Log.record(.info, category: "Export", message: "错题 PDF 导出开始 / Mistake PDF export started: count=\(previewCount), mode=\(mode.rawValue), includeImages=\(includeImages)")
        dismiss()
        // 等 sheet 关闭动画开始后再触发回调，避免与 dismiss 冲突。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            onGenerate(options)
        }
    }
}
