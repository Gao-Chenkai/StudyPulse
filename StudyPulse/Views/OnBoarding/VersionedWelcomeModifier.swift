//
//  VersionedWelcomeModifier.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/6/21.
//  替换原 WSOnBoarding 自带的 `.wsWelcomeView()`：
//  - 首次启动 → 欢迎页（含产品介绍 + 基础信息填写）
//  - 版本更新 → 新功能介绍页（仅产品介绍，不要求填资料）
//  使用原生 iOS 26 风格的 OnboardingView。
//
//  每次发布新版本时记得更新 OnboardingConfig.whatsNew 里的 features。
//

import SwiftUI

// MARK: - 版本号读取

enum AppVersion {
    /// 当前版本号（CFBundleShortVersionString）
    static var current: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? "1.0"
    }
}

// MARK: - ViewModifier

/// 版本感知的欢迎 / 新功能介绍页面。
struct VersionedWelcomeModifier: ViewModifier {
    @State private var showWelcome = false
    @State private var showWhatsNew = false

    /// 首次启动 welcome 流程结束（用户完成基础信息填写）时回调，
    /// 父级负责把数据写入 DataManager。
    var onProfileCommit: ((OnboardingProfileDraft, [String]) -> Void)?

    func body(content: Content) -> some View {
        content
            .task { checkAndShow() }
            .sheet(
                isPresented: $showWelcome,
                onDismiss: markVersionSeen
            ) {
                OnboardingView(
                    config: .welcome,
                    onFinish: {
                        showWelcome = false
                    },
                    onProfileComplete: { draft, subjects in
                        onProfileCommit?(draft, subjects)
                    }
                )
                .interactiveDismissDisabled()
                .presentationDetents([.large])
                .presentationBackground(.clear)
                .presentationDragIndicator(.hidden)
            }
            .sheet(
                isPresented: $showWhatsNew,
                onDismiss: markVersionSeen
            ) {
                OnboardingView(
                    config: .whatsNew,
                    onFinish: {
                        showWhatsNew = false
                    }
                )
                .presentationDetents([.large])
                .presentationBackground(.clear)
                .presentationDragIndicator(.hidden)
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
    func versionedWelcomeView() -> some View {
        modifier(VersionedWelcomeModifier())
    }

    /// 版本感知的欢迎 / 新功能介绍页面，支持自定义首次启动的 profile 提交回调。
    /// - Parameter onProfileCommit: 用户在首次启动完成基础信息填写时回调，父级负责把数据写入 DataManager。
    func versionedWelcomeView(
        onProfileCommit: @escaping (OnboardingProfileDraft, [String]) -> Void
    ) -> some View {
        modifier(VersionedWelcomeModifier(onProfileCommit: onProfileCommit))
    }
}
