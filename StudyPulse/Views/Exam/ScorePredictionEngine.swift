//
//  ScorePredictionEngine.swift
//  StudyPulse
//
//  本地纯 Swift 实现的成绩预测引擎。
//  默认使用基于最近 N 次同科成绩的简单线性回归 + 95% 预测区间。
//  预留 `CoreMLScorePredictor` 接入点供未来替换为机器学习模型。
//
//  Created for the Exam "预测" button feature.
//

import Foundation
import SwiftUI
import os

// MARK: - 预测结果模型

/// 单次成绩预测的结果。
/// Score prediction result returned by `ScorePredictor.predict(...)`.
///
/// - predicted: 点估计 (point estimate)
/// - lowerBound / upperBound: 95% 置信区间 (95% prediction interval)
/// - slope: 拟合斜率（分/天），`nil` 表示样本不足无法拟合
/// - rSquared: 决定系数 R²，[0, 1] 越大说明拟合越好
/// - usedSampleSize: 实际参与回归的样本数
/// - lastActual / lastActualDate: 最近一次实际成绩（与 predicted 形成对比）
/// - dataRange: 参与回归数据的日期范围
struct ScorePredictionResult: Equatable {
    let subject: String
    let fullScore: Double
    let predicted: Double
    let lowerBound: Double
    let upperBound: Double
    let confidenceLevel: Double
    let slope: Double?
    let rSquared: Double?
    let usedSampleSize: Int
    let lastActual: Double?
    let lastActualDate: Date?
    let dataRange: ClosedRange<Date>?

    /// 是否数据足以给出置信区间（n >= 3 且非退化样本）
    var hasConfidenceInterval: Bool {
        usedSampleSize >= 3 && (upperBound - lowerBound).isFinite && upperBound > lowerBound
    }

    /// 相对最近一次实际成绩的预计变化（可正可负）
    /// Expected change relative to last actual score (can be positive or negative).
    var delta: Double? {
        guard let last = lastActual else { return nil }
        return predicted - last
    }
}

// MARK: - 预测器协议

/// 成绩预测器协议。
/// Score predictor interface.
/// 设计目标：默认实现是纯本地的线性回归（无外部依赖）；
/// 未来可以通过 `ScorePredictorFactory` 切换到 Core ML 模型实现，
/// 而无需修改调用方代码。
protocol ScorePredictor: Sendable {
    /// 引擎类型标识（用于 UI 展示 / 调试）
    var engineName: String { get }

    /// 给定历史成绩和目标考试日期，预测下一次考试分数。
    /// - Parameters:
    ///   - history: 同科目的历史成绩（任意顺序）
    ///   - examDate: 下一次考试日期
    ///   - fullScore: 科目满分
    /// - Returns: 预测结果。数据不足（< 2 条）时返回 nil。
    func predict(
        history: [Grade],
        examDate: Date,
        fullScore: Double
    ) -> ScorePredictionResult?
}

// MARK: - 线性回归预测器（默认实现）

/// 基于最小二乘的简单线性回归预测器。
/// 公式：
///   x = 距首条成绩的天数
///   y = 分数
///   β = Sxy / Sxx   (slope)
///   α = mean(y) − β·mean(x)  (intercept)
///   ŷ = α + β·x_new
///   s = sqrt( SSE / (n−2) )  (residual standard error)
///   95% PI: ŷ ± t_{n−2, .025} · s · sqrt( 1 + 1/n + (x_new−x̄)² / Sxx )
struct LinearRegressionScorePredictor: ScorePredictor {
    let engineName: String = "Linear Regression"

    /// 最少需要的样本数。低于此值时返回 nil。
    let minimumSampleSize: Int

    /// 最近 N 次（默认 5）。
    let windowSize: Int

    init(windowSize: Int = 5, minimumSampleSize: Int = 2) {
        self.windowSize = max(2, windowSize)
        self.minimumSampleSize = max(2, minimumSampleSize)
    }

