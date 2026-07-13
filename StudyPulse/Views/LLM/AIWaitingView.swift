//
//  AIWaitingView.swift
//  StudyPulse
//
//  Created by Antigravity on 2026/7/13.
//  Copyright © 2026 Chenkai Gao. All rights reserved.
//

import SwiftUI
import Combine

/// 一个用于大模型加载等待的高级、精致的视图。
/// 包含活泼色彩在页面上流动（浮动模糊圆球）的背景、玻璃拟态卡片以及多状态提示文本的自动轮回切换。
///
/// A premium loading/waiting view for LLM operations.
/// Features a dynamic background with flowing vibrant color blobs, a glassmorphic card,
/// and automated cycling of localized waiting status messages.
struct AIWaitingView: View {
    /// 加载状态标题（如：“AI 正在构思变式题...”）
    /// Loading title.
    let title: String

    /// 可选的取消操作回调
    /// Optional cancellation callback.
    var onCancel: (() -> Void)? = nil

    /// 轮回切换的状态语句列表
    /// List of status messages to cycle through.
    let messages: [String]

    // MARK: - State Properties
    
    /// 当前显示的提示语句索引
    /// Index of the currently displayed status message.
    @State private var currentTextIndex = 0
    
    /// 动画计时器是否处于激活状态
    /// Whether the text-switching timer is active.
    @State private var timerActive = true

    // 背景圆球位移与缩放状态（用于流动效果）
    // Floating blob positions and scale factors (for the fluid flow effect)
    @State private var blobOffset1: CGSize = .init(width: -100, height: -120)
    @State private var blobOffset2: CGSize = .init(width: 100, height: 100)
    @State private var blobOffset3: CGSize = .init(width: -60, height: 120)
    @State private var blobOffset4: CGSize = .init(width: 80, height: -80)

    @State private var blobScale1: CGFloat = 1.0
    @State private var blobScale2: CGFloat = 1.1
    @State private var blobScale3: CGFloat = 0.9
    @State private var blobScale4: CGFloat = 1.15

    // 中心星光缩放与旋转角度
    // Center glow scale and rotation angles
    @State private var sparkleScale: CGFloat = 0.95
    @State private var sparkleRotation: Double = 0

    /// 每 2.5 秒触发一次状态文本切换
    /// Timer firing every 2.5 seconds to cycle the status text.
    private let timer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()

    // MARK: - Initializer
    
    init(title: String, messages: [String], onCancel: (() -> Void)? = nil) {
        self.title = title
        self.messages = messages.isEmpty ? [
            "AI正在结合历史数据...".localized(),
            "AI正在提炼表达...".localized(),
            "AI正在构建逻辑模型...".localized(),
            "AI正在为您生成专属内容...".localized()
        ] : messages
        self.onCancel = onCancel
    }

    // MARK: - Body
    
