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
    @State private var showingEditSheet = false // ✅ 1. 使用布尔值控制显示
    
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
                    showingEditSheet = true // ✅ 2. 切换布尔值触发 Sheet
                }
            }
        }
        // ✅ 3. 改用 isPresented 绑定布尔值，逻辑更简单可靠
        .sheet(isPresented: $showingEditSheet) {
            // 假设你的编辑视图叫 MistakeDetailEditView
            // 请确保这个视图已经存在，并且初始化参数正确
            MistakeDetailEditView(dataManager: dataManager, mistakeSet: mistakeSet)
        }
    } // ✅ 4. 补全了缺失的闭合大括号
}

#Preview {
    MistakeView()
        .environmentObject(DataManager())
}
