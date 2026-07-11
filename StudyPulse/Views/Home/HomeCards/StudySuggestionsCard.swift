//
//  StudySuggestionsCard.swift
//  StudyPulse
//
//  主页"学习建议"卡片:基于 grades / mistakes / exams / 身体状态
// 给出 3 条最高优先级建议。建议生成已迁入 HomeViewModel.generateSuggestions(...)
// (底层调用 SuggestionEngine);卡片本身只负责渲染。
//
//  LLM BYOK 增强(2026-07-11):当 `AppPreferences.llmEnabled == true` 时,
//  卡片额外调用 `LLMClient.stream` 拉取 3 条 AI 建议并流式覆盖本地结果;
//  失败时静默回退到本地建议 + 显示 "AI 建议不可用"。
//
//  Extracted from HomeView.swift during card-extraction refactor (2026-07-05).
//

import SwiftUI

/// 主页"学习建议"卡片。
/// 由父 View 注入 `HomeViewModel`(VM 暴露 `generateSuggestions(limit:)`)。
/// 卡片观察 `HealthKitManager.shared` 的 `bodyStatus`,身体状态变化时刷新建议。
struct StudySuggestionsCard: View {
    @ObservedObject var viewModel: HomeViewModel
    @ObservedObject private var healthManager = HealthKitManager.shared
    @EnvironmentObject private var envManager: AppEnvironmentManager

    /// 本地建议(由 `HomeViewModel.generateSuggestions` 产生,作为 fallback)
    @State private var localSuggestions: [StudySuggestion] = []
    /// AI 建议(流式累积,任意时刻可被本地覆盖以回退)
    @State private var aiSuggestions: [StudySuggestion]? = nil
    /// 当前 LLM 流式任务;进入卡片/重新加载前 cancel 旧任务
    @State private var aiTask: Task<Void, Never>? = nil
    /// AI 错误信息(用于显示"AI 建议不可用"小灰字)
    @State private var aiErrorMessage: String? = nil
    /// AI 加载中(用于显示 progress chip)
    @State private var aiLoading: Bool = false

    /// 当前展示的建议(优先 AI,失败/未启用时本地)
    private var displayed: [StudySuggestion] {
        aiSuggestions ?? localSuggestions
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Text("Study Suggestions".localized())
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)

                if envManager.llmConfig.isConfigured && aiSuggestions != nil {
                    aiChip
                } else if envManager.llmConfig.isConfigured && aiLoading {
                    aiLoadingChip
                }

                Spacer()

                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.yellow)
            }

            if displayed.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("Start adding grades to get suggestions!".localized())
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(displayed.prefix(3), id: \.id) { suggestion in
                        SuggestionRowView(suggestion: suggestion)
                    }
                    if envManager.llmConfig.isConfigured && aiErrorMessage != nil && aiSuggestions == nil {
                        Text(aiErrorMessage ?? "")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSkin(envManager.effectiveCardSkin, glassEnabled: envManager.glassEffectEnabled)
        .onAppear { reload() }
        .debugLayoutBoundsAuto()
        .onChange(of: healthManager.bodyStatus) { _, _ in reload() }
        .onDisappear { aiTask?.cancel() }
    }

    // MARK: - AI chip

    private var aiChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.system(size: 10, weight: .bold))
            Text("AI".localized())
                .font(.system(size: 10, weight: .bold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.teal.opacity(0.18)))
        .foregroundColor(.teal)
    }

    private var aiLoadingChip: some View {
        HStack(spacing: 4) {
            ProgressView().scaleEffect(0.55)
            Text("AI".localized())
                .font(.system(size: 10, weight: .bold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.teal.opacity(0.12)))
        .foregroundColor(.teal)
    }

    // MARK: - Reload

    /// 拉取最新 3 条本地建议 + 可选的 AI 建议。
    /// 失败时静默回退到本地版本。
    private func reload() {
        // 1) 本地建议总是先就位
        localSuggestions = viewModel.generateSuggestions(limit: 3)

        // 2) 如果 LLM 未配置 / 未启用,直接展示本地版本
        guard envManager.llmConfig.isConfigured else {
            aiSuggestions = nil
            aiErrorMessage = nil
            aiLoading = false
            return
        }

        // 3) 取消上一次流式任务
        aiTask?.cancel()
        aiLoading = true
        aiErrorMessage = nil
        aiSuggestions = nil

        aiTask = Task {
            await streamAI()
        }
    }

    @MainActor
    private func streamAI() async {
        let config = envManager.llmConfig
        let context = viewModel.buildSuggestionsContext()
        let prompt = StudySuggestionsLLM.makePrompt(context)
        var accumulated = ""
        do {
            _ = try await LLMClient.shared.stream(prompt: prompt, config: config) { snapshot in
                accumulated = snapshot
            }
            if let parsed = StudySuggestionsLLM.parse(accumulated) {
                aiSuggestions = parsed
                aiErrorMessage = nil
            } else {
                // 解析失败 → 回退本地
                aiSuggestions = nil
                aiErrorMessage = "AI 建议不可用,显示本地版本".localized()
            }
        } catch is CancellationError {
            // 正常取消,保持当前状态
        } catch {
            aiSuggestions = nil
            aiErrorMessage = "AI 建议不可用,显示本地版本".localized()
        }
        aiLoading = false
    }
}

// MARK: - 建议行视图

/// 单条学习建议行(展开/收起描述)。
struct SuggestionRowView: View {
    let suggestion: StudySuggestion
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(suggestion.color.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: suggestion.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(suggestion.color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(suggestion.description)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(isExpanded ? nil : 2)
                }

                Spacer()

                PriorityIndicator(priority: suggestion.priority)
            }

            if !isExpanded {
                Button(action: { isExpanded = true }) {
                    Text("Read more".localized())
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(14)
        .background(Color(.systemBackground).opacity(0.6))
        .cornerRadius(14)
    }
}

// MARK: - 优先级指示器

/// SuggestionRowView 右上角小色块(HIGH / MED / LOW)。
struct PriorityIndicator: View {
    let priority: StudySuggestion.Priority

    var body: some View {
        ZStack {
            Capsule()
                .fill(color.opacity(0.15))

            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
        }
        .frame(height: 20)
    }

    private var label: String {
        switch priority {
        case .high: return "HIGH".localized()
        case .medium: return "MED".localized()
        case .low: return "LOW".localized()
        }
    }

    private var color: Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .green
        }
    }
}
