//
//  AddGradeView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//
 
import SwiftUI
import os

struct AddGradeView: View {
    @Environment(RepositoryContainer.self) private var container
    @Environment(\.presentationMode) var presentationMode
    
    @StateObject private var viewModel: AddGradeViewModel
    @StateObject private var subjectInfo = SubjectInfo()

    /// Default initializer.
    init(container: RepositoryContainer) {
        self._viewModel = StateObject(wrappedValue: AddGradeViewModel(container: container))
    }

    /// Convenience init that seeds the form with Siri-provided values.
    init(container: RepositoryContainer, presetSubject: String, presetScore: Double, presetExamName: String? = nil) {
        let vm = AddGradeViewModel(container: container)
        vm.seedPreset(presetSubject: presetSubject, presetScore: presetScore, presetExamName: presetExamName)
        self._viewModel = StateObject(wrappedValue: vm)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                examDetailsSection
                
                if !viewModel.subjectScores.isEmpty {
                    scoreInputSections
                }
                
                importanceSection
            }
            .adaptiveForm()
            .navigationTitle("Add New Grade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .onAppear { viewModel.syncSubjectScores() }
            .containerBackground(.clear, for: .navigation)
            .debugModeContainer()
            .debugLayoutBoundsAuto()
        }
    }
}

// MARK: - 子界面拆分（UI 逻辑剥离）
private extension AddGradeView {
    
    // 1. 考试信息区域
    var examDetailsSection: some View {
        Section(header: Text("Exam Details".localized())) {
            HStack {
                Text("Exam Name".localized())
                TextField("Name".localized(), text: $viewModel.examName)
                    .multilineTextAlignment(.trailing)
            }

            DatePicker("Exam Date".localized(), selection: $viewModel.selectedDate, in: ...Date(), displayedComponents: .date)

            examTypePicker
        }
    }
    
    // 2. 考试类型选择器
    var examTypePicker: some View {
        VStack(spacing: 8) {
            Picker("Exam Type".localized(), selection: $viewModel.isComprehensiveExam) {
                Text("Single Subject".localized()).tag(false)
                Text("Comprehensive Exam".localized()).tag(true)
            }
            .pickerStyle(.segmented)
            
            if !viewModel.isComprehensiveExam {
                singleSubjectPicker
            } else {
                multipleSubjectList
            }
        }
    }
    
    // 3. 单选科目
    var singleSubjectPicker: some View {
        Picker("Select Subject".localized(), selection: $viewModel.selectedSingleSubject) {
            ForEach(viewModel.availableSubjects, id: \.self) { name in
                Text(viewModel.displayName(forSubject: name)).tag(name)
            }
        }
        .padding(.top, 10)
        .padding(2)
        .onChange(of: viewModel.selectedSingleSubject) { viewModel.syncSubjectScores() }
    }
    
    // 4. 多选科目
    var multipleSubjectList: some View {
        List {
            Text("Select Multiple Subjects".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ForEach(viewModel.availableSubjects, id: \.self) { subject in
                HStack {
                    Text(viewModel.displayName(forSubject: subject))
                    Spacer()
                    if viewModel.selectedMultipleSubjects.contains(subject) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { viewModel.toggleSubject(subject) }
            }
        }
        .frame(height: viewModel.dynamicListHeight)
        .listStyle(.plain)
    }
    
    // 5. 所有科目分数录入区域
    var scoreInputSections: some View {
        ForEach($viewModel.subjectScores) { $subject in
            Section(header: Text("Score \(subject.subject.localized())".localized())) {
                let maxScore = viewModel.fullScore(for: subject.subject)
                
                ScoreControlView(
                    title: "Score".localized(),
                    value: $subject.score,
                    max: Int(maxScore),
                    color: scoreColor(subject.score, fullScore: maxScore)
                )
                
                Toggle("Use Raw Score".localized(), isOn: $subject.useRawScore)
                
                if subject.useRawScore {
                    ScoreControlView(
                        title: "Raw Score".localized(),
                        value: $subject.rawScore,
                        max: Int(maxScore),
                        color: scoreColor(subject.rawScore, fullScore: maxScore)
                    )
                }
                
                Toggle("Use Ranking".localized(), isOn: $subject.useRanking)
                
                if subject.useRanking {
                    RankingControlView(ranking: $subject.ranking)
                }
            }
        }
    }
    
    // 6. 重要性
    var importanceSection: some View {
        Section(header: Text("Importance".localized())) {
            VStack(alignment: .leading) {
                HStack {
                    Text("Importance".localized())
                    Spacer()
                    Text(String(format: "%d / 5".localized(), viewModel.importance)).foregroundColor(.secondary)
                }
                HStack {
                    ForEach(1...5, id: \.self) { index in
                        Image(systemName: index <= viewModel.importance ? "star.fill" : "star")
                            .foregroundColor(index <= viewModel.importance ? .yellow : .gray)
                            .font(.title3)
                            .onTapGesture { viewModel.importance = index }
                    }
                }
            }
        }
    }
    
    // 工具栏
    var toolbar: some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { presentationMode.wrappedValue.dismiss() }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    viewModel.saveGrades()
                    presentationMode.wrappedValue.dismiss()
                }
                .fontWeight(.semibold)
                .disabled(viewModel.examName.isEmpty || viewModel.subjectScores.isEmpty)
            }
        }
    }
}



// MARK: - 抽离公共控件（彻底解耦）
struct ScoreControlView: View {
    let title: String
    @Binding var value: Double
    let max: Int
    let color: Color
    
    var body: some View {
        VStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 20) {
                Button { decrease() } label: {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(value <= 0 ? .gray : .blue)
                }
                .buttonStyle(.plain)
                
                Text(String(format: "%.1f", value))
                    .contentTransition(.numericText(value: value))
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
                
                Button { increase() } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(value >= Double(max) ? .gray : .blue)
                }
                .buttonStyle(.plain)
            }
            
            Slider(value: $value, in: 0...Double(max), step: 0.5)
                .tint(color)
        }
    }
    
    private func increase() {
        withAnimation {
            if value < Double(max) {
                value += value == Double(max) - 0.5 ? 0.5 : 1
            }
        }
    }
    
    private func decrease() {
        withAnimation {
            if value > 0 {
                value -= value == 0.5 ? 0.5 : 1
            }
        }
    }
}

// 排名控件
struct RankingControlView: View {
    @Binding var ranking: Int?
    
    var body: some View {
        VStack {
            Text("Ranking".localized())
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                //
                Button {
                    withAnimation {
                        if ranking ?? 1 <= 1 {
                            Log.view.debug("排名已是最小值 1 / Ranking already at minimum 1")
                        } else {
                            ranking = (ranking ?? 1) - 1
                            Log.view.debug("排名递减 / Ranking decremented to \(ranking ?? 0, privacy: .public)")
                        }
                    }
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor((ranking ?? 1) <= 1 ? .gray : .blue)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                
                // 排名输入框（居中 + 动画）
                TextField("", value: $ranking, format: .number)
                    .contentTransition(.numericText()) // 👈 数字动画！
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .keyboardType(.numberPad)
                
                // 👈 加号按钮（逻辑直接写在UI里）
                Button {
                    withAnimation {
                        ranking = (ranking ?? 0) + 1
                    }
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
        }
    }
}

#Preview {
    let container = RepositoryContainer()
    return AddGradeView(container: container).environment(container)
}
