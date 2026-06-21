//
//  SettingsView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var dataManager: DataManager

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
  .listStyle(.insetGrouped)
  .navigationTitle("Settings".localized())
        }
    }

    private var profileRow: some View {
        HStack(spacing: 14) {
            AvatarView(
                username: dataManager.profile.username,
                avatarData: dataManager.loadAvatar(),
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
