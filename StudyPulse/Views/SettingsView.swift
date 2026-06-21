//
//  SettingsView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var dataManager: DataManager
    /// 异步加载的头像数据，避免 body 中同步读文件
    @State private var avatarData: Data? = nil

    var body: some View {
        NavigationStack {
            List {
                // Pinned profile row (tap to enter Apple ID style page)
                Section {
                    NavigationLink(destination: ProfileSettingsView()) {
                        profileRow
                    }
                }

                // Settings categories
                Section {
                    ForEach(SettingsCategory.allCases) { category in
                        NavigationLink(destination: category.destination) {
                            SettingsCategoryRow(category: category)
                        }
                    }
                }
            }
        .task {
            avatarData = await dataManager.loadAvatarAsync()
        }
  .listStyle(.insetGrouped)
  .navigationTitle("Settings".localized())
        }
    }

    private var profileRow: some View {
        HStack(spacing: 14) {
            AvatarView(
                username: dataManager.profile.username,
                avatarData: avatarData,
                size: 64
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(dataManager.profile.username)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                Text(profileSubtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 6)
    }

    private var profileSubtitle: String {
        let p = dataManager.profile
        if !p.studentId.isEmpty {
            return "Student ID · \(p.studentId)"
        } else if !p.schoolName.isEmpty {
            return p.schoolName
        } else {
            return "Tap to set up your profile".localized()
        }
    }
}
