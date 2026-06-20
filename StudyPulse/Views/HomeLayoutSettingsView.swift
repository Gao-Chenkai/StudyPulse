//
//  HomeLayoutSettingsView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/6/20.
//

import SwiftUI

// MARK: - HomeLayoutSettingsView

/// 主页卡片布局设置：拖拽排序 + 开关控制显示/隐藏
struct HomeLayoutSettingsView: View {
    @State private var items: [HomeCardItem] = HomeLayoutPreference.load().items
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 12) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .frame(width: 24)
                        
                        Image(systemName: item.type.icon)
                            .foregroundColor(.accentColor)
                            .frame(width: 28)
                        
                        Text(item.type.displayName)
                            .font(.system(size: 16))
                        
                        Spacer()
                        
                        Toggle("", isOn: binding(for: item))
                            .labelsHidden()
                    }
                    .padding(.vertical, 4)
                }
                .onMove { source, destination in
                    items.move(fromOffsets: source, toOffset: destination)
                    save()
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Home Layout".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button(role: .destructive) {
                        HomeLayoutPreference.resetToDefault()
                        items = HomeLayoutPreference.load().items
                    } label: {
                        Label("Reset to Default".localized(), systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
    
    private func binding(for item: HomeCardItem) -> Binding<Bool> {
        Binding(
            get: {
                items.first(where: { $0.id == item.id })?.enabled ?? true
            },
            set: { newValue in
                if let index = items.firstIndex(where: { $0.id == item.id }) {
                    items[index].enabled = newValue
                    save()
                }
            }
        )
    }
    
    private func save() {
        let pref = HomeLayoutPreference(items: items)
        pref.save()
    }
}

#Preview {
    HomeLayoutSettingsView()
}
