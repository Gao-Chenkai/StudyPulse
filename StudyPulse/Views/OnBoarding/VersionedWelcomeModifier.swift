//
//  VersionedWelcomeModifier.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/6/21.
//
//  版本感知欢迎页：首次启动 → 欢迎页；版本更新 → 新功能介绍页。
//  每次发布新版本时记得更新 WSWelcomeConfig.whatsNewInfo 里的 features。

import SwiftUI
import WSOnBoarding

// MARK: - 版本号读取

enum AppVersion {
    /// 当前版本号（CFBundleShortVersionString）
    static var current: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? "1.0"
    }
}

// MARK: - ViewModifier

/// 替换 WSOnBoarding 自带的 `.wsWelcomeView()`，自动判断显示欢迎页还是新功能介绍页。
///
/// 决策逻辑：
///   - 从未启动过（lastSeenAppVersion == nil）→ 欢迎页
///   - 版本号变了（lastSeenAppVersion != current）→ 新功能页
///   - 版本号没变 → 什么都不显示
struct VersionedWelcomeModifier: ViewModifier {
    @State private var showWelcome = false
    @State private var showWhatsNew = false

    func body(content: Content) -> some View {
        content
            .task { checkAndShow() }
            .sheet(
                isPresented: $showWelcome,
                onDismiss: markVersionSeen
            ) {
                StandardWelcomeView(config: WSWelcomeConfig.welcomeInfo)
            }
            .fullScreenCover(
                isPresented: $showWhatsNew,
                onDismiss: markVersionSeen
            ) {
                StandardWelcomeView(config: WSWelcomeConfig.whatsNewInfo)
            }
    }

    private func checkAndShow() {
        let currentVersion = AppVersion.current
        let lastSeenVersion = UserDefaults.standard.string(
            forKey: UserDefaultsKey.lastSeenAppVersion
        )

        if lastSeenVersion == nil {
            showWelcome = true
        } else if lastSeenVersion != currentVersion {
            showWhatsNew = true
        }
    }

    private func markVersionSeen() {
        UserDefaults.standard.set(
            AppVersion.current,
            forKey: UserDefaultsKey.lastSeenAppVersion
        )
    }
}

// MARK: - UserDefaults keys

private enum UserDefaultsKey {
    static let lastSeenAppVersion = "lastSeenAppVersion"
}

// MARK: - View extension

extension View {
    /// 版本感知的欢迎 / 新功能介绍页面。
    /// 替代 `.wsWelcomeView(config:style:welcomeKey:)`。
    func versionedWelcomeView() -> some View {
        modifier(VersionedWelcomeModifier())
    }
}
