//
//  FlashcardCardView.swift
//  StudyPulse
//
//  单张闪卡视图：支持 3D 翻牌动画 + Markdown 渲染
//
//  Created by Chenkai Gao on 2026/6/27.
//

import SwiftUI
import SwiftStreamingMarkdown

// MARK: - Flashcard Card View

/// 单张闪卡：点击或按钮触发翻面
struct FlashcardCardView: View {
    let mistake: MistakeNote
    @Binding var isFlipped: Bool

    var body: some View {
        ZStack {
            // 正面：题目
            FlashcardFaceView(mistake: mistake, side: .front)
                .opacity(isFlipped ? 0 : 1)
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                .accessibilityHidden(isFlipped)

            // 反面：错因 + 正确解法
            FlashcardFaceView(mistake: mistake, side: .back)
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
                .accessibilityHidden(!isFlipped)
        }
        .frame(maxWidth: .infinity, minHeight: 480)
        .background(faceBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.18), radius: 16, x: 0, y: 8)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.purple.opacity(0.25), .blue.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                isFlipped.toggle()
            }
        }
    }

    /// 玻璃风背景（iOS 26 升级为 glassEffect；当前用 regularMaterial 兼容老版本）
    @ViewBuilder
    private var faceBackground: some View {
        if #available(iOS 26.0, *) {
            Color.clear.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.regularMaterial)
        }
    }
}

// MARK: - Card Side

/// 闪卡正反面枚举
enum FlashcardSide {
    case front  // 题目
    case back   // 错因 + 正确解法
}

// MARK: - Flashcard Face

/// 闪卡正反面具体内容
struct FlashcardFaceView: View {
    let mistake: MistakeNote
    let side: FlashcardSide

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 顶部标签
            HStack {
                Label(side == .front ? "Question".localized() : "Answer".localized(),
                      systemImage: side == .front ? "doc.text" : "checkmark.seal.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(side == .front ? Color.blue : Color.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(
                            (side == .front ? Color.blue : Color.green).opacity(0.15)
                        )
                    )

                Spacer()

                if !mistake.subject.isEmpty {
                    Text(mistake.subject.localized())
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.purple.opacity(0.15)))
                        .foregroundStyle(Color.purple)
                }
            }

            Divider()

            // 内容区
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch side {
                    case .front:
                        // 正面：标题 + 题目 + 题目图片
                        if !mistake.title.isEmpty {
                            Text(mistake.title)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.primary)
                        }
                        if !mistake.originalQuestion.isEmpty {
                            MarkdownView(
                                text: mistake.originalQuestion.normalisingSingleDollarMath(),
                                config: .previewConfig
                            )
                            .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text("No question content".localized())
                                .foregroundStyle(.secondary)
                        }
                        if !mistake.questionImages.isEmpty {
                            imageStripView(images: mistake.questionImages)
                        }

                    case .back:
                        // 反面：错因 + 正确解法
                        if !mistake.errorReason.isEmpty {
                            sectionTitle("Error Reason".localized(), icon: "exclamationmark.triangle.fill", color: .orange)
                            MarkdownView(
                                text: mistake.errorReason.normalisingSingleDollarMath(),
                                config: .previewConfig
                            )
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        if !mistake.correctSolution.isEmpty {
                            sectionTitle("Correct Solution".localized(), icon: "checkmark.circle.fill", color: .green)
                            MarkdownView(
                                text: mistake.correctSolution.normalisingSingleDollarMath(),
                                config: .previewConfig
                            )
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        if !mistake.correctSolutionImages.isEmpty {
                            imageStripView(images: mistake.correctSolutionImages)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // 底部提示
            HStack {
                Image(systemName: "hand.tap")
                    .font(.caption2)
                Text("Tap to flip".localized())
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
        }
        .padding(20)
    }

    @ViewBuilder
    private func sectionTitle(_ text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(color)
            Text(text).font(.subheadline.weight(.semibold))
        }
    }

    @ViewBuilder
    private func imageStripView(images: [Data]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(images.indices, id: \.self) { idx in
                    ThumbnailImageView(data: images[idx])
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }
}
