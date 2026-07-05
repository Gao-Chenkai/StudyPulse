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

    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var envManager: AppEnvironmentManager
    @State private var showingDetail = false
    @State private var didLog = false

    private let predictor: ScorePredictor = ScorePredictorFactory.active

    private var predictionResult: ScorePredictionResult? {
        predictor.predict(history: history, examDate: exam.examDate, fullScore: fullScore)
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
            .background(Color(.systemGroupedBackground))
            .onAppear {
                guard !didLog else { return }
                didLog = true
                Log.prediction.info("预测 Sheet 打开 / sheet opened; exam=\(self.exam.name, privacy: .public), subject=\(self.exam.subject, privacy: .public), history=\(self.history.count, privacy: .public)")
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

                // 95% CI 柱状图
                ciBarChartCard(result: result)

                // 关键统计
                statsCard(result: result)

                // 历史样本
                historyCard(result: result)

                // 详情入口
                detailButton
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
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
                if let r2 = result.rSquared {
                    Text("R² = \(String(format: "%.2f", r2))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
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
                    .foregroundColor(.secondary)
                Text("→")
                    .font(.title3)
                    .foregroundColor(.secondary)
                Text("\(Int(result.predicted.rounded()))")
                    .font(.title3.weight(.heavy))
                    .foregroundColor(envManager.effectiveAccentColor)
                Text("→")
                    .font(.title3)
                    .foregroundColor(.secondary)
                Text("\(Int(result.upperBound.rounded()))")
                    .font(.title3.weight(.bold))
                    .foregroundColor(.secondary)
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

            statsRow(
                title: "Sample Size".localized(),
                value: "\(result.usedSampleSize)"
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
            if let r2 = result.rSquared {
                let qualityKey: String = (r2 >= 0.8) ? "Strong" : (r2 >= 0.4 ? "Moderate" : "Weak")
                let quality = qualityKey.localized()
                statsRow(
                    title: "Fit Quality".localized(),
                    value: String(format: "%@ (%@)".localized(), quality, String(format: "%.2f", r2))
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

    /// 历史样本列表（最近 N 条）
    @ViewBuilder
    private func historyCard(result: ScorePredictionResult) -> some View {
        let recent = history.sorted(by: { $0.date > $1.date }).prefix(result.usedSampleSize)
        if !recent.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Recent Grades Used".localized())
                    .font(.subheadline)
                    .fontWeight(.semibold)
                ForEach(Array(recent), id: \.id) { g in
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

    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var envManager: AppEnvironmentManager
    @Environment(\.dismiss) private var dismiss
    @State private var targetScoreText: String = ""
    @State private var didInitTarget = false
    @FocusState private var targetFocused: Bool

    /// 候选错题：同科目的所有错题（按 active phase 过滤）。
    private var candidateMistakes: [MistakeNote] {
        dataManager.filteredMistakeSets
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
    let sampleHistory: [Grade] = (0..<5).map { i in
        Grade(
            subject: "Math",
            score: 95.0 + Double(i) * 3 + Double.random(in: -3...3),
            ranking: 50 - i * 5,
            importance: 3,
            date: Calendar.current.date(byAdding: .day, value: -(30 - i * 7), to: now)!,
            examName: "Mock Exam #\(i + 1)",
            fullScore: 150
        )
    }
    let exam = Exam(
        name: "Midterm Math",
        date: Calendar.current.date(byAdding: .day, value: 21, to: now)!,
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
    .environmentObject(DataManager())
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    totalCard
                    ForEach(target.perSubject, id: \.subject) { item in
                        perSubjectCard(item: item)
                    }
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
        }
    }

    /// 总分卡
    @ViewBuilder
    private var totalCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Total".localized())
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(String(format: "/ %d".localized(), Int(target.totalFull.rounded())))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(target.totalLower.rounded()))")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.secondary)
                Text("→")
                    .foregroundColor(.secondary)
                Text("\(Int(target.totalPredicted.rounded()))")
                    .font(.title.weight(.heavy))
                    .foregroundColor(Color(.systemPurple))
                Text("→")
                    .foregroundColor(.secondary)
                Text("\(Int(target.totalUpper.rounded()))")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.secondary)
            }
            Text("95% Confidence Interval (Sum)".localized())
                .font(.caption2)
                .foregroundColor(.secondary)
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
                Spacer()
                Text(String(format: "/ %d".localized(), Int(r.fullScore.rounded())))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(r.lowerBound.rounded()))")
                    .font(.callout.weight(.bold))
                    .foregroundColor(.secondary)
                Text("→")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(Int(r.predicted.rounded()))")
                    .font(.title3.weight(.heavy))
                    .foregroundColor(Color(.systemPurple))
                Text("→")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(Int(r.upperBound.rounded()))")
                    .font(.callout.weight(.bold))
                    .foregroundColor(.secondary)
            }
            Text(String(format: "n = %d".localized(), r.usedSampleSize))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}
