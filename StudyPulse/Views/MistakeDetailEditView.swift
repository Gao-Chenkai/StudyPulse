//
//  MistakeDetailEditView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import SwiftUI
import Combine

struct MistakeDetailEditView: View {
    // 如果父视图通过 .environmentObject 传入，这里也用 @EnvironmentObject
    // 如果父视图是直接传参 init(dataManager: ...)，则保持 @ObservedObject 也可以
    @ObservedObject var dataManager: DataManager
    @Environment(\.presentationMode) var presentationMode
    let mistakeSet: MistakeNote
    
    // 编辑状态变量
    @State private var editedTitle = ""
    @State private var editedOriginalQuestion = ""
    @State private var editedSource = ""
    @State private var editedErrorReason = ""
    @State private var editedWrongSolution = ""
    @State private var editedCorrectSolution = ""
    @State private var editedDate = Date()
    
    // 控制当前显示哪个编辑区域的状态
    @State private var selectedSection: EditSection = .question

    // 定义四个部分的枚举配置
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
            case .question: return "题目"
            case .reason: return "错因"
            case .wrong: return "错解"
            case .correct: return "正解"
            }
        }
        
        var color: Color {
            switch self {
            case .question: return .blue
            case .reason: return .orange
            case .wrong: return .red
            case .correct: return .green
            }
        }
    }

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
                            HStack(spacing: iconLabelSpacing) {
                                Image(systemName: "rectangle.and.pencil.and.ellipsis")
                                    .foregroundColor(.yellow)
                                    .frame(width: iconWidth, alignment: .center)
                                Text("Title")
                                    .frame(width: labelWidth, alignment: .leading)
                                TextField("Title", text: $editedTitle)
                                    .multilineTextAlignment(.trailing)
                            }
                            .padding(leftPadding)
                            
                            Divider()
                                .padding(.leading, leftPadding + iconWidth + iconLabelSpacing + labelWidth)
                            
                            // Source
                            HStack(spacing: iconLabelSpacing) {
                                Image(systemName: "list.bullet.clipboard")
                                    .foregroundColor(.green)
                                    .frame(width: iconWidth, alignment: .center)
                                Text("Source")
                                    .frame(width: labelWidth, alignment: .leading)
                                TextField("Source", text: $editedSource)
                                    .multilineTextAlignment(.trailing)
                            }
                            .padding(leftPadding)
                            
                            Divider()
                                .padding(.leading, leftPadding + iconWidth + iconLabelSpacing + labelWidth)
                            
                            // Date
                            HStack(spacing: iconLabelSpacing) {
                                Image(systemName: "calendar")
                                    .foregroundColor(.pink)
                                    .frame(width: iconWidth, alignment: .center)
                                Text("Date")
                                    .frame(width: labelWidth, alignment: .leading)
                                Spacer()
                                DatePicker(
                                    "",
                                    selection: $editedDate,
                                    displayedComponents: .date
                                )
                                .labelsHidden()
                                .fixedSize(horizontal: true, vertical: false)
                            }
                            .padding(leftPadding)
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

                    // --- 第三部分：下方输入区域 ---
                    VStack(alignment: .leading, spacing: 12) {
                        Group {
                            if selectedSection == .question {
                                TextEditor(text: $editedOriginalQuestion)
                                    .frame(minHeight: 350)
                                    .font(.body)
                                    .padding(8)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedSection == .question ? Color.blue.opacity(0.5) : Color.gray.opacity(0.2), lineWidth: selectedSection == .question ? 2 : 1)
                                    )
                            } else if selectedSection == .reason {
                                TextEditor(text: $editedErrorReason)
                                    .frame(minHeight: 350)
                                    .font(.body)
                                    .padding(8)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedSection == .reason ? Color.orange.opacity(0.5) : Color.gray.opacity(0.2), lineWidth: selectedSection == .reason ? 2 : 1)
                                    )
                            } else if selectedSection == .wrong {
                                TextEditor(text: $editedWrongSolution)
                                    .frame(minHeight: 350)
                                    .font(.body)
                                    .padding(8)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedSection == .wrong ? Color.red.opacity(0.5) : Color.gray.opacity(0.2), lineWidth: selectedSection == .wrong ? 2 : 1)
                                    )
                            } else if selectedSection == .correct {
                                TextEditor(text: $editedCorrectSolution)
                                    .frame(minHeight: 350)
                                    .font(.body)
                                    .padding(8)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedSection == .correct ? Color.green.opacity(0.5) : Color.gray.opacity(0.2), lineWidth: selectedSection == .correct ? 2 : 1)
                                    )
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Edit Mistake")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // 初始化数据
                editedTitle = mistakeSet.title
                editedOriginalQuestion = mistakeSet.originalQuestion
                editedSource = mistakeSet.source
                editedErrorReason = mistakeSet.errorReason
                editedWrongSolution = mistakeSet.wrongSolution
                editedCorrectSolution = mistakeSet.correctSolution
                editedDate = mistakeSet.date
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges() // ✅ 调用保存逻辑
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // 保存逻辑
    private func saveChanges() {
        // 1. 基于原始对象创建一个新的可变副本
        var updatedMistake = mistakeSet
        
        // 2. 将编辑后的值赋给副本
        updatedMistake.title = editedTitle
        updatedMistake.originalQuestion = editedOriginalQuestion
        updatedMistake.source = editedSource
        updatedMistake.errorReason = editedErrorReason
        updatedMistake.wrongSolution = editedWrongSolution
        updatedMistake.correctSolution = editedCorrectSolution
        updatedMistake.date = editedDate
        // 注意：images 数组保持不变，如果需要编辑图片需额外逻辑
        
        // 3. 调用 DataManager 的更新方法
        // 这会自动查找数组中的旧项并替换，同时触发 @Published 刷新 UI 和保存到磁盘
        dataManager.updateMistake(updatedMistake)
        
        // 4. 关闭弹窗
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Preview
#if DEBUG
struct MistakeDetailEditView_Previews: PreviewProvider {
    static var previews: some View {
        let mockDataManager = DataManager()
        
        let mockMistake = MistakeNote(
            title: "微积分错题示例",
            originalQuestion: "求函数 f(x) = x^2 在 x=2 处的导数。",
            source: "2023 期中考试卷",
            date: Date(),
            errorReason: "公式记忆混淆，把幂函数求导记错了。",
            wrongSolution: "f'(x) = x^3 / 3",
            correctSolution: "f'(x) = 2x, 所以 f'(2) = 4",
            images: []
        )
        
        return MistakeDetailEditView(
            dataManager: mockDataManager,
            mistakeSet: mockMistake
        )
    }
}
#endif
