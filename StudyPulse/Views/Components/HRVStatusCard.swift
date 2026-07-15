//
//  HRVStatusCard.swift
//  StudyPulse
//
//  Dashboard card showing recovery readiness as a 4-axis radar / polygon
//  chart (HRV, heart rate, recovery sleep, respiratory rate) and an
//  integrated study suggestion derived from the same signals.
//  仪表盘卡片:用 4 轴雷达 / 多边形图(HRV、心率、恢复睡眠、呼吸频率)
//  展示恢复度,并从同一组信号中派生学习建议。
//
//  Phase 3 拆分 (2026-07-14):原 951 行单文件 → orchestrator 留本文件,
//  拆出 4 个独立子文件:
//  - BodyRadarValues.swift             (6 轴归一化数值 + 颜色 / 文本)
//  - BodyRadarChart.swift              (6 轴多边形 Path 绘制)
//  - FitnessRingView.swift             (单环进度环,Activity-ring 风格)
//  - HRVStatusSuggestionSection.swift  (本地 + LLM 增强建议区,含 AI debug 入口)
//
//  本文件只剩:主 View 编排(header / chart / axis row / suggestion / AI 请求生命周期 / 冷却计时 / discussion sheet)。
//

import SwiftUI
import os

/// 恢复雷达卡:HRV/HR/睡眠/呼吸 4 轴雷达 + 整合学习建议。
/// Recovery radar card: 4-axis radar (HRV/HR/Sleep/Respiratory) + integrated study suggestion.
struct HRVStatusCard: View {
    @ObservedObject var hrvManager = HealthKitManager.shared
    @Environment(RepositoryContainer.self) private var container
    @State private var animateIn = false

    // LLM 增强雷达建议
    // LLM enhancement state.
    @State private var aiSuggestion: StudySuggestion? = nil
    @State private var aiLoading: Bool = false
    @State private var aiErrorMessage: String? = nil
    @State private var aiTask: Task<Void, Never>? = nil
    @State private var lastAIFullText: String? = nil
    @State private var lastBodyReadinessContext: BodyReadinessContext? = nil
    @State private var showDiscussion: Bool = false

    // 冷却:40 分钟内最多 1 次自动请求,除非用户点"立刻分析"
    /// Radar LLM 增强建议的冷却时长(秒);默认 40 分钟。
    /// Cooldown duration (seconds) for the body-radar LLM-enhanced suggestion. Default 40 min.
    private static let radarAICooldownSeconds: TimeInterval = 40 * 60
    /// 距下次可自动请求的剩余秒数;Timer 每秒刷新一次。
    /// Seconds remaining until the next automatic request is allowed; refreshed every second.
    @State private var cooldownRemainingSeconds: Int = 0
    /// 每秒刷新倒计时的定时器。
    /// Timer that refreshes the countdown every second.
    @State private var cooldownTimer: Timer? = nil

    /// 今日的本地算法建议(用于 AI 流式期间显示 + AI 解析失败的兜底)
    private var localSuggestion: StudySuggestion? {
        StudyReadinessAlgorithm.recommend(
            hrvEnabled: hrvManager.hrvEnabled,
            hrvOnboardingCompleted: hrvManager.hrvOnboardingCompleted,
            isAuthorized: hrvManager.isAuthorized,
            hrv: hrvManager.readiness,
            bodyStatus: hrvManager.bodyStatus,
            baselines: hrvManager.personalBaselines,
            age: container.profileRepo.profile.age
        )
    }

    /// 当前展示的建议:AI 成功时用 AI,否则本地
    private var displayedSuggestion: StudySuggestion? {
        aiSuggestion ?? localSuggestion
    }