    var body: some View {
        ZStack {
            // 1. 流动炫彩背景 (Flowing animated background of vibrant colors)
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                // 圆球 1：紫罗兰色
                Circle()
                    .fill(Color.purple.opacity(0.25))
                    .frame(width: 320, height: 320)
                    .blur(radius: 65)
                    .offset(blobOffset1)
                    .scaleEffect(blobScale1)

                // 圆球 2：青蓝色
                Circle()
                    .fill(Color.cyan.opacity(0.25))
                    .frame(width: 280, height: 280)
                    .blur(radius: 55)
                    .offset(blobOffset2)
                    .scaleEffect(blobScale2)

                // 圆球 3：蔷薇粉色
                Circle()
                    .fill(Color.pink.opacity(0.22))
                    .frame(width: 300, height: 300)
                    .blur(radius: 65)
                    .offset(blobOffset3)
                    .scaleEffect(blobScale3)

                // 圆球 4：靛蓝色
                Circle()
                    .fill(Color.indigo.opacity(0.25))
                    .frame(width: 260, height: 260)
                    .blur(radius: 55)
                    .offset(blobOffset4)
                    .scaleEffect(blobScale4)
            }
            .ignoresSafeArea()
            .onAppear {
                startFlowAnimation()
            }

            // 2. 居中的毛玻璃卡片 (Glassmorphic center card)
            VStack(spacing: 24) {
                // 炫光加载光环与旋转星芒
                // Rotating and pulsing sparkles indicator
                ZStack {
                    // 外圈动态光环 1 (Outer pulse ring 1)
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.cyan, .purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                        .frame(width: 80, height: 80)
                        .scaleEffect(sparkleScale + 0.15)
                        .opacity(1.8 - (sparkleScale + 0.15))

                    // 外圈动态光环 2 (Outer pulse ring 2)
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.pink, .purple, .indigo],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                        .frame(width: 100, height: 100)
                        .scaleEffect(sparkleScale + 0.3)
                        .opacity(1.8 - (sparkleScale + 0.3))

                    // 中心半透明模糊底垫 (Blurred background disk)
                    Circle()
                        .fill(.thinMaterial)
                        .frame(width: 68, height: 68)
                        .shadow(color: .purple.opacity(0.12), radius: 8)

                    // 旋转的 AI 星芒图标 (Rotating system sparkles icon)
                    Image(systemName: "sparkles")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan, .purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .rotationEffect(.degrees(sparkleRotation))
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                        sparkleScale = 1.15
                    }
                    withAnimation(.linear(duration: 9.0).repeatForever(autoreverses: false)) {
                        sparkleRotation = 360
                    }
                }

                // 标题与轮回切换的文字
                // Title and cycling text labels
                VStack(spacing: 12) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    if !messages.isEmpty {
                        Text(messages[currentTextIndex])
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                            .id(currentTextIndex)
                    }
                }
                .frame(height: 72) // 固定高度防止文案长短不一时布局发生抖动 (Fixed height to prevent shifting)
                
                // 取消按钮
                // Cancel button
                if let onCancel {
                    Button(action: onCancel) {
                        Text("Cancel".localized())
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color(.secondarySystemBackground))
                            )
                    }
                    .transition(.opacity)
                }
            }
            .padding(.vertical, 36)
            .padding(.horizontal, 28)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.35), .white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(color: Color.black.opacity(0.06), radius: 15, x: 0, y: 8)
            .padding(.horizontal, 36)
        }
        .onReceive(timer) { _ in
            guard timerActive && !messages.isEmpty else { return }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) {
                currentTextIndex = (currentTextIndex + 1) % messages.count
            }
        }
        .onDisappear {
            timerActive = false
        }
    }

    // MARK: - Helper Methods
    
    /// 触发背景圆球的无限缓动漂移
    /// Starts infinite floating animation of background colorful blobs.
    private func startFlowAnimation() {
        let duration: Double = 8.5
        
        withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
            blobOffset1 = CGSize(width: 70, height: -60)
            blobScale1 = 1.15
        }
        withAnimation(.easeInOut(duration: duration - 1.2).repeatForever(autoreverses: true)) {
            blobOffset2 = CGSize(width: -50, height: -100)
            blobScale2 = 0.95
        }
        withAnimation(.easeInOut(duration: duration + 0.8).repeatForever(autoreverses: true)) {
            blobOffset3 = CGSize(width: 80, height: 50)
            blobScale3 = 1.2
        }
        withAnimation(.easeInOut(duration: duration - 0.6).repeatForever(autoreverses: true)) {
            blobOffset4 = CGSize(width: -80, height: 70)
            blobScale4 = 1.05
        }
    }
}

#Preview {
    AIWaitingView(
        title: "AI 正在构思变式题...",
        messages: [
            "AI正在结合历史数据...",
            "AI正在提炼表达...",
            "正在为您量身定制变式训练..."
        ],
        onCancel: {}
    )
}
