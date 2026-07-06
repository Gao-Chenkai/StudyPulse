//
//  WelcomeHeaderCard.swift
//  StudyPulse
//
//  主页顶部欢迎区:问候语 + "Ready to study!" 大标题 + 当前日期 + 头像按钮。
// 点击头像跳到 Profile tab(selectedTab = 4)。
//
//  Extracted from HomeView.swift during card-extraction refactor (2026-07-05).
//

import SwiftUI

/// 主页顶部欢迎区域。
/// 接收一个 `selectedTab` 绑定,因为点击头像需要切换到 Profile tab。
struct WelcomeHeaderCard: View {
    @Binding var selectedTab: Int
    @Environment(\.colorScheme) var colorScheme
    @Environment(RepositoryContainer.self) private var container
    /// 异步加载的头像数据,避免 body 中同步读文件
    @State private var avatarData: Data? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(greetingText())
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)

                Text("Ready to study!".localized())
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text(currentDateText())
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                selectedTab = 4
            } label: {
                AvatarView(
                    username: container.profileRepo.profile.username,
                    avatarData: avatarData,
                    size: 50,
                    showBorder: true
                )
            }
            .buttonStyle(.plain)
        }
        .task {
            avatarData = await container.loadAvatarAsync()
        }
        .debugLayoutBoundsAuto()
    }

    private func greetingText() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "Good Morning".localized()
        } else if hour < 18 {
            return "Good Afternoon".localized()
        } else {
            return "Good Evening".localized()
        }
    }

    private func currentDateText() -> String {
        DateFormatters.fullDate.string(from: Date())
    }
}
