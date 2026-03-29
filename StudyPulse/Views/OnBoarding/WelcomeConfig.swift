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
                    title: "图表分析",
                    description: "以直观的形式了解趋势。",
                    color: .blue
                ),
                FeatureItem(
                    icon: "bolt.fill",
                    title: "毫秒级响应",
                    description: "超快速分析，无需等待即可获得结果。",
                    color: .orange
                ),
                FeatureItem(
                    icon: "wifi.slash",
                    title: "离线支持",
                    description: "无需联网，在本地设备上完成所有处理。",
                    color: .green
                ),
            ],
            iconSymbol: "graduationcap.fill",
//            iconName: "StudyPulseIcon", // 应用图标图片文件名称
            backgroundImageName: nil,
            primaryColor: .blue,
            continueButtonText: "继续",
            disclaimerText:
                "你的设备信息和使用数据将不会用于提供个性化体验、改进应用功能和防止欺诈。查看详细隐私政策了解更多信息。点击“继续”即代表同意用户协议。"
        )
    }
}
