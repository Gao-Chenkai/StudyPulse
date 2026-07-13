//
//  ScorePredictionSheet.swift
//  StudyPulse
//
//  Created for the Exam "预测" button feature.
//  Exam "Predict" button feature.
//

import SwiftUI
import os

// MARK: - 共享头部卡片
// MARK: - Shared header card

/// 预测页通用头部(标题 / 副标题 / 日期 / 引擎名)
/// Shared prediction header (title / subtitle / date / engine name).
struct ScorePredictionHeaderCard: View {
    let title: String
    let subtitle: String
    let date: Date
    let engineName: String

    @EnvironmentObject var envManager: AppEnvironmentManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                Spacer()
                Text(subtitle)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(envManager.effectiveAccentColor.opacity(0.15))
                    )
                    .foregroundColor(envManager.effectiveAccentColor)
            }
            HStack {
                Label(date.formatted(date: .abbreviated, time: .omitted),
                      systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Label(String(format: "Engine: %@".localized(), engineName),
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
}

// MARK: - 单科预测入口 Sheet
// MARK: - Single-subject prediction entry sheet

/// 单科预测入口 Sheet
/// Single-subject prediction entry sheet.
struct ScorePredictionSheet: View {
    let exam: Exam
    let history: [Grade]
    let fullScore: Double
    let onDismiss: () -> Void

    @Environment(RepositoryContainer.self) private var container
    @EnvironmentObject var envManager: AppEnvironmentManager
    @State private var showingDetail = false
    @State private var didLog = false

    /// 当前激活的预测器(由工厂决定)
    /// The currently active predictor (chosen by the factory).
    private let predictor: ScorePredictor = ScorePredictorFactory.active

    /// 同科目错题(用于 mistakeContext)
    /// Same-subject mistakes (for building mistakeContext).
    private var subjectMistakes: [MistakeNote] {
        container.mistakeRepo.filteredMistakeSets
            .filter { $0.subject == exam.subject }
    }

    /// 调用预测器得出结果(每次访问都会重算;无数据时为 nil)
    /// The predictor result (recomputed on every access; nil when there's not enough data).
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
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            ScorePredictionHeaderCard(
                                title: exam.name,
                                subtitle: exam.subject.localized(),
                                date: exam.examDate,
                                engineName: predictor.engineName
                            )

                            SingleSubjectPredictionContent(
                                exam: exam,
                                history: history,
                                result: result,
                                fullScore: fullScore,
                                subjectMistakes: subjectMistakes,
                                showingDetail: $showingDetail
                            )
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    }
                } else {
                    emptyState
                }
            }
            .navigationTitle("Score Prediction".localized())
            .navigationBarTitleDisplayMode(.inline)
            .llmDebugButton(caller: "ScorePrediction-Subject")
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

    /// 数据不足时的占位视图
    /// Placeholder view shown when there isn't enough data.
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

// MARK: - 综合考试预测 Sheet
// MARK: - Comprehensive exam prediction sheet

/// 综合考试预测 Sheet
/// Comprehensive exam prediction sheet.
struct ComprehensiveScorePredictionSheet: View {
    let target: ComprehensivePredictionTarget
    let onDismiss: () -> Void

    @EnvironmentObject var envManager: AppEnvironmentManager

    var body: some View {
        NavigationStack {
            ScrollView {
                ComprehensivePredictionContent(target: target)
                    .padding(.horizontal)
                    .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Score Prediction".localized())
            .navigationBarTitleDisplayMode(.inline)
            .llmDebugButton(caller: "ScorePrediction-Comprehensive")
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
}
