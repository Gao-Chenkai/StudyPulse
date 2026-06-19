//
//  WelcomeConfig.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/29.
//

import SwiftUI
import WSOnBoarding

// 扩展 WSOnBoarding 库中的 WSWelcomeConfig
extension WSWelcomeConfig {
    /// 应用的欢迎页配置
    static var welcomeInfo: WSWelcomeConfig {
        return WSWelcomeConfig(
            appName: "StudyPulse", // 显示的应用名称
            introText: nil,
            features: [
                FeatureItem(
                    icon: "list.clipboard",
                    title: "Chart Analysis".localized(),
                    description: "Intuitive visualization of your trends.".localized(),
                    color: .blue
                ),
                FeatureItem(
                    icon: "bolt.fill",
                    title: "Lightning Fast".localized(),
                    description: "Millisecond response with no waiting for results.".localized(),
                    color: .orange
                ),
                FeatureItem(
                    icon: "wifi.slash",
                    title: "Offline Support".localized(),
                    description: "Works fully offline. No internet required.".localized(),
                    color: .green
                ),
            ],
            iconSymbol: "graduationcap.fill",
//            iconName: "StudyPulseIcon", // 应用图标图片文件名称
            backgroundImageName: nil,
            primaryColor: .blue,
            continueButtonText: "Continue".localized(),
            disclaimerText: "Your device information and usage data will not be used to provide a personalized experience, improve app functionality, or prevent fraud. Please review our privacy policy for more information. By tapping Continue, you agree to the User Agreement.".localized()
        )
    }
}
