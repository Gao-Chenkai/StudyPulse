//
//  MistakeView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//


import SwiftUI
import Combine

struct MistakeView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingNewMistakeSet = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(dataManager.mistakeSets) { mistakeSet in
                    NavigationLink(destination: MistakeSetDetailView(mistakeSet: mistakeSet)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(mistakeSet.title)
                                .font(.headline)
                            
                            Text(mistakeSet.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteMistakeSets)
            }
            .navigationTitle("Mistakes")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        showingNewMistakeSet = true
                    }
                }
            }
            .sheet(isPresented: $showingNewMistakeSet) {
                NewMistakeSetView()
            }
        }
    }
    
    private func deleteMistakeSets(offsets: IndexSet) {
        dataManager.mistakeSets.remove(atOffsets: offsets)
        dataManager.saveMistakeSets()
    }
}

struct MistakeSetDetailView: View {
    let mistakeSet: MistakeNote
    @EnvironmentObject var dataManager: DataManager
    @State private var showingNewMistake = false
    
    var body: some View {
        List {
            Section(header: Text("Details")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(mistakeSet.originalQuestion)
                        .font(.body)
                    
                    Text("Source: \(mistakeSet.source)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("Analysis")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("**Error Reason:**")
                    Text(mistakeSet.errorReason)
                    
                    Text("**Wrong Solution:**")
                    Text(mistakeSet.wrongSolution)
                    
                    Text("**Correct Solution:**")
                    Text(mistakeSet.correctSolution)
                }
            }
        }
        .navigationTitle(mistakeSet.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showingNewMistake = true
                }
            }
        }
        .sheet(item: Binding(
            get: { mistakeSet },
            set: { _ in }
        )) { _ in
            MistakeDetailEditView(dataManager: dataManager, mistakeSet: mistakeSet)
                    }
        }
    }

