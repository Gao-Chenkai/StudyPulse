//
//  SubjectPickerView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//
//  学科下拉选择器:只显示已启用的学科(Subject.enabled == true)。
//  Subject dropdown picker: only shows enabled subjects (`Subject.enabled == true`).
//

import SwiftUI

/// 学科下拉选择器。
/// Subject dropdown picker.
struct SubjectPickerView: View {
    /// 当前选中的学科名
    /// Currently selected subject name.
    @Binding var selectedSubject: String
    /// 学科列表(只有 enabled 的会显示)
    /// Subject list (only enabled subjects are shown).
    let subjects: [Subject]
    
    var body: some View {
        Picker("Subject".localized(), selection: $selectedSubject) {
            ForEach(subjects.filter { $0.enabled }, id: \.name) { subject in
                Text(subject.name).tag(subject.name)
            }
        }
    }
}
