//
//  ScorePredictionSheet.swift
//  StudyPulse
//
//  考试详情页"预测"按钮弹出的 Sheet：
//  - 顶部用柱状图展示 95% 置信区间（带参考线 / 数值标注）
//  - 中部显示预测统计（点估计、斜率、R²、样本量）
//  - 底部"详情"按钮：进入"为达到 N 分需要复习 XX"的推荐页
//
//  Created for the Exam "预测" button feature.
//

import SwiftUI
import Charts
import os
import SwiftStreamingMarkdown

// MARK: - 预测结果入口 Sheet

/// 预测 Sheet：从 Exam 行的"预测"按钮进入，展示 95% CI 柱状图和详情入口。
struct ScorePredictionSheet: View {
    /// 目标考试
    let exam: Exam
    /// 同科目的历史成绩
    let history: [Grade]
    /// 满分
    let fullScore: Double
    /// 退出回调
    let onDismiss: () -> Void

    @Environment(RepositoryContainer.self) private var container
    @EnvironmentObject var envManager: AppEnvironmentManager
    @State private var showingDetail = false
    @State private var didLog = false

    // LLM AI 预测状态
    @State private var aiPredictionText: String? = nil
    @State private var aiPredictionLoading: Bool = false
    @State private var aiPredictionError: String? = nil
    @State private var aiPredictionTask: Task<Void, Never>? = nil

    // LLM 深入探讨 sheet
    @State private var showDiscussion: Bool = false
    @State private var discussionContext: String = ""
    @State private var discussionInitial: String? = nil

    private let predictor: ScorePredictor = ScorePredictorFactory.active

    /// 同科目错题(已过滤);用于驱动 v1.4 二元回归 + mastery 缩窄 CI
    private var subjectMistakes: [MistakeNote] {
        container.mistakeRepo.filteredMistakeSets
            .filter { $0.subject == exam.subject }
    }

