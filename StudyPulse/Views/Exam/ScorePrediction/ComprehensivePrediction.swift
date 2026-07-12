//
//  ComprehensivePrediction.swift
//  StudyPulse
//
//  Created for the Exam "预测" button feature.
//

import SwiftUI

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

struct ComprehensivePredictionContent: View {
    let target: ComprehensivePredictionTarget

    @EnvironmentObject var envManager: AppEnvironmentManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 总分卡
            totalCard

            // 各科卡片
            ForEach(target.perSubject, id: \.subject) { item in
                perSubjectCard(item: item)
            }

            // AI 预测卡片
            PredictionDiscussionEntryView(context: .comprehensive(target: target))
        }
    }

    // MARK: - 子卡片

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
