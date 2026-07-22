import SwiftUI
import PhotosUI
import UIKit
import SwiftStreamingMarkdown

struct ExamAutopsyView: View {
    @Environment(RepositoryContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    let exam: Exam
    @StateObject private var vm: ExamAutopsyViewModel

    init(exam: Exam, container: RepositoryContainer) { self.exam = exam; _vm = StateObject(wrappedValue: ExamAutopsyViewModel(exam: exam, container: container)) }

    var body: some View {
        ScrollView {
            VStack(spacing: DesignToken.Spacing.cardSpacing) {
                headerCard; paperCard; analysisCard
                if !vm.record.items.isEmpty { itemsCard }
                if let report = vm.record.report { reportCard(report) }
            }.padding(.horizontal, DesignToken.Spacing.secondaryHorizontal).padding(.vertical, DesignToken.Spacing.large)
        }
        .background(Color(.systemGroupedBackground).opacity(DesignToken.Opacity.rootBackground))
        .navigationTitle("考试复盘")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
        .alert("复盘提示", isPresented: Binding(get: { vm.errorMessage != nil }, set: { if !$0 { vm.errorMessage=nil } })) { Button("好") { vm.errorMessage=nil } } message: { Text(vm.errorMessage ?? "") }
    }

    private var headerCard: some View { card { HStack { Image(systemName: "stethoscope").font(.title2).foregroundStyle(.purple); VStack(alignment:.leading,spacing:4){ Text("Exam Autopsy").font(DesignToken.Font.titleSmall); Text(exam.name).font(DesignToken.Font.subheadline).foregroundStyle(.secondary) }; Spacer(); if vm.record.report != nil { Label("已生成", systemImage:"checkmark.circle.fill").foregroundStyle(.green).font(DesignToken.Font.caption) } } } }

    private var paperCard: some View {
        card {
            VStack(alignment: .leading, spacing: DesignToken.Spacing.medium) {
                Label("试卷图片", systemImage: "photo.on.rectangle.angled").font(DesignToken.Font.titleSmall)
                if !vm.record.paperImages.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(Array(vm.record.paperImages.enumerated()), id: \.offset) { entry in
                                if let image = UIImage(data: entry.element) {
                                    Image(uiImage: image).resizable().scaledToFill()
                                        .frame(width: 80, height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: DesignToken.CornerRadius.small))
                                }
                            }
                        }
                    }
                }
                HStack {
                    PhotosPicker(selection: $vm.selectedItems, maxSelectionCount: 12, matching: .images) {
                        Label("添加图片", systemImage: "plus")
                    }.buttonStyle(.bordered)
                    Button { vm.addManualItem() } label: {
                        Label("手动添加错题", systemImage: "square.and.pencil")
                    }.buttonStyle(.bordered)
                }
            }
            .onChange(of: vm.selectedItems) { _, newValue in
                Task { await vm.addImages(newValue); vm.selectedItems = [] }
            }
        }
    }

    private var analysisCard: some View { card { VStack(alignment:.leading,spacing:DesignToken.Spacing.medium){ HStack{ Label("AI 识别草稿",systemImage:"sparkles").font(DesignToken.Font.titleSmall); Spacer(); if vm.isWorking { ProgressView() } }; Text("AI 只生成可编辑草稿，确认后才会写入错题本。无需 OCR。 ").font(DesignToken.Font.subheadline).foregroundStyle(.secondary); Button { Task { await vm.analyze(exam:exam) } } label: { Label(vm.record.report == nil ? "开始分析" : "重新分析",systemImage:"wand.and.stars") }.buttonStyle(.borderedProminent).disabled(vm.isWorking || vm.record.paperImages.isEmpty) } } }

    private var itemsCard: some View { card { VStack(alignment:.leading,spacing:DesignToken.Spacing.medium){ Label("逐题确认",systemImage:"checklist").font(DesignToken.Font.titleSmall); ForEach(vm.record.items){ item in AutopsyItemEditor(item:item){ vm.update($0) } }; HStack{ Button("导入已确认错题"){vm.importConfirmed(exam:exam)}; Button("生成 Todo"){vm.importTasks(exam:exam)} }.buttonStyle(.bordered) } } }

    private func reportCard(_ report: ExamAutopsyReport) -> some View { card { VStack(alignment:.leading,spacing:DesignToken.Spacing.medium){ Label("复盘报告",systemImage:"chart.bar.doc.horizontal").font(DesignToken.Font.titleSmall); MarkdownPreviewView(text: report.conclusion.isEmpty ? "已完成逐题分析，请根据确认结果修复。" : report.conclusion).frame(maxHeight:140); if !report.keyProblems.isEmpty { Text("关键问题").font(DesignToken.Font.bodyBold); ForEach(report.keyProblems,id:\.self){ MarkdownPreviewView(text: $0).frame(maxHeight:100) } }; if !report.reasonCounts.isEmpty { ForEach(report.reasonCounts.sorted{$0.value>$1.value},id:\.key){ key,value in HStack{ Text(key).font(DesignToken.Font.subheadline); Spacer(); Text("\(value)").font(DesignToken.Font.bodyBold) } } } } } }

    private func card<Content:View>(@ViewBuilder content:()->Content)->some View { content().padding(DesignToken.Spacing.cardPadding).frame(maxWidth:.infinity,alignment:.leading).cardSkin() }
}

private struct AutopsyItemEditor: View {
    let item: ExamAutopsyItem; let onChange: (ExamAutopsyItem)->Void
    @State private var draft: ExamAutopsyItem
    init(item: ExamAutopsyItem,onChange:@escaping(ExamAutopsyItem)->Void){self.item=item;self.onChange=onChange;_draft=State(initialValue:item)}
    var body: some View {
        VStack(alignment: .leading, spacing: DesignToken.Spacing.small) {
            HStack {
                Text("题号 \(draft.questionNumber.isEmpty ? "?" : draft.questionNumber)").font(DesignToken.Font.bodyBold)
                Spacer()
                Text(draft.isConfirmed ? "用户确认" : "AI 推测").font(DesignToken.Font.caption)
                    .foregroundStyle(draft.isConfirmed ? .green : .orange)
            }
            TextField("题目", text: $draft.question, axis: .vertical).font(DesignToken.Font.body)
            if !draft.question.isEmpty { MarkdownPreviewView(text: draft.question).frame(maxHeight: 130) }
            TextField("具体失分行为", text: $draft.behavior, axis: .vertical).font(DesignToken.Font.body)
            Picker("原因", selection: $draft.reason) {
                ForEach(AutopsyLossReason.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            TextField("依据", text: $draft.evidence, axis: .vertical).font(DesignToken.Font.subheadline)
            if !draft.evidence.isEmpty { MarkdownPreviewView(text: draft.evidence).frame(maxHeight: 100) }
            Toggle("确认此题", isOn: $draft.isConfirmed)
        }
        .padding(DesignToken.Spacing.medium)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DesignToken.CornerRadius.medium))
        .onChange(of: draft) { _, value in
            var updated = value
            updated.source = updated.isConfirmed ? .userConfirmed : .aiDraft
            onChange(updated)
        }
    }
}