    private var predictionResult: ScorePredictionResult? {
        let context = MistakeContext.build(from: subjectMistakes)
        return predictor.predict(
            history: history,
            mistakeContext: context,
            examDate: exam.examDate,
            fullScore: fullScore
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if let result = predictionResult {
                    contentView(result: result)
                } else {
                    emptyState
                }
            }
            .navigationTitle("Score Prediction".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done".localized()) { onDismiss() }
                }
                ToolbarItem(placement: .principal) {
                    Text("Score Prediction".localized())
                        .appleIntelligenceForeground()
                        .font(.headline)
                }
            }
            .sheet(isPresented: $showingDetail) {
                if let result = predictionResult {
                    ScorePredictionDetailView(
                        exam: exam,
                        history: history,
                        result: result,
                        fullScore: fullScore
                    )
                    .adaptiveSheet(detents: [.medium, .large])
                }
            }
            .sheet(isPresented: $showDiscussion) {
                AIDiscussionSheet(
                    title: "AI 预测 · 深入探讨".localized(),
                    context: discussionContext,
                    initialAssistantMessage: discussionInitial,
                    onDismiss: { showDiscussion = false }
                )
                .adaptiveSheet(detents: [.large])
            }
            .background(Color(.systemGroupedBackground))
            .onAppear {
                guard !didLog else { return }
                didLog = true
                Log.prediction.info("预测 Sheet 打开 / sheet opened; exam=\(self.exam.name, privacy: .public), subject=\(self.exam.subject, privacy: .public), history=\(self.history.count, privacy: .public)")
            }
            .onDisappear {
                aiPredictionTask?.cancel()
                aiPredictionTask = nil
            }
        }
    }

    // MARK: - 内容

    @ViewBuilder
    private func contentView(result: ScorePredictionResult) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // 头部：考试信息 + 引擎名
                headerCard(result: result)

                // 离群点警告(若最近一次考试残差 > 3σ)
                if let warning = result.outlierWarning {
                    outlierWarningCard(warning: warning)
                }

                // v1.5:数据不足横幅(n<3 / yHat 撞边界 / CI 撑满)
                if result.isLowConfidence {
                    lowConfidenceCard(result: result)
                }

                // 95% CI 柱状图
                ciBarChartCard(result: result)

                // 关键统计
                statsCard(result: result)

                // 历史样本
                historyCard(result: result)

                // AI 预测按钮 + 折叠结果(LLM BYOK;未配置时按钮灰显)
                aiPredictionCard(result: result)

                // 详情入口
                detailButton
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
    }

    /// AI 预测卡:默认显示一个"让大模型预测"按钮;点击后流式拉取 LLM 预测。
    /// 失败时显示错误信息(可点重试),成功时用 MarkdownView 渲染。
    @ViewBuilder
    private func aiPredictionCard(result: ScorePredictionResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundColor(.teal)
                Text("AI 预测".localized())
                    .font(.subheadline.weight(.semibold))
                if aiPredictionLoading {
                    ProgressView().scaleEffect(0.7).padding(.leading, 2)
                }
                Spacer()
                if envManager.llmConfig.isConfigured {
                    Text("BYOK".localized())
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.teal.opacity(0.15)))
                        .foregroundColor(.teal)
                }
            }

            // 状态 1: 未配置 LLM
            if !envManager.llmConfig.isConfigured {
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
            else if let text = aiPredictionText {
                MarkdownView(
                    text: text.normalisingSingleDollarMath(),
                    config: .previewConfig
                )
                .textSelection(.enabled)
                HStack(spacing: 10) {
                    // 深入探讨:基于本场预测与 AI 多轮对话
                    Button {
                        presentDiscussion(result: result, lastPrediction: text)
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
            else if aiPredictionLoading {
                Text(aiPredictionText ?? "Waiting...".localized())
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            // 状态 4: 已配置,出错
            else if let err = aiPredictionError {
                VStack(alignment: .leading, spacing: 4) {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.orange)
                    Button("重试".localized()) {
                        startAIPrediction(result: result)
                    }
                    .font(.caption)
                }
            }
            // 状态 5: 已配置,未触发 → 显示"开始预测"按钮
            else {
                Text("让大模型基于历史成绩、错题状态和默认预测,给出第二意见。".localized())
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button {
                    startAIPrediction(result: result)
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
    }

    /// 触发 LLM 流式预测
    private func startAIPrediction(result: ScorePredictionResult) {
        aiPredictionTask?.cancel()
        aiPredictionText = ""
        aiPredictionError = nil
        aiPredictionLoading = true
        let config = envManager.llmConfig
        let context = MistakeContext.build(from: subjectMistakes)
        let prompt = ScorePredictionLLM.makePrompt(
            exam: exam,
            history: history,
            defaultResult: result,
            fullScore: fullScore,
            mistakeContext: context
        )
        aiPredictionTask = Task {
            do {
                _ = try await LLMClient.shared.stream(
                    prompt: prompt,
                    config: config
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

    /// 打开"深入探讨" sheet:把本场默认预测 + 已有 AI 预测作为上下文/初始消息。
    private func presentDiscussion(result: ScorePredictionResult, lastPrediction: String) {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
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
        let context = """
        学科:\(exam.subject)
        考试名称:\(exam.name)
        考试日期:\(f.string(from: exam.examDate))
        满分:\(Int(fullScore))

        --- 默认算法预测 ---
        点估计:\(Int(result.predicted.rounded()))
        95% 区间:[\(Int(result.lowerBound.rounded())), \(Int(result.upperBound.rounded()))]
        区间半宽:±\(String(format: "%.1f", result.halfWidth))
        样本量:\(result.usedSampleSize)

        --- 最近 5 次成绩 ---
        \(recent.isEmpty ? "(无)" : recent)
        \(mistakeBlock)

        --- 上一次 AI 预测(只读) ---
        \(lastPrediction)
        """
        discussionContext = context
        discussionInitial = lastPrediction
        showDiscussion = true
    }

    /// v1.5:数据不足横幅——明确告诉用户 CI 不可信,数字只是"参考"。
    @ViewBuilder
    private func lowConfidenceCard(result: ScorePredictionResult) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Color(.systemOrange))
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text("Data Insufficient for Reliable Prediction".localized())
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(String(
                    format: "仅基于 %d 条成绩,置信区间过宽,以下数字仅作参考。".localized(),
                    result.usedSampleSize
                ))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemOrange).opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color(.systemOrange).opacity(0.35), lineWidth: 1)
        )
    }

    /// 头部小卡：考试 + 引擎信息
    @ViewBuilder
    private func headerCard(result: ScorePredictionResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(exam.name)
                    .font(.headline)
                Spacer()
                Text(exam.subject.localized())
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(envManager.effectiveAccentColor.opacity(0.15))
                    )
                    .foregroundColor(envManager.effectiveAccentColor)
            }
            HStack {
                Label(exam.examDate.formatted(date: .abbreviated, time: .omitted),
                      systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Label(String(format: "Engine: %@".localized(), predictor.engineName),
                      systemImage: "cpu")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    /// 95% 置信区间柱状图
    @ViewBuilder
    private func ciBarChartCard(result: ScorePredictionResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("95% Confidence Interval".localized())
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(String(
                    format: "±%.1f %@".localized(),
                    result.halfWidth,
                    "pts".localized()
                ))
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(envManager.effectiveAccentColor)
            }

            // 主柱状图
            Chart {
                // 95% CI 带状区域（用 RectangleMark 画一个高度 = 区间宽度的"柱"）
                RectangleMark(
                    xStart: .value("Side", "CI"),
                    xEnd: .value("Side", "CI"),
                    yStart: .value("Lower", result.lowerBound),
                    yEnd: .value("Upper", result.upperBound)
                )
                .foregroundStyle(envManager.effectiveAccentColor.opacity(0.18))
                .cornerRadius(6)

                // 预测点水平线
                RuleMark(y: .value("Predicted", result.predicted))
                    .foregroundStyle(envManager.effectiveAccentColor)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .annotation(position: .top, alignment: .leading) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(envManager.effectiveAccentColor)
                                .frame(width: 7, height: 7)
                            Text("\(Int(result.predicted.rounded()))")
                                .font(.caption2.weight(.bold))
                                .foregroundColor(.primary)
                        }
                    }

                // 最近一次实际分数参考线
                if let last = result.lastActual {
                    RuleMark(y: .value("Last", last))
                        .foregroundStyle(Color(.systemGray))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .annotation(position: .bottom, alignment: .leading) {
                            Text(String(format: "Last %d".localized(), Int(last.rounded())))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                }
            }
            .chartXAxis(.hidden)
            .chartYScale(domain: 0...max(result.fullScore, result.upperBound * 1.05))
            .frame(height: 220)
            .padding(.top, 4)

            // 区间文本
            HStack(spacing: 6) {
                Text("\(Int(result.lowerBound.rounded()))")
                    .font(.title3.weight(.bold))
                    .foregroundColor(envManager.effectiveAccentColor.opacity(0.45))
                Text("→")
                    .font(.title3)
                    .foregroundColor(envManager.effectiveAccentColor.opacity(0.45))
                Text("\(Int(result.predicted.rounded()))")
                    .font(.title3.weight(.heavy))
                    .foregroundColor(envManager.effectiveAccentColor)
                Text("→")
                    .font(.title3)
                    .foregroundColor(envManager.effectiveAccentColor.opacity(0.45))
                Text("\(Int(result.upperBound.rounded()))")
                    .font(.title3.weight(.bold))
                    .foregroundColor(envManager.effectiveAccentColor.opacity(0.45))
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Text("Predicted score range with 95% confidence.".localized())
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    /// 关键统计
    @ViewBuilder
    private func statsCard(result: ScorePredictionResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Key Stats".localized())
                .font(.subheadline)
                .fontWeight(.semibold)

            // 主指标:基于 N 次考试,误差约 ±X 分(替代旧的 Strong/Moderate/Weak 标签)
            statsRow(
                title: "Prediction Range".localized(),
                value: String(
                    format: "Based on %d exams, ±%.1f pts".localized(),
                    result.usedSampleSize,
                    result.halfWidth
                )
            )

            // v1.4:错题曝光贡献 γ(每 10 次复习 → +X.X 分)
            // v1.5:错题数据过少时不显示(避免基于 1-2 次复习的 γ 误导)
            if result.shouldShowMistakeEffects, let gamma = result.exposureLift {
                let perTenReviews = gamma * 10
                let formattedPerTen = String(format: "%+0.1f", perTenReviews)
                statsRow(
                    title: "Exposure Lift".localized(),
                    value: String(
                        format: "每 10 次复习 → %@ %@".localized(),
                        formattedPerTen,
                        "pts".localized()
                    ),
                    valueColor: gamma >= 0 ? Color(.systemGreen) : Color(.systemRed)
                )
            }

            // v1.4:mastery 缩窄 CI(原始 ±X 分 → 缩窄后 ±Y 分)
            // v1.5:错题数据过少时不显示(此时 mastery=0 不缩窄,显示出来反而误导)
            if result.shouldShowMistakeEffects, result.avgMastery > 0 {
                let shrunkPct = Int((1.0 - result.masteryCIMultiplier) * 100)
                statsRow(
                    title: "Avg Mastery".localized(),
                    value: String(
                        format: "%d%% (CI −%d%%)".localized(),
                        Int(result.avgMastery * 100),
                        shrunkPct
                    ),
                    valueColor: Color(.systemBlue)
                )
            } else if !result.shouldShowMistakeEffects {
                // v1.5:错题数据不足 → 给出小提示,让用户知道 γ / mastery 为何缺席
                statsRow(
                    title: "Mistake Review".localized(),
                    value: "复习过少,未纳入计算".localized(),
                    valueColor: Color(.systemGray)
                )
            }

            // 窗口 + EWMA 上下文(供懂统计的用户看)
            statsRow(
                title: "Window".localized(),
                value: String(
                    format: "%dd / EWMA %dd".localized(),
                    Int(result.windowDays),
                    Int(result.halfLifeDays)
                )
            )

            if let slope = result.slope {
                let perWeek = slope * 7
                let trendKey: String = (abs(perWeek) < 0.05) ? "Flat" : (perWeek > 0 ? "Rising" : "Falling")
                let trend = trendKey.localized()
                let formatted = String(format: "%+.2f", perWeek)
                statsRow(
                    title: "Trend (per week)".localized(),
                    value: String(format: "%@ pts (%@)".localized(), formatted, trend)
                )
            }
            if let delta = result.delta {
                let formatted = String(format: "%+.1f", delta)
                let color: Color = delta >= 0 ? Color(.systemGreen) : Color(.systemRed)
                statsRow(
                    title: "Change vs. Last".localized(),
                    value: String(format: "%@ %@".localized(), formatted, "pts".localized()),
                    valueColor: color
                )
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    /// 离群点警告卡:最近一次考试残差 > 3σ 时展示
    @ViewBuilder
    private func outlierWarningCard(warning: OutlierWarning) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(Color(.systemOrange))
                Text("Outlier Detected".localized())
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(String(format: "z = %+.1fσ".localized(), warning.zScore))
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(Color(.systemOrange))
            }
            Text("Last exam may have been affected by special factors (illness, bad day, etc.). Treat the prediction with extra caution.".localized())
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                Text(String(format: "%@ %@".localized(), warning.date.formatted(date: .abbreviated, time: .omitted), "·"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(String(format: "Score %@, fitted %@, |residual| %@".localized(),
                            String(format: "%.1f", warning.score),
                            String(format: "%.1f", warning.fittedValue),
                            String(format: "%.1f", abs(warning.residual))))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemOrange).opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color(.systemOrange).opacity(0.35), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func statsRow(title: String, value: String, valueColor: Color = .primary) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundColor(valueColor)
        }
    }

    /// 历史样本列表(EWMA 窗口内的所有成绩)
    @ViewBuilder
    private func historyCard(result: ScorePredictionResult) -> some View {
        // 用 result.dataRange(参与回归的实际范围)排序,不再硬切 N 条
        let recent = result.dataRange.map { range in
            history.filter { range.contains($0.date) }
        } ?? []
        let sorted = recent.sorted(by: { $0.date > $1.date })
        if !sorted.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Grades Used".localized())
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    if let range = result.dataRange {
                        Text(String(
                            format: "%@ – %@".localized(),
                            range.lowerBound.formatted(date: .abbreviated, time: .omitted),
                            range.upperBound.formatted(date: .abbreviated, time: .omitted)
                        ))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                ForEach(sorted, id: \.id) { g in
                    HStack {
                        Text(g.date, format: .dateTime.month().day())
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .leading)
                        if !g.examName.isEmpty {
                            Text(g.examName)
                                .font(.caption)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text("(no name)".localized())
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Text("\(Int(g.score.rounded()))")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }

    /// 详情按钮
    @ViewBuilder
    private var detailButton: some View {
        Button {
            showingDetail = true
        } label: {
            HStack {
                Image(systemName: "target")
                Text("How to Reach Your Target".localized())
                    .fontWeight(.semibold)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(envManager.effectiveAccentColor.opacity(0.12))
            )
            .foregroundColor(envManager.effectiveAccentColor)
        }
        .buttonStyle(.plain)
    }

    /// 数据不足时的空状态
    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            ContentUnavailableView(
                "Not Enough Data".localized(),
                systemImage: "chart.bar.xaxis",
                description: Text("Add at least 2 grades for this subject to enable prediction.".localized())
            )
            Button("Done".localized()) { onDismiss() }
                .buttonStyle(.bordered)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - 预测详情页（"为达到 N 分需要复习 XX"）

/// 预测详情：用户输入目标分，显示分数差 + 推荐复习的错题。
struct ScorePredictionDetailView: View {
    let exam: Exam
    let history: [Grade]
    let result: ScorePredictionResult
    let fullScore: Double

    @Environment(RepositoryContainer.self) private var container
    @EnvironmentObject var envManager: AppEnvironmentManager
    @Environment(\.dismiss) private var dismiss
    @State private var targetScoreText: String = ""
    @State private var didInitTarget = false
    @FocusState private var targetFocused: Bool

    /// 候选错题：同科目的所有错题（按 active phase 过滤）。
    private var candidateMistakes: [MistakeNote] {
        container.mistakeRepo.filteredMistakeSets
            .filter { $0.subject == exam.subject && !$0.title.isEmpty }
            .sorted { $0.date > $1.date }
    }

    /// 当前目标分（解析失败时回退到 result.upperBound）
    private var targetScore: Double {
        let parsed = Double(targetScoreText.trimmingCharacters(in: .whitespaces)) ?? result.upperBound
        return max(0, min(parsed, fullScore))
    }

    /// 分数差
    private var gap: Double {
        MistakeGapAnalyzer.scoreGap(target: targetScore, result: result)
    }

    /// 推荐错题
    private var recommendations: [MistakeRecommendation] {
        guard gap > 0 else { return [] }
        return MistakeGapAnalyzer.recommendations(
            mistakes: candidateMistakes,
            targetScore: targetScore,
            maxCount: 5
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    targetInputCard
                    gapSummaryCard
                    if gap > 0 {
                        recommendationCard
                    } else {
                        onTrackCard
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Target Plan".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done".localized()) { dismiss() }
                }
            }
            .onAppear {
                guard !didInitTarget else { return }
                didInitTarget = true
                // 默认目标 = 向上取整到下一个 5 分位，但不高于满分
                let defaultTarget = min(fullScore, max(result.upperBound, (result.predicted + 5).rounded(.up)))
                let roundedToFive = (defaultTarget / 5.0).rounded() * 5.0
                let safe = max(1, min(fullScore, roundedToFive))
                targetScoreText = String(Int(safe))
            }
        }
    }

    // MARK: - 子卡片

    @ViewBuilder
    private var targetInputCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Target Score".localized())
                .font(.subheadline)
                .fontWeight(.semibold)

            HStack(spacing: 10) {
                TextField("e.g. 130", text: $targetScoreText)
                    .keyboardType(.numberPad)
                    .focused($targetFocused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.tertiarySystemGroupedBackground))
                    )
                    .frame(maxWidth: 120)
                Text("/ \(Int(fullScore))")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                Stepper("", value: Binding(
                    get: { Int(targetScoreText) ?? 0 },
                    set: { targetScoreText = String(max(0, min($0, Int(fullScore)))) }
                ))
                .labelsHidden()
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    @ViewBuilder
    private var gapSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Score Gap".localized())
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(String(format: "To %d".localized(), Int(targetScore)))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("+ \(String(format: "%.1f", gap))")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundColor(gap > 0 ? Color(.systemOrange) : Color(.systemGreen))
                Text("pts".localized())
                    .font(.headline)
                    .foregroundColor(.secondary)
            }

            Text(String(
                format: "To safely reach %d (with 95%% confidence), you need to close the gap above your lower bound (%d).".localized(),
                Int(targetScore),
                Int(result.lowerBound)
            ))
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    @ViewBuilder
    private var recommendationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Recommended Mistakes".localized())
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(String(format: "%d / %d".localized(),
                            recommendations.count,
                            candidateMistakes.count))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if recommendations.isEmpty {
                Text("No mistakes found for this subject yet. Add some to get targeted recommendations.".localized())
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 6)
            } else {
                ForEach(recommendations) { rec in
                    recommendationRow(rec)
                    if rec.id != recommendations.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    @ViewBuilder
    private func recommendationRow(_ rec: MistakeRecommendation) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.bubble.fill")
                .foregroundColor(.orange)
                .font(.callout)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(rec.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                HStack(spacing: 8) {
                    Label(rec.date.formatted(date: .abbreviated, time: .omitted),
                          systemImage: "calendar")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Label(String(format: "Mastery %d%%".localized(),
                                 Int((rec.masteryScore * 100).rounded())),
                          systemImage: "gauge.with.dots.needle.67percent")
                        .font(.caption2)
                        .foregroundColor(rec.masteryScore < 0.4 ? Color(.systemRed) : Color(.systemOrange))
                    if rec.exposureCount > 0 {
                        Label(String(format: "× %d".localized(), rec.exposureCount),
                              systemImage: "eye")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var onTrackCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("On Track".localized(), systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundColor(Color(.systemGreen))
            Text(String(
                format: "Your predicted lower bound (%d) already meets or exceeds the target (%d). No extra review needed based on current trend.".localized(),
                Int(result.lowerBound),
                Int(targetScore)
            ))
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemGreen).opacity(0.10))
        )
    }
}

#Preview("Linear Regression") {
    let now = Date()
    let sampleHistory: [Grade] = (0..<5).compactMap { i in
        guard let date = Calendar.current.date(byAdding: .day, value: -(30 - i * 7), to: now) else { return nil }
        return Grade(
            subject: "Math",
            score: 95.0 + Double(i) * 3 + Double.random(in: -3...3),
            ranking: 50 - i * 5,
            importance: 3,
            date: date,
            examName: "Mock Exam #\(i + 1)",
            fullScore: 150
        )
    }
    let exam = Exam(
        name: "Midterm Math",
        date: Calendar.current.date(byAdding: .day, value: 21, to: now) ?? now.addingTimeInterval(86400 * 21),
        importance: 5,
        subject: "Math",
        examName: "Midterm",
        masteryDegree: 60
    )
    return ScorePredictionSheet(
        exam: exam,
        history: sampleHistory,
        fullScore: 150,
        onDismiss: {}
    )
    .environment(RepositoryContainer())
    .environmentObject(AppEnvironmentManager.shared)
}

// MARK: - 综合考试预测 Sheet

/// 综合考试的预测结果(各科结果 + 合计)
struct PerSubjectPrediction: Equatable {
    let subject: String
    let result: ScorePredictionResult
}

struct ComprehensivePredictionTarget: Identifiable {
    let id = UUID()
    let exam: comprehensiveExam
    let perSubject: [PerSubjectPrediction]
    let totalFull: Double
    let totalPredicted: Double
    let totalLower: Double
    let totalUpper: Double
}

/// 综合考试预测 Sheet:逐科展示预测区间 + 顶部总分汇总。
struct ComprehensiveScorePredictionSheet: View {
    let target: ComprehensivePredictionTarget
    let onDismiss: () -> Void

    @EnvironmentObject var envManager: AppEnvironmentManager

    // LLM AI 预测状态
    @State private var aiPredictionText: String? = nil
    @State private var aiPredictionLoading: Bool = false
    @State private var aiPredictionError: String? = nil
    @State private var aiPredictionTask: Task<Void, Never>? = nil

    // LLM 深入探讨 sheet
    @State private var showDiscussion: Bool = false
    @State private var discussionContext: String = ""
    @State private var discussionInitial: String? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    totalCard
                    ForEach(target.perSubject, id: \.subject) { item in
                        perSubjectCard(item: item)
                    }
                    // AI 预测卡:与单科一致,默认显示一个"让大模型预测"按钮
                    comprehensiveAIPredictionCard
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Score Prediction".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done".localized()) { onDismiss() }
                }
                ToolbarItem(placement: .principal) {
                    Text("Score Prediction".localized())
                        .appleIntelligenceForeground()
                        .font(.headline)
                }
            }
            .onDisappear {
                aiPredictionTask?.cancel()
                aiPredictionTask = nil
            }
            .sheet(isPresented: $showDiscussion) {
                AIDiscussionSheet(
                    title: "AI 总分预测 · 深入探讨".localized(),
                    context: discussionContext,
                    initialAssistantMessage: discussionInitial,
                    onDismiss: { showDiscussion = false }
                )
                .adaptiveSheet(detents: [.large])
            }
        }
    }

    /// 综合考试 AI 预测卡(总分第二意见)
    @ViewBuilder
    private var comprehensiveAIPredictionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundColor(.teal)
                Text("AI 总分预测".localized())
                    .font(.subheadline.weight(.semibold))
                if aiPredictionLoading {
                    ProgressView().scaleEffect(0.7).padding(.leading, 2)
                }
                Spacer()
                if envManager.llmConfig.isConfigured {
                    Text("BYOK".localized())
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.teal.opacity(0.15)))
                        .foregroundColor(.teal)
                }
            }

            // 状态 1: 未配置 LLM
            if !envManager.llmConfig.isConfigured {
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
            else if let text = aiPredictionText {
                MarkdownView(
                    text: text.normalisingSingleDollarMath(),
                    config: .previewConfig
                )
                .textSelection(.enabled)
                HStack(spacing: 10) {
                    // 深入探讨:基于综合预测与 AI 多轮对话
                    Button {
                        presentComprehensiveDiscussion(lastPrediction: text)
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
            else if aiPredictionLoading {
                Text(aiPredictionText ?? "Waiting...".localized())
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            // 状态 4: 已配置,出错
            else if let err = aiPredictionError {
                VStack(alignment: .leading, spacing: 4) {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.orange)
                    Button("重试".localized()) {
                        startComprehensiveAIPrediction()
                    }
                    .font(.caption)
                }
            }
            // 状态 5: 已配置,未触发 → 显示"开始预测"按钮
            else {
                Text("让大模型基于各科默认预测,给出总分第二意见。".localized())
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button {
                    startComprehensiveAIPrediction()
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
    }

    /// 触发 LLM 流式预测(综合考试)
    private func startComprehensiveAIPrediction() {
        aiPredictionTask?.cancel()
        aiPredictionText = ""
        aiPredictionError = nil
        aiPredictionLoading = true
        let config = envManager.llmConfig
        let prompt = ComprehensiveScorePredictionLLM.makePrompt(
            exam: target.exam,
            target: target
        )
        aiPredictionTask = Task {
            do {
                _ = try await LLMClient.shared.stream(
                    prompt: prompt,
                    config: config
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

    /// 打开"深入探讨" sheet:把综合考试各科/总分预测 + 已有 AI 预测作为上下文/初始消息。
    private func presentComprehensiveDiscussion(lastPrediction: String) {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
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
        let context = """
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
        discussionContext = context
        discussionInitial = lastPrediction
        showDiscussion = true
    }

    /// 总分卡
    @ViewBuilder
    private var totalCard: some View {
        let totalHalfWidth = (target.totalUpper - target.totalLower) / 2.0
        let ciSpanRatio = target.totalFull > 0
            ? (target.totalUpper - target.totalLower) / target.totalFull
            : 0
        let totalLowConfidence = ciSpanRatio >= 0.8
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Total".localized())
                    .font(.subheadline)
                    .fontWeight(.semibold)
                if totalLowConfidence {
                    Label("Data Insufficient".localized(), systemImage: "exclamationmark.triangle.fill")
                        .labelStyle(.iconOnly)
                        .font(.caption2)
                        .foregroundColor(Color(.systemOrange))
                }
                Spacer()
                Text(String(format: "/ %d".localized(), Int(target.totalFull.rounded())))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(target.totalLower.rounded()))")
                    .font(.title2.weight(.bold))
                    .foregroundColor(Color(.systemPurple).opacity(0.45))
                Text("→")
                    .foregroundColor(Color(.systemPurple).opacity(0.45))
                Text("\(Int(target.totalPredicted.rounded()))")
                    .font(.title.weight(.heavy))
                    .foregroundColor(Color(.systemPurple))
                Text("→")
                    .foregroundColor(Color(.systemPurple).opacity(0.45))
                Text("\(Int(target.totalUpper.rounded()))")
                    .font(.title2.weight(.bold))
                    .foregroundColor(Color(.systemPurple).opacity(0.45))
            }
            if totalLowConfidence {
                Text("Confidence interval is too wide — too few recent grades to predict reliably.".localized())
                    .font(.caption2)
                    .foregroundColor(Color(.systemOrange))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(String(
                    format: "95%% Confidence Interval (Sum), ±%.1f %@".localized(),
                    totalHalfWidth,
                    "pts".localized()
                ))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    /// 单科预测卡(简化版,无详情入口)
    @ViewBuilder
    private func perSubjectCard(item: PerSubjectPrediction) -> some View {
        let r = item.result
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.subject.localized())
                    .font(.subheadline.weight(.semibold))
                if r.isLowConfidence {
                    Label("Data Insufficient".localized(), systemImage: "exclamationmark.triangle.fill")
                        .labelStyle(.iconOnly)
                        .font(.caption2)
                        .foregroundColor(Color(.systemOrange))
                }
                Spacer()
                Text(String(format: "/ %d".localized(), Int(r.fullScore.rounded())))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(r.lowerBound.rounded()))")
                    .font(.callout.weight(.bold))
                    .foregroundColor(r.isLowConfidence
                                     ? Color(.systemOrange).opacity(0.6)
                                     : Color(.systemPurple).opacity(0.45))
                Text("→")
                    .font(.caption)
                    .foregroundColor(r.isLowConfidence
                                     ? Color(.systemOrange).opacity(0.6)
                                     : Color(.systemPurple).opacity(0.45))
                Text("\(Int(r.predicted.rounded()))")
                    .font(.title3.weight(.heavy))
                    .foregroundColor(r.isLowConfidence ? Color(.systemOrange) : Color(.systemPurple))
                Text("→")
                    .font(.caption)
                    .foregroundColor(r.isLowConfidence
                                     ? Color(.systemOrange).opacity(0.6)
                                     : Color(.systemPurple).opacity(0.45))
                Text("\(Int(r.upperBound.rounded()))")
                    .font(.callout.weight(.bold))
                    .foregroundColor(r.isLowConfidence
                                     ? Color(.systemOrange).opacity(0.6)
                                     : Color(.systemPurple).opacity(0.45))
            }
            HStack(spacing: 6) {
                if r.isLowConfidence {
                    Text(String(
                        format: "n = %d · 区间过宽,数据不足".localized(),
                        r.usedSampleSize
                    ))
                        .font(.caption2)
                        .foregroundColor(Color(.systemOrange))
                } else {
                    Text(String(format: "n = %d, ±%.1f %@".localized(),
                                r.usedSampleSize,
                                r.halfWidth,
                                "pts".localized()))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                if r.outlierWarning != nil {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundColor(Color(.systemOrange))
                }
                // v1.5:错题数据过少时不显示 γ 和 mastery(避免误导)
                if r.shouldShowMistakeEffects, let gamma = r.exposureLift {
                    let perTen = String(format: "%+.1f", gamma * 10)
                    Text(String(format: "γ×10 = %@ %@".localized(),
                                perTen,
                                "pts".localized()))
                        .font(.caption2)
                        .foregroundColor(gamma >= 0 ? Color(.systemGreen) : Color(.systemRed))
                }
                if r.shouldShowMistakeEffects, r.avgMastery > 0 {
                    Text(String(format: "M=%d%%".localized(),
                                Int(r.avgMastery * 100)))
                        .font(.caption2)
                        .foregroundColor(Color(.systemBlue))
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}