    var body: some View {
        if hrvManager.hrvEnabled && hrvManager.hrvOnboardingCompleted {
            VStack(alignment: .leading, spacing: 14) {
                header

                if hrvManager.isHealthBootstrapping {
                    // 后台仍在跑 14 天 HRV 查询 + PersonalBaselines 重算
                    // 时显示 Loading 占位,避免首屏卡住。
                    loadingPlaceholder
                } else {
                    if hrvManager.hrvDetailLevel != .suggestionOnly {
                        let radar = BodyRadarValues.compute(
                            hrv: hrvManager.readiness,
                            body: hrvManager.bodyStatus,
                            baselines: hrvManager.personalBaselines,
                            age: container.profileRepo.profile.age,
                            mistakes: container.mistakeRepo.filteredMistakeSets,
                            recentAnnotations: StudySessionStore.recentAnnotations(days: 7)
                        )
                        BodyRadarChart(values: radar)
                            .frame(height: 220)
                            .padding(.vertical, 4)
                    }

                    if hrvManager.hrvDetailLevel == .chartAndData {
                        axisValuesRow
                    }

                    suggestionRow
                }
            }
            .padding(DesignToken.Spacing.cardPadding)
            .cardSkin()
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(accent.opacity(0.25), lineWidth: 1)
            )
            .opacity(animateIn ? 1 : 0)
            .offset(y: animateIn ? 0 : 10)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    animateIn = true
                }
                startCooldownTimer()
                refreshAI()
            }
            .onDisappear {
                aiTask?.cancel()
                stopCooldownTimer()
            }
            .onChange(of: hrvManager.bodyStatus) { _, _ in refreshAI() }
            .onChange(of: hrvManager.readiness) { _, _ in refreshAI() }
            .onChange(of: hrvManager.personalBaselines) { _, _ in refreshAI() }
            .debugLayoutBoundsAuto()
        }
    }

    // MARK: - Loading Placeholder / 后台 bootstrap 期间的占位

    /// Placeholder shown while the background bootstrap is still
    /// running. Keeps the layout stable (no half-rendered radar) and
    /// signals that data is on the way.
    /// 后台 bootstrap 期间显示柔和的灰色卡,避免渲染残缺的雷达图/建议。
    private var loadingPlaceholder: some View {
        HStack(spacing: 10) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading...".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding(.vertical, 8)
    }

    // MARK: - Header / 顶部标题
    private var header: some View {
        HStack {
            Image(systemName: "heart.text.square.fill")
                .foregroundStyle(accent.gradient)
                .font(.title3)
            Text("Recovery Radar".localized())
                .font(.headline)
                .fontWeight(.bold)
            Spacer()
            readinessBadge
        }
    }

    // MARK: - Axis values row / 各轴数值行
    /// Numeric readout for each of the four radar dimensions.
    /// Shown only at the highest detail level. The workout slot is
    /// rendered as a 3-ring fitness ring instead of a plain text tile.
    /// 4 轴雷达各维度的数值读数,只在最高细节级别显示。
    /// 运动那一格用 3 圈 fitness ring 渲染,而不是普通文本块。
    private var axisValuesRow: some View {
        let radar = BodyRadarValues.compute(
            hrv: hrvManager.readiness,
            body: hrvManager.bodyStatus,
            baselines: hrvManager.personalBaselines,
            age: container.profileRepo.profile.age,
            mistakes: container.mistakeRepo.filteredMistakeSets,
            recentAnnotations: StudySessionStore.recentAnnotations(days: 7)
        )
        return HStack(spacing: 6) {
            axisTile(
                title: "HRV",
                value: radar.hrvValueText,
                color: radar.hrvColor
            )
            axisTile(
                title: "Heart Rate".localized(),
                value: radar.heartRateValueText,
                color: radar.heartRateColor
            )
            axisTile(
                title: "Recovery Sleep".localized(),
                value: radar.sleepValueText,
                color: radar.sleepColor
            )
            workoutTile(
                minutes: hrvManager.bodyStatus.exerciseMinutesToday
            )
            axisTile(
                title: "Respiratory".localized(),
                value: radar.respiratoryValueText,
                color: radar.respiratoryColor
            )
            axisTile(
                title: "Stability".localized(),
                value: radar.psychologicalStabilityValueText,
                color: radar.psychologicalStabilityColor
            )
        }
    }

    private func axisTile(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.08))
        )
    }

    /// Workout tile — small 3-ring fitness ring in the same visual
    /// language as the iOS Activity rings.
    /// 运动 tile:小型 3 圈 fitness ring,沿用 iOS Activity ring 的视觉语言。
    private func workoutTile(minutes: Double?) -> some View {
        // 每日运动目标:30 分钟即 100%
        // Daily workout goal: 30 minutes → 100% progress.
        let goal = 30.0
        let progress = min(1.0, (minutes ?? 0) / goal)
        let color = FitnessRingView.colorFor(progress: progress)
        return VStack(spacing: 3) {
            FitnessRingView(progress: progress, lineWidth: 3.5, size: 26)
                .frame(width: 26, height: 26)
            Text(String(format: "%.0f min", minutes ?? 0))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("Workout".localized())
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.08))
        )
    }

    // MARK: - Integrated suggestion row / 整合建议
    /// 雷达建议:本地算法 + LLM 增强。
    /// - 未配置 LLM → 直接显示本地建议
    /// - 已配置 LLM → 显示本地建议作为兜底,流式 LLM 增强版本覆盖
    /// - LLM 失败 → 静默回退本地,底部小灰字提示
    private var suggestionRow: some View {
        Group {
            if let suggestion = displayedSuggestion {
                VStack(alignment: .leading, spacing: 8) {
                    integratedSuggestionView(suggestion, isAIEnhanced: aiSuggestion != nil)
                    // AI 状态栏(loading chip / 错误提示 / 深入探讨)
                    suggestionFooter
                    // DEBUG 模式:卡片底部显示 LLM 调用指示器
                    LLMCallIndicator(caller: "BodyRadar")
                }
            } else if hrvManager.readiness.category == .insufficient {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text(hrvManager.readiness.suggestion)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if !hrvManager.readiness.suggestion.isEmpty {
                Text(hrvManager.readiness.suggestion)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showDiscussion) {
            AIDiscussionSheet(
                title: "雷达建议 · 深入探讨".localized(),
                context: buildRadarDiscussionContext(),
                initialAssistantMessage: lastAIFullText ?? localSuggestion?.description,
                onDismiss: { showDiscussion = false }
            )
            .adaptiveSheet(detents: [.large])
        }
    }

    /// 建议底部的 AI 状态 / 操作栏
    @ViewBuilder
    private var suggestionFooter: some View {
        let configured = container.envManager.llmConfig.isConfigured
        HStack(spacing: 8) {
            // AI chip / 冷却倒计时
            if configured {
                if aiLoading {
                    HStack(spacing: 4) {
                        ProgressView().scaleEffect(0.55)
                        Text("AI".localized())
                            .font(.caption2.weight(.bold))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.teal.opacity(0.12)))
                    .foregroundColor(.teal)
                } else if aiSuggestion != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.caption2.weight(.bold))
                        Text("AI".localized())
                            .font(.caption2.weight(.bold))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.teal.opacity(0.18)))
                    .foregroundColor(.teal)
                } else if let msg = aiErrorMessage {
                    Text(msg)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else if cooldownRemainingSeconds > 0 {
                    // 冷却中:显示剩余时间,告诉用户可点击"立刻分析"绕过
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(formatCooldown(cooldownRemainingSeconds))
                            .font(.caption2.monospacedDigit())
                    }
                    .foregroundColor(.secondary)
                }
            }
            Spacer()
            // 立刻分析:在冷却中 / 无 AI 结果时都允许点击(强制重置请求时间)
            if configured && localSuggestion != nil {
                Button {
                    requestAIImmediately()
                } label: {
                    Label("立刻分析".localized(), systemImage: "bolt.fill")
                        .font(.caption2.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .tint(.teal)
                .disabled(aiLoading)
            }
            // 深入探讨:当 AI 已给结果 / 本地建议有内容时显示
            if localSuggestion != nil {
                Button {
                    showDiscussion = true
                } label: {
                    Label("深入探讨".localized(), systemImage: "bubble.left.and.bubble.right.fill")
                        .font(.caption2.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .tint(.teal)
            }
        }
    }

    private func integratedSuggestionView(_ s: StudySuggestion, isAIEnhanced: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(s.color.opacity(0.15))
                    .frame(width: 30, height: 30)
                Image(systemName: s.icon)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(s.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(s.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                    if isAIEnhanced {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                            .foregroundColor(.teal)
                    }
                }
                Text(s.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(s.color.opacity(0.08))
        )
    }

    // MARK: - AI 生命周期 / AI lifecycle

    /// 拉取最新数据后决定:本地建议立刻就位;若 LLM 已配置且不在冷却中则流式增强
    /// - 冷却:距上次成功请求 < 40 分钟时跳过,显示本地建议 + 倒计时
    /// - "立刻分析" 按钮调用 `requestAIImmediately()` 强制绕过冷却
    private func refreshAI() {
        // 数据变更时,本地建议永远是 fallback;AI 状态重置
        aiTask?.cancel()
        aiLoading = false
        aiErrorMessage = nil
        aiSuggestion = nil
        lastAIFullText = nil

        guard container.envManager.llmConfig.isConfigured else { return }
        guard let local = localSuggestion else { return }

        // 冷却中 → 不发请求,但刷新倒计时让用户看到剩余时间
        if !canRequestNow() {
            updateCooldownRemaining()
            return
        }

        runLLMRequest(fallback: local)
    }

    /// 用户点击"立刻分析":无视 40 分钟冷却,立刻发请求并重置冷却起点。
    /// 公开入口:UI 上的 ⚡ 按钮直接调用此方法。
    func requestAIImmediately() {
        aiTask?.cancel()
        aiLoading = false
        aiErrorMessage = nil
        aiSuggestion = nil
        lastAIFullText = nil

        guard container.envManager.llmConfig.isConfigured else { return }
        guard let local = localSuggestion else { return }
        runLLMRequest(fallback: local)
    }

    /// 实际发起 LLM 请求的内部方法;请求前重置冷却起点,请求完成后再次刷新倒计时。
    private func runLLMRequest(fallback: StudySuggestion) {
        // 构造 LLM 上下文(包含 30 天基线 + 今日信号 + 本地建议)
        let context = StudyReadinessAlgorithm.buildBodyReadinessContext(
            hrvEnabled: hrvManager.hrvEnabled,
            hrvOnboardingCompleted: hrvManager.hrvOnboardingCompleted,
            isAuthorized: hrvManager.isAuthorized,
            hrv: hrvManager.readiness,
            bodyStatus: hrvManager.bodyStatus,
            baselines: hrvManager.personalBaselines,
            age: container.profileRepo.profile.age,
            recentDifficultyAnnotations: StudySessionStore.recentAnnotations(days: 7)
        )
        lastBodyReadinessContext = context

        let config = container.envManager.llmConfig
        let prompt = BodyRadarLLM.makePrompt(context)
        aiLoading = true
        aiTask = Task {
            var accumulated = ""
            do {
                _ = try await LLMClient.shared.stream(prompt: prompt, config: config, caller: "BodyRadar") { snapshot in
                    accumulated = snapshot
                }
                if let parsed = BodyRadarLLM.parse(accumulated, fallback: fallback) {
                    aiSuggestion = parsed
                    lastAIFullText = accumulated
                    aiErrorMessage = nil
                } else {
                    aiErrorMessage = "AI 建议不可用,显示本地版本".localized()
                }
            } catch is CancellationError {
                // 正常取消
            } catch {
                aiErrorMessage = "AI 建议不可用,显示本地版本".localized()
                Log.llm.error("BodyRadarLLM stream failed: \(error.localizedDescription, privacy: .public)")
            }
            // 成功 / 失败 / 取消都重置冷却起点 —— 一次请求就消耗一次配额
            container.envManager.preferences.lastRadarAIRequestTime = Date()
            updateCooldownRemaining()
            aiLoading = false
        }
    }

    // MARK: - 冷却辅助 / Cooldown helpers

    /// 是否在冷却中(且未强制)
    private func canRequestNow() -> Bool {
        guard let last = container.envManager.preferences.lastRadarAIRequestTime else { return true }
        return Date().timeIntervalSince(last) >= Self.radarAICooldownSeconds
    }

    /// 计算并写入 `cooldownRemainingSeconds`(供 UI 倒计时显示)
    private func updateCooldownRemaining() {
        guard let last = container.envManager.preferences.lastRadarAIRequestTime else {
            cooldownRemainingSeconds = 0
            return
        }
        let elapsed = Date().timeIntervalSince(last)
        let remaining = max(0, Self.radarAICooldownSeconds - elapsed)
        cooldownRemainingSeconds = Int(remaining.rounded())
    }

    /// 启动每秒刷新一次的倒计时 Timer
    private func startCooldownTimer() {
        updateCooldownRemaining()
        guard cooldownRemainingSeconds > 0 else { return }
        stopCooldownTimer()
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                updateCooldownRemaining()
                if cooldownRemainingSeconds <= 0 {
                    stopCooldownTimer()
                }
            }
        }
    }

    private func stopCooldownTimer() {
        cooldownTimer?.invalidate()
        cooldownTimer = nil
    }

    /// 把剩余秒数格式化成 "mm:ss"(> 1 小时显示 "Hh Mm")
    private func formatCooldown(_ seconds: Int) -> String {
        if seconds <= 0 { return "00:00" }
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    /// 给"深入探讨" sheet 用的上下文:复刻 prompt 中的关键字段
    private func buildRadarDiscussionContext() -> String {
        guard let ctx = lastBodyReadinessContext else {
            // 兜底:在 lastBodyReadinessContext 没初始化时用当前数据
            let temp = StudyReadinessAlgorithm.buildBodyReadinessContext(
                hrvEnabled: hrvManager.hrvEnabled,
                hrvOnboardingCompleted: hrvManager.hrvOnboardingCompleted,
                isAuthorized: hrvManager.isAuthorized,
                hrv: hrvManager.readiness,
                bodyStatus: hrvManager.bodyStatus,
                baselines: hrvManager.personalBaselines,
                age: container.profileRepo.profile.age,
                recentDifficultyAnnotations: StudySessionStore.recentAnnotations(days: 7)
            )
            lastBodyReadinessContext = temp
            return BodyRadarLLM.makePrompt(temp).messages.first?.content
                ?? "雷达建议上下文"
        }
        return BodyRadarLLM.makePrompt(ctx).messages.first?.content
            ?? "雷达建议上下文"
    }

    // MARK: - Computed Properties / 计算属性
    private var accent: Color {
        // 按 readiness category 取强调色
        // Accent color per readiness category.
        switch hrvManager.readiness.category {
        case .excellent: return .green
        case .normal: return .blue
        case .low: return .orange
        case .loading, .insufficient, .noAuthorization, .queryFailed: return .secondary
        }
    }

    private var readinessBadge: some View {
        Text(badgeLabel)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(accent.opacity(0.15)))
            .foregroundColor(accent)
    }

    private var badgeLabel: String {
        switch hrvManager.readiness.category {
        case .excellent: return "Excellent".localized()
        case .normal: return "Normal".localized()
        case .low: return "Low".localized()
        case .loading: return "Loading...".localized()
        case .insufficient: return "Collecting".localized()
        case .noAuthorization: return "-"
        case .queryFailed: return "Error".localized()
        }
    }
}
