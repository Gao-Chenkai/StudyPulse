//
//  NewMistakeSetView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

// 4.11: 改不动了 下次再改只能重新手写了

import SwiftUI

// 重构点 1: 将枚举移出 View 结构体，定义为全局枚举
// 这能显著减轻编译器的嵌套类型推导负担，解决 "unable to type-check" 错误
enum EditSection: String, CaseIterable, Identifiable {
    case question = "Question"
    case reason = "Reason"
    case wrong = "Wrong"
    case correct = "Correct"
    
    var id: String { self.rawValue }
    
    // 重构点 2: 使用线性 if-else 直接返回字面量
    // 避免使用 switch 或 字典初始化，这是编译速度最快的方式
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
    @State private var editedOriginalQuestion = ""
    @State private var editedSource = ""
    @State private var editedErrorReason = ""
    @State private var editedWrongSolution = ""
    @State private var editedCorrectSolution = ""
    @State private var editedDate = Date()
    
    @State private var selectedSection: EditSection = .question
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Basic Info")) {
                    HStack {
                        Image(systemName: "rectangle.and.pencil.and.ellipsis")
                            .foregroundColor(.yellow)
                            .frame(width: 30)
                        
                        Text ("Exam Name")
                        
                        TextField("Exam Name", text: $editedTitle)
                            .multilineTextAlignment(.trailing)
                        Spacer()
                    }
                    
                    HStack {
                        Image(systemName: "list.bullet.clipboard")
                            .foregroundColor(.green)
                            .frame(width: 30)
                        
                        Text ("Source")
                        
                        TextField("Source", text: $editedSource)
                            .multilineTextAlignment(.trailing)
                        Spacer()
                    }
                    
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.pink)
                        Text("Date")
                        Spacer()
                        
                        DatePicker("", selection: $editedDate, displayedComponents: .date)
                            .labelsHidden()
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
                
                ScrollView {
                    buildSegmentedControl()
                    
                    buildEditorArea()
                    
                    Spacer(minLength: 40)
                }
        
            }
            
            
            
//            ScrollView {
//                VStack(spacing: 20) {
//                    
//                    // 1. 基础信息卡片
//                    buildBasicInfo()
//                    
//                    List {
//                        Section(header: Text("Basic Info")) {
//                            HStack {
//                                Image(systemName: "person.fill")
//                                    .foregroundColor(.yellow)
//                                    .frame(width: 30)
//                                Text("Username")
//                                    .foregroundColor(.primary)
//                                    .lineLimit(1) // 👈 关键：限制为一行
//                                Spacer()
//                                Text(dataManager.profile.username)
//                            }
//                        }
//                    }
//                    
//                    // 2. 分段控制器 (Segmented Control)
//                    buildSegmentedControl()
//                    
//                    // 3. 编辑器区域
//                    buildEditorArea()
//                    
//                    Spacer(minLength: 40)
//                }
//                .padding(.top, 8)
//            }
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
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    /// 构建基础信息部分
    @ViewBuilder
    private func buildBasicInfo() -> some View {
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
                
                buildInfoRow(icon: "rectangle.and.pencil.and.ellipsis", color: .yellow, label: "Title", text: $editedTitle, leftPadding: leftPadding, labelWidth: labelWidth, iconWidth: iconWidth, iconLabelSpacing: iconLabelSpacing)
                
                Divider().padding(.leading, leftPadding + iconWidth + iconLabelSpacing + labelWidth)
                
                buildInfoRow(icon: "list.bullet.clipboard", color: .green, label: "Source", text: $editedSource, leftPadding: leftPadding, labelWidth: labelWidth, iconWidth: iconWidth, iconLabelSpacing: iconLabelSpacing)
                
                Divider().padding(.leading, leftPadding + iconWidth + iconLabelSpacing + labelWidth)
                
                buildDateRow(leftPadding: leftPadding, labelWidth: labelWidth, iconWidth: iconWidth, iconLabelSpacing: iconLabelSpacing)
            }
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .padding(.horizontal)
    }
    
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
    
    /// 构建顶部切换按钮
    @ViewBuilder
    private func buildSegmentedControl() -> some View {
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
    }
    
    /// 构建编辑器区域
    @ViewBuilder
    private func buildEditorArea() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            
            TextEditor(text: currentBinding)
                .frame(minHeight: 355)
                .font(.body)
                .padding(8)
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(selectedSection.color.opacity(0.5), lineWidth: 2)
                )
                .padding(.horizontal)
        }
    }
    
    // MARK: - Helpers
    
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
            title: editedTitle.isEmpty ? "未命名错题" : editedTitle,
            originalQuestion: editedOriginalQuestion,
            source: editedSource,
            date: editedDate,
            errorReason: editedErrorReason,
            wrongSolution: editedWrongSolution,
            correctSolution: editedCorrectSolution,
            images: []
        )
        dataManager.addMistake(newMistake)
        presentationMode.wrappedValue.dismiss()
    }
}

#Preview {
    NewMistakeSetView()
        .environmentObject(DataManager())
}
