//
//  MistakeDetailEditView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import SwiftUI
import Combine

struct MistakeDetailEditView: View {
    @ObservedObject var dataManager: DataManager
    @Environment(\.presentationMode) var presentationMode
    let mistakeSet: MistakeNote
    
    @State private var editedTitle = ""
    @State private var editedOriginalQuestion = ""
    @State private var editedSource = ""
    @State private var editedErrorReason = ""
    @State private var editedWrongSolution = ""
    @State private var editedCorrectSolution = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Basic Info")) {
                    TextField("Title", text: $editedTitle)
                    TextField("Source", text: $editedSource)
                }
                
                Section(header: Text("Question Details")) {
                    TextEditor(text: $editedOriginalQuestion)
                        .frame(height: 100)
                }
                
                Section(header: Text("Analysis")) {
                    TextEditor(text: $editedErrorReason)
                        .frame(height: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.bottom, 8)
                    
                    TextEditor(text: $editedWrongSolution)
                        .frame(height: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.bottom, 8)
                    
                    TextEditor(text: $editedCorrectSolution)
                        .frame(height: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            .navigationTitle("Edit Mistake")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                editedTitle = mistakeSet.title
                editedOriginalQuestion = mistakeSet.originalQuestion
                editedSource = mistakeSet.source
                editedErrorReason = mistakeSet.errorReason
                editedWrongSolution = mistakeSet.wrongSolution
                editedCorrectSolution = mistakeSet.correctSolution
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        // 在实际应用中，这里会保存编辑的内容
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
