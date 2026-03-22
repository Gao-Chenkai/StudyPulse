//
//  NewMistakeSheet.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import SwiftUI

struct NewMistakeSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var dataManager: DataManager
    
    @State private var title = ""
    @State private var originalQuestion = ""
    @State private var source = ""
    @State private var errorReason = ""
    @State private var wrongSolution = ""
    @State private var correctSolution = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Basic Info")) {
                    TextField("Title", text: $title)
                    TextField("Source", text: $source)
                }
                
                Section(header: Text("Question Details")) {
                    TextEditor(text: $originalQuestion)
                        .frame(height: 100)
                }
                
                Section(header: Text("Analysis")) {
                    TextEditor(text: $errorReason)
                        .frame(height: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.bottom, 8)
                    
                    TextEditor(text: $wrongSolution)
                        .frame(height: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.bottom, 8)
                    
                    TextEditor(text: $correctSolution)
                        .frame(height: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
            }
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
                        let newMistake = MistakeNote(
                            title: title,
                            originalQuestion: originalQuestion,
                            source: source,
                            date: Date(),
                            errorReason: errorReason,
                            wrongSolution: wrongSolution,
                            correctSolution: correctSolution
                        )
                        
                        dataManager.mistakeSets.append(newMistake)
                        dataManager.saveMistakeSets()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(title.isEmpty || originalQuestion.isEmpty)
                }
            }
        }
    }
}
