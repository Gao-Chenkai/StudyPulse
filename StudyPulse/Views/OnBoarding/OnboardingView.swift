//
//  OnboardingView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/6/27.
//  原生 iOS 26 风格的引导页：渐变背景 + 玻璃质感卡片 + 大圆角，
//  使用 TabView 分页，每页聚焦一个特性。
//

import SwiftUI

/// 原生 iOS 26 风格的引导页视图，替代 WSOnBoarding 的 StandardWelcomeView。
struct OnboardingView: View {
    let config: OnboardingConfig
    /// 用户点击「继续 / 完成」或「跳过」时回调
    let onFinish: () -> Void

    @State private var currentPage = 0

    /// 总页数 = 1（Hero）+ features.count
    private var totalPages: Int { 1 + config.features.count }
    private var isLastPage: Bool { currentPage >= totalPages - 1 }

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                TabView(selection: $currentPage) {
                    heroPage
                        .tag(0)
                    ForEach(Array(config.features.enumerated()), id: \.offset) { index, feature in
                        featurePage(feature, index: index)
                            .tag(index + 1)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.25), value: currentPage)

                bottomBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            // 基础渐变：主色淡化到系统背景色
            LinearGradient(
                colors: [
                    config.primaryColor.opacity(0.18),
                    Color(.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // 装饰性模糊光晕
            Circle()
                .fill(config.primaryColor.opacity(0.35))
                .frame(width: 320, height: 320)
                .blur(radius: 100)
                .offset(x: -180, y: -260)
                .ignoresSafeArea()

            Circle()
                .fill(config.primaryColor.opacity(0.22))
                .frame(width: 280, height: 280)
                .blur(radius: 90)
                .offset(x: 200, y: 360)
                .ignoresSafeArea()
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            pageIndicator
            Spacer()
            if !isLastPage {
                Button("Skip".localized(), action: onFinish)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 32)
    }

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalPages, id: \.self) { i in
                Capsule()
                    .fill(i == currentPage ? config.primaryColor : Color.secondary.opacity(0.3))
                    .frame(width: i == currentPage ? 22 : 6, height: 6)
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: currentPage)
            }
        }
    }

    // MARK: - Hero page

    private var heroPage: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer().frame(height: 24)

                if config.pageType == .whatsNew {
                    whatsNewBadge
                }

                appIcon

                VStack(spacing: 12) {
                    Text(config.appName)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)

                    Text(config.introText)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let disclaimer = config.disclaimerText, !disclaimer.isEmpty {
                    disclaimerCard(disclaimer)
                        .padding(.top, 4)
                }

                Spacer().frame(height: 8)
            }
            .padding(.horizontal, 8)
        }
        .scrollIndicators(.hidden)
    }

    private var appIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            config.primaryColor,
                            config.primaryColor.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
                .shadow(color: config.primaryColor.opacity(0.4), radius: 24, y: 12)

            Image(systemName: config.iconSymbol)
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(.white)
                .symbolRenderingMode(.hierarchical)
        }
    }

    private var whatsNewBadge: some View {
        Text("What's New".localized())
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(config.primaryColor)
            )
    }

    // MARK: - Feature page

    private func featurePage(_ feature: OnboardingConfig.Feature, index: Int) -> some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer().frame(height: 24)

                featureIconBadge(feature)

                VStack(spacing: 14) {
                    Text("\(index + 1) / \(config.features.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(feature.title)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)

                    Text(feature.description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8)
                }

                Spacer().frame(height: 8)
            }
            .padding(.horizontal, 8)
        }
        .scrollIndicators(.hidden)
    }

    private func featureIconBadge(_ feature: OnboardingConfig.Feature) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 48, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            feature.color.opacity(0.28),
                            feature.color.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 200, height: 200)
                .overlay(
                    RoundedRectangle(cornerRadius: 48, style: .continuous)
                        .strokeBorder(feature.color.opacity(0.2), lineWidth: 1)
                )

            Image(systemName: feature.icon)
                .font(.system(size: 96, weight: .medium))
                .foregroundStyle(feature.color.gradient)
                .symbolRenderingMode(.hierarchical)
        }
    }

    // MARK: - Disclaimer

    private func disclaimerCard(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.title3)
                .foregroundStyle(config.primaryColor)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(glassSurface(cornerRadius: 16))
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        Button(action: handlePrimaryTap) {
            HStack(spacing: 8) {
                Text(primaryButtonTitle)
                    .font(.headline)
                if !isLastPage {
                    Image(systemName: "arrow.right")
                        .font(.subheadline.weight(.bold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                config.primaryColor,
                                config.primaryColor.opacity(0.85)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: config.primaryColor.opacity(0.35), radius: 14, y: 8)
            )
        }
        .buttonStyle(.plain)
    }

    private var primaryButtonTitle: String {
        isLastPage ? config.continueButtonText : "Next".localized()
    }

    private func handlePrimaryTap() {
        if isLastPage {
            onFinish()
        } else {
            withAnimation(.easeInOut(duration: 0.25)) {
                currentPage += 1
            }
        }
    }

    // MARK: - Glass surface helper

    /// iOS 26+ 使用 Liquid Glass 效果；旧版本回退到 .regularMaterial。
    @ViewBuilder
    private func glassSurface(cornerRadius: CGFloat) -> some View {
        if #available(iOS 26, *) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.clear)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.regularMaterial)
        }
    }
}

#Preview("Welcome") {
    OnboardingView(config: .welcome) {}
}

#Preview("What's New") {
    OnboardingView(config: .whatsNew) {}
}