    func predict(
        history: [Grade],
        examDate: Date,
        fullScore: Double
    ) -> ScorePredictionResult? {
        guard fullScore > 0 else { return nil }

        // 1. 排序 + 截取最近 N 条
        let recent = history
            .sorted { $0.date > $1.date }
            .prefix(windowSize)
            .sorted { $0.date < $1.date }

        guard recent.count >= minimumSampleSize else { return nil }

        // 2. 把日期转换成"距首条成绩的天数"，x = Double(天数)
        let t0 = recent.first!.date
        let xs: [Double] = recent.map { $0.date.timeIntervalSince(t0) / 86400.0 }
        let ys: [Double] = recent.map { max(0, min($0.score, fullScore)) }
        let n = Double(recent.count)

        // 3. 累加量
        let meanX = xs.reduce(0, +) / n
        let meanY = ys.reduce(0, +) / n
        var sxx: Double = 0
        var sxy: Double = 0
        for i in 0..<recent.count {
            let dx = xs[i] - meanX
            sxx += dx * dx
            sxy += dx * (ys[i] - meanY)
        }

        // 退化情况：所有 x 相同（同一日期）或 y 全相等
        let slope: Double? = sxx > 1e-9 ? sxy / sxx : (ys.allSatisfy { abs($0 - meanY) < 1e-9 } ? 0 : nil)
        let intercept: Double = meanY - (slope ?? 0) * meanX

        // 4. 预测 x_new
        let xNew = max(0, examDate.timeIntervalSince(t0) / 86400.0)
        var yHat = intercept + (slope ?? 0) * xNew
        yHat = max(0, min(yHat, fullScore))

        // 5. 残差平方和 + 决定系数
        var sse: Double = 0
        var sst: Double = 0
        for i in 0..<recent.count {
            let yi = ys[i]
            let yFit = intercept + (slope ?? 0) * xs[i]
            sse += (yi - yFit) * (yi - yFit)
            sst += (yi - meanY) * (yi - meanY)
        }
        let rSquared: Double? = sst > 1e-9 ? max(0, min(1, 1 - sse / sst)) : nil

        // 6. 95% 预测区间
        let df = recent.count - 2
        let tCrit = ScorePredictorMath.tValue95(df: df)
        var lower = yHat
        var upper = yHat

        if df > 0, sxx > 1e-9 {
            let s = (sse / Double(df)).squareRoot()
            if s.isFinite {
                let se = s * (1.0 + 1.0 / n + (xNew - meanX) * (xNew - meanX) / sxx).squareRoot()
                let halfWidth = tCrit * se
                lower = max(0, yHat - halfWidth)
                upper = min(fullScore, yHat + halfWidth)
            }
        } else if df <= 0 {
            // n <= 2：无法计算标准误差，退化为仅点估计
            lower = yHat
            upper = yHat
        }

        // 7. 最后一次实际成绩（从全集取，不受 windowSize 影响）
        let lastActualEntry = history.max(by: { $0.date < $1.date })

        // 8. 数据范围
        let firstDate = recent.first!.date
        let lastDate = recent.last!.date
        let dataRange: ClosedRange<Date>? = firstDate <= lastDate ? (firstDate...lastDate) : nil

        return ScorePredictionResult(
            subject: recent.first?.subject ?? "",
            fullScore: fullScore,
            predicted: yHat,
            lowerBound: lower,
            upperBound: upper,
            confidenceLevel: 0.95,
            slope: slope,
            rSquared: rSquared,
            usedSampleSize: recent.count,
            lastActual: lastActualEntry?.score,
            lastActualDate: lastActualEntry?.date,
            dataRange: dataRange
        )
    }
}

// MARK: - Core ML 预测器（占位 / 未启用）

/// Core ML 模型预测器（占位实现，目前未启用）。
/// Core ML model-based predictor (placeholder, not enabled yet)。
///
/// 接入步骤（未来）：
///   1. 在 Xcode 中拖入训练好的 `ScorePredictor.mlmodel`
///   2. Xcode 会自动生成 `ScorePredictorInput` / `ScorePredictorOutput` 类型
///   3. 在本类的 `predict(...)` 里实例化 `ScorePredictor` 并调用 `prediction(...)`
///   4. 把模型输出映射成 `ScorePredictionResult` 即可
///   5. 在 `ScorePredictorFactory.active` 里把 `.linearRegression(...)` 换成 `.coreML(...)`
struct CoreMLScorePredictor: ScorePredictor {
    let engineName: String = "Core ML (disabled)"

    /// 故意保留为 nil，方便 UI 在选择本引擎时显示"暂未启用"占位。
    /// Intentionally returns nil so the UI can show a "not yet enabled" placeholder
    /// when this engine is selected.
    func predict(
        history: [Grade],
        examDate: Date,
        fullScore: Double
    ) -> ScorePredictionResult? {
        Log.prediction.warning("CoreMLScorePredictor 被调用但尚未启用 / Core ML predictor invoked but not yet enabled. history=\(history.count, privacy: .public)")
        return nil
    }
}

// MARK: - 预测器工厂

/// 预测器工厂：暴露当前激活的预测器。
/// 当前默认始终返回 `LinearRegressionScorePredictor`。
/// 保留 `coreML` 选项以便未来切换。
enum ScorePredictorKind: String, CaseIterable, Identifiable {
    case linearRegression
    case coreML

    var id: String { rawValue }

    @MainActor var displayName: String {
        switch self {
        case .linearRegression: return "Linear Regression".localized()
        case .coreML:           return "Core ML (Beta)".localized()
        }
    }

