//
//  PredictionDiscussionEntry.swift
//  StudyPulse
//
//  Created for the Exam "预测" button feature.
//  Exam "Predict" button feature — LLM-based discussion entry view.
//

import SwiftUI
import SwiftStreamingMarkdown
import os

/// AI 讨论上下文(单科 / 综合)
/// AI discussion context (single-subject or comprehensive).
enum AIContext {
    case singleSubject(exam: Exam, history: [Grade], defaultResult: ScorePredictionResult, fullScore: Double, subjectMistakes: [MistakeNote])
    case comprehensive(target: ComprehensivePredictionTarget)
}

/// 预测页底部 AI 讨论入口(状态机:未配置 / 已加载 / 加载中 / 错误 / 未触发)
/// AI discussion entry at the bottom of the prediction page
/// (state machine: unconfigured / loaded / loading / error / idle).
struct PredictionDiscussionEntryView: View {
    let context: AIContext

    @Environment(RepositoryContainer.self) private var container

    /// `Date` → `yyyy-MM-dd` 字符串(给 LLM 用)
    /// `Date` → `yyyy-MM-dd` string (for LLM).
    static func isoDateString(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    @State private var aiPredictionText: String? = nil
    @State private var aiPredictionLoading: Bool = false
    @State private var aiPredictionError: String? = nil
    @State private var aiPredictionTask: Task<Void, Never>? = nil

    @State private var showDiscussion: Bool = false
    @State private var discussionContext: String = ""
    @State private var discussionInitial: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundColor(.teal)
                Text(titleText)
                    .font(.subheadline.weight(.semibold))
                if aiPredictionLoading {
                    ProgressView().scaleEffect(0.7).padding(.leading, 2)
                }
                Spacer()
                if container.envManager.llmConfig.isConfigured {
                    Text("BYOK".localized())
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.teal.opacity(0.15)))
                        .foregroundColor(.teal)
                }
            }

            // 状态 1: 未配置 LLM
            // State 1: LLM not configured.
            if !container.envManager.llmConfig.isConfigured {
                VStack(alignment: .leading, spacing: 6) {
                    Text("未配置 LLM,无法使用 AI 预测".localized())
                        .font(.caption)
                        .foregroundColor(.secondary)
                    NavigationLink(destination: LLMSettingsView()) {
                        Label("去配置".localized(), systemImage: "gearshape")
                            .font(.caption.weight(.medium))
                    }
                }
            }
            // 状态 2: 已配置且已有结果 → 渲染 Markdown
            // State 2: configured + result available → render Markdown.
            else if let text = aiPredictionText {
                MarkdownView(
                    text: text.normalisingSingleDollarMath(),
                    config: .previewConfig
                )
                .textSelection(.enabled)
                HStack(spacing: 10) {
                    Button {
                        presentDiscussion(lastPrediction: text)
                    } label: {
                        Label("深入探讨".localized(), systemImage: "bubble.left.and.bubble.right.fill")
                            .font(.caption2)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .tint(.teal)
                    Spacer()
                    Button {
                        aiPredictionText = nil
                        aiPredictionError = nil
                    } label: {
                        Label("重测".localized(), systemImage: "arrow.clockwise")
                            .font(.caption2)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }
            // 状态 3: 已配置,正在加载 → 显示流式累积
            // State 3: configured + loading → show streaming accumulator.
            else if aiPredictionLoading {
                Text(aiPredictionText ?? "Waiting...".localized())
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            // 状态 4: 已配置,出错
            // State 4: configured + errored.
            else if let err = aiPredictionError {
                VStack(alignment: .leading, spacing: 4) {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.orange)
                    Button("重试".localized()) {
                        startAIPrediction()
                    }
                    .font(.caption)
                }
            }
            // 状态 5: 已配置,未触发 → 显示"开始预测"按钮
            // State 5: configured + idle → show "Start prediction" button.
            else {
                Text(placeholderText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button {
                    startAIPrediction()
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("让大模型预测".localized())
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.teal.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.teal.opacity(0.25), lineWidth: 1)
        )
        .onDisappear {
            aiPredictionTask?.cancel()
            aiPredictionTask = nil
        }
        .sheet(isPresented: $showDiscussion) {
            AIDiscussionSheet(
                title: sheetTitle,
                context: discussionContext,
                initialAssistantMessage: discussionInitial,
                onDismiss: { showDiscussion = false }
            )
            .adaptiveSheet(detents: [.large])
        }
    }

    private var titleText: String {
        switch context {
        case .singleSubject:
            return "AI 预测".localized()
        case .comprehensive:
            return "AI 总分预测".localized()
        }
    }

    private var placeholderText: String {
        switch context {
        case .singleSubject:
            return "让大模型基于历史成绩、错题状态和默认预测,给出第二意见。".localized()
        case .comprehensive:
            return "让大模型基于各科默认预测,给出总分第二意见。".localized()
        }
    }

    private var sheetTitle: String {
        switch context {
        case .singleSubject:
            return "AI 预测 · 深入探讨".localized()
        case .comprehensive:
            return "AI 总分预测 · 深入探讨".localized()
        }
    }

    private func startAIPrediction() {
        aiPredictionTask?.cancel()
        aiPredictionText = ""
        aiPredictionError = nil
        aiPredictionLoading = true

        let config = container.envManager.llmConfig
        let prompt: LLMPrompt

        switch context {
        case .singleSubject(let exam, let history, let defaultResult, let fullScore, let subjectMistakes):
            let mistakeContext = MistakeContext.build(from: subjectMistakes)
            prompt = ScorePredictionLLM.makePrompt(
                exam: exam,
                history: history,
                defaultResult: defaultResult,
                fullScore: fullScore,
                mistakeContext: mistakeContext
            )
        case .comprehensive(let target):
            prompt = ComprehensiveScorePredictionLLM.makePrompt(
                exam: target.exam,
                target: target
            )
        }

        aiPredictionTask = Task {
            do {
                _ = try await LLMClient.shared.stream(
                    prompt: prompt,
                    config: config,
                    caller: "ScorePrediction"
                ) { snapshot in
                    aiPredictionText = snapshot
                }
            } catch is CancellationError {
                // ignore
            } catch {
                let desc = (error as? LLMError)?.errorDescription ?? error.localizedDescription
                aiPredictionError = desc
            }
            aiPredictionLoading = false
        }
    }

    private func presentDiscussion(lastPrediction: String) {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"

        switch context {
        case .singleSubject(let exam, let history, let defaultResult, let fullScore, let subjectMistakes):
            let recent = history.suffix(5)
                .map { g in
                    let full = g.fullScore ?? fullScore
                    return "  - \(f.string(from: g.date))  \(Int(g.score.rounded()))/\(Int(full.rounded()))  \(g.examName.isEmpty ? "(无标题)" : g.examName)"
                }
                .joined(separator: "\n")
            let ctx = MistakeContext.build(from: subjectMistakes)
            let mistakeBlock: String = ctx.reviewedMistakeCount > 0
                ? """
                \n--- 错题复习状态 ---
                已复习错题数:\(ctx.reviewedMistakeCount)
                平均掌握度:\(String(format: "%.0f%%", ctx.averageMastery * 100))
                总曝光次数:\(ctx.totalExposureCount)
                """
                : "\n--- 错题复习状态 ---\n(本科目暂无错题数据)\n"
            discussionContext = """
            学科:\(exam.subject)
            考试名称:\(exam.name)
            考试日期:\(f.string(from: exam.examDate))
            满分:\(Int(fullScore))

            --- 默认算法预测 ---
            点估计:\(Int(defaultResult.predicted.rounded()))
            95% 区间:[\(Int(defaultResult.lowerBound.rounded())), \(Int(defaultResult.upperBound.rounded()))]
            区间半宽:±\(String(format: "%.1f", defaultResult.halfWidth))
            样本量:\(defaultResult.usedSampleSize)

            --- 最近 5 次成绩 ---
            \(recent.isEmpty ? "(无)" : recent)
            \(mistakeBlock)

            --- 上一次 AI 预测(只读) ---
            \(lastPrediction)
            """
        case .comprehensive(let target):
            let subjectLines = target.perSubject
                .map { item -> String in
                    let r = item.result
                    let range = "\(Int(r.lowerBound.rounded()))~\(Int(r.upperBound.rounded()))"
                    let n = r.usedSampleSize
                    let half = String(format: "%.1f", r.halfWidth)
                    return "  - \(item.subject): 点估计=\(Int(r.predicted.rounded())), 95% CI=[\(range)], ±\(half) pts, n=\(n), 满分=\(Int(r.fullScore.rounded()))"
                }
                .joined(separator: "\n")
            let totalHalf = (target.totalUpper - target.totalLower) / 2.0
            discussionContext = """
            综合考试名称:\(target.exam.name)
            考试日期:\(f.string(from: target.exam.examDate))
            距离考试:\(max(0, Calendar.current.dateComponents([.day], from: Date(), to: target.exam.examDate).day ?? 0)) 天
            学科数:\(target.perSubject.count)
            满分合计:\(Int(target.totalFull.rounded()))

            --- 各科默认预测 ---
            \(subjectLines.isEmpty ? "(无)" : subjectLines)

            --- 总分默认预测 ---
            点估计:\(Int(target.totalPredicted.rounded()))
            95% 区间:[\(Int(target.totalLower.rounded())), \(Int(target.totalUpper.rounded()))]
            区间半宽:±\(String(format: "%.1f", totalHalf))

            --- 上一次 AI 总分预测(只读) ---
            \(lastPrediction)
            """
        }

        discussionInitial = lastPrediction
        showDiscussion = true
    }
}
