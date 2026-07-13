//
//  HomeLayoutSettingsView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/6/20.
//

import SwiftUI

// MARK: - HomeLayoutSettingsView
// MARK: - 主页布局设置视图

/// 主页卡片布局设置：拖拽排序 + 开关控制显示/隐藏
/// Home card layout settings: drag to reorder + toggle to show/hide.
struct HomeLayoutSettingsView: View {
    /// 当前编辑中的布局条目(可拖拽、可切换 enabled)。
    /// In-progress layout items being edited (draggable, toggleable `enabled`).
    @State private var items: [HomeCardItem] = HomeLayoutPreference.load().items
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
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
                } header: {
                    Text("Home Cards".localized())
                } footer: {
                    Text("homeLayout.footer".localized())
                }
            }
            .listStyle(.insetGrouped)
            .environment(\.editMode, .constant(.active))
            .containerBackground(.clear, for: .navigation)
            .debugModeContainer()
            .debugLayoutBoundsAuto()
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
    
    /// 给定一个 `HomeCardItem`,返回一个安全的 `Binding<Bool>` 用于开关控件;
    /// 设置后立即写回 `HomeLayoutPreference`。
    /// For a given `HomeCardItem`, returns a safe `Binding<Bool>` for the toggle control; immediately writes back to `HomeLayoutPreference` on change.
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

    /// 把当前 `items` 持久化到 `HomeLayoutPreference`(UserDefaults)。
    /// Persist the current `items` to `HomeLayoutPreference` (UserDefaults).
    private func save() {
        let pref = HomeLayoutPreference(items: items)
        pref.save()
    }
}

#Preview {
    HomeLayoutSettingsView()
}
