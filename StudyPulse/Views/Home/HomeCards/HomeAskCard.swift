//
//  HomeAskCard.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/7/11.
//
//  主页 AI 提问入口卡。
//  - display-only 输入框样式,提示文本随上下文切换
//    ("未配置" / "问点什么..." / 一些推荐问题)
//  - 点击整个卡片或输入框 → 弹出 HomeAskSheet
//  - 不参与长按分享(不能导出"输入框"图片)
//

import SwiftUI

struct HomeAskCard: View {
    @Environment(RepositoryContainer.self) private var container
    @EnvironmentObject var envManager: AppEnvironmentManager
    @State private var showSheet: Bool = false

    var body: some View {
        Button {
            showSheet = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [.teal, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 36, height: 36)
                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Ask AI".localized())
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                        if envManager.llmConfig.isConfigured {
                            HStack(spacing: 2) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 9, weight: .bold))
                                Text("AI".localized())
                                    .font(.caption2.weight(.bold))
                            }
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Capsule().fill(Color.teal.opacity(0.18)))
                            .foregroundColor(.teal)
                        }
                    }
                    Text(placeholder)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        envManager.llmConfig.isConfigured
                            ? Color.teal.opacity(0.25)
                            : Color.secondary.opacity(0.15),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSheet) {
            HomeAskSheet(container: container, envManager: envManager)
                .environmentObject(envManager)
        }
    }

    private var placeholder: String {
        if !envManager.llmConfig.isConfigured {
            return "未配置 AI · 前往设置".localized()
        }
        return "Ask anything...".localized()
    }
}
