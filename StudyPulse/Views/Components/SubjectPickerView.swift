//
//  SubjectPickerView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import SwiftUI

struct SubjectPickerView: View {
    @Binding var selectedSubject: String
    let subjects: [Subject]
    
    var body: some View {
        Picker("Subject", selection: $selectedSubject) {
            ForEach(subjects.filter { $0.enabled }, id: \.name) { subject in
                Text(subject.name).tag(subject.name)
            }
        }
    }
}