    @MainActor var footnote: String {
        switch self {
        case .linearRegression:
            return "Local regression, no network required.".localized()
        case .coreML:
            return "On-device ML model, currently disabled.".localized()
        }
    }
}

enum ScorePredictorFactory {
    /// 当前激活的预测器。默认使用线性回归。
    /// Active predictor. Defaults to linear regression.
    static let active: ScorePredictor = LinearRegressionScorePredictor(windowSize: 5)

    /// 给定 kind 返回对应预测器实例（仅用于调试 / 设置面板演示）。
    /// Build a predictor for a given kind (debug / settings preview only).
    static func predictor(for kind: ScorePredictorKind) -> ScorePredictor {
        switch kind {
        case .linearRegression:
            return LinearRegressionScorePredictor(windowSize: 5)
        case .coreML:
            return CoreMLScorePredictor()
        }
    }
}

// MARK: - 数学工具

/// 集中放置预测相关的纯函数。
enum ScorePredictorMath {
    /// 95% 置信水平（双侧）下，自由度 df 对应的 t 分位数。
    /// 覆盖 df = 1 ... 30。df > 30 时使用 1.96（正态近似）。
    /// df = 0 或负数视为无穷（不应用 CI）。
    static func tValue95(df: Int) -> Double {
        switch df {
        case 1:  return 12.706
        case 2:  return 4.303
        case 3:  return 3.182
        case 4:  return 2.776
        case 5:  return 2.571
        case 6:  return 2.447
        case 7:  return 2.365
        case 8:  return 2.306
        case 9:  return 2.262
        case 10: return 2.228
        case 11: return 2.201
        case 12: return 2.179
        case 13: return 2.160
        case 14: return 2.145
        case 15: return 2.131
        case 16: return 2.120
        case 17: return 2.110
        case 18: return 2.101
        case 19: return 2.093
        case 20: return 2.086
        case 21: return 2.080
        case 22: return 2.074
        case 23: return 2.069
        case 24: return 2.064
        case 25: return 2.060
        case 26: return 2.056
        case 27: return 2.052
        case 28: return 2.048
        case 29: return 2.045
        case 30: return 2.042
        default: return 1.96 // df > 30 或 < 0 时回退到正态分位数
        }
    }
}

// MARK: - 错题差距分析

/// 错题推荐条目：为达到目标分，用户应当复习的错题。
/// A single mistake (or mistake set) recommended for review to bridge a score gap.
struct MistakeRecommendation: Identifiable, Equatable {
    let id: UUID
    let title: String
    let subject: String
    let date: Date
    let masteryScore: Double   // 0-1
    let exposureCount: Int
    let priority: Double       // 内部打分，越大越靠前
}

/// 错题差距分析：根据目标分与预测区间下界，挑选最值得复习的错题。
/// Mistake gap analyzer: pick the most impactful mistakes to review in order
/// to reach a target score.
enum MistakeGapAnalyzer {
    /// 输出推荐错题列表（按 priority 降序，最多 `maxCount` 条）。
    /// - Parameters:
    ///   - mistakes: 候选错题（已按科目过滤）
    ///   - targetScore: 用户设定的目标分（如 130）
    ///   - maxCount: 最多返回多少条
    static func recommendations(
        mistakes: [MistakeNote],
        targetScore: Double,
        maxCount: Int = 5
    ) -> [MistakeRecommendation] {
        let now = Date()
        // priority = 时间新鲜度 (0-1) * 0.4 + 掌握度低 (1-mastery) * 0.4 + 曝光次数归一化 * 0.2
        let maxExposure = max(1, mistakes.map(\.exposureCount).max() ?? 1)

        let scored: [MistakeRecommendation] = mistakes.map { m in
            let days = max(0, now.timeIntervalSince(m.date) / 86400.0)
            // 半衰期 30 天：exp(-days/30) 越新越接近 1
            let recency = exp(-days / 30.0)
            let exposureNorm = Double(m.exposureCount) / Double(maxExposure)
            let masteryLow = 1.0 - max(0, min(1, m.masteryScore))
            let priority = recency * 0.4 + masteryLow * 0.4 + exposureNorm * 0.2
            return MistakeRecommendation(
                id: m.id,
                title: m.title,
                subject: m.subject,
                date: m.date,
                masteryScore: m.masteryScore,
                exposureCount: m.exposureCount,
                priority: priority
            )
        }
        .sorted { $0.priority > $1.priority }
        return Array(scored.prefix(maxCount))
    }

    /// 计算还需要弥补的分数差（>= 0）。
    /// gap = max(0, target - predicted_lower_bound)
    /// 若用户的目标分已经低于预测下界，认为差距为 0（"无压力"）。
    static func scoreGap(target: Double, result: ScorePredictionResult) -> Double {
        let safeTarget = max(0, target)
        let gap = safeTarget - result.lowerBound
        return max(0, gap)
    }
}
