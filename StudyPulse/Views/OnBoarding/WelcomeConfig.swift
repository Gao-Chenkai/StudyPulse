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
            appName: "StudyPulse",
            introText: "Track grades, master mistakes, plan exams — and let your body guide when to study with HealthKit insights.".localized(),
            features: [
                FeatureItem(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Tracking & Trends".localized(),
                    description: "Log scores across subjects and watch your progress unfold with interactive trend charts.".localized(),
                    color: .blue
                ),
                FeatureItem(
                    icon: "doc.text.magnifyingglass",
                    title: "Mistake Notes".localized(),
                    description: "Snap photos of errors, auto-extract text with OCR, and review with plain text.".localized(),
                    color: .orange
                ),
                FeatureItem(
                    icon: "heart.text.square",
                    title: "HealthKit Ready".localized(),
                    description: "Connect Apple Health for daily study suggestions tailored to your HRV and recovery state.".localized(),
                    color: .pink
                ),
                FeatureItem(
                    icon: "calendar.badge.clock",
                    title: "Exam Planning".localized(),
                    description: "Schedule exams with countdown, calendar sync, and smart preparation reminders.".localized(),
                    color: .green
                ),
            ],
            iconSymbol: "graduationcap.fill",
            primaryColor: .blue,
            continueButtonText: "Continue".localized(),
            disclaimerText: "All your data stays on device — StudyPulse never uploads grades, mistakes, or health data to external servers.".localized()
        )
    }
    /// 应用的"新功能"页配置 — 每次版本更新后展示
    static var whatsNewInfo: WSWelcomeConfig {
        // ═══════════════════════════════════════════════
        // 每次发布新版本时，在这里更新 features 内容
        // 把本次新增/改进的功能写进来
        // ═══════════════════════════════════════════════
        return WSWelcomeConfig(
            appName: "StudyPulse",
            introText: "Here's what's new in this version.".localized(),
            features: [
                FeatureItem(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Tracking & Trends".localized(),
                    description: "Log scores across subjects and watch your progress unfold with interactive trend charts.".localized(),
                    color: .blue
                ),
                FeatureItem(
                    icon: "doc.text.magnifyingglass",
                    title: "Mistake Notes".localized(),
                    description: "Snap photos of errors, auto-extract text with OCR, and review with plain text.".localized(),
                    color: .orange
                ),
                FeatureItem(
                    icon: "heart.text.square",
                    title: "HealthKit Ready".localized(),
                    description: "Connect Apple Health for daily study suggestions tailored to your HRV and recovery state.".localized(),
                    color: .pink
                ),
                FeatureItem(
                    icon: "calendar.badge.clock",
                    title: "Exam Planning".localized(),
                    description: "Schedule exams with countdown, calendar sync, and smart preparation reminders.".localized(),
                    color: .green
                ),
            ],
            iconSymbol: "graduationcap.fill",
            primaryColor: .blue,
            continueButtonText: "Continue".localized(),
            pageType: .whatsNew
        )
    }
}
