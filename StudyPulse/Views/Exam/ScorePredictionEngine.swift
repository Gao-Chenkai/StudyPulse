//
//  ScorePredictionEngine.swift
//  StudyPulse
//
//  本地纯 Swift 实现的成绩预测引擎。
//  v1.4 起默认使用 **二元加权线性回归**(bivariate WLS):
//      score = α + β·date + γ·cumulative_exposure
//    配合 EWMA(指数加权移动平均)在 60 天硬截窗口内拟合;
//    平均掌握度(mastery)用于按 (1 - 0.4·mastery) 缩窄 95% 预测区间;
//    残差 > 3σ 的最近一次考试会被标记为离群点(outlier)并在 UI 中提示用户。
//  预留 `CoreMLScorePredictor` 接入点供未来替换为机器学习模型。
//
//  Created for the Exam "预测" button feature.
//

import Foundation
import SwiftUI
import os

// MARK: - 错题上下文(由调用方提供,引擎不直接访问 MistakeRepository)

/// 错题复习上下文:预测引擎所需的"用户做了多少错题复习 + 平均掌握度"。
/// Mistake review context consumed by the score predictor.
/// Sheet 层从 `MistakeRepository` 聚合后传入;引擎本身不访问 Repository
/// (保持与数据层的解耦,便于未来替换为其他数据源)。
struct MistakeContext: Equatable {
    /// 同科目所有错题的所有 `masteryHistory` 时间戳(用于累积曝光 e(t))
    /// All `masteryHistory` timestamps across the subject's mistakes.
    let reviewTimestamps: [Date]
    /// 同科目错题的平均掌握度(0-1);用于按 (1 - 0.4·mastery) 缩窄 CI
    /// Average mastery across the subject's mistakes (0-1).
    let averageMastery: Double
    /// 进入过复习流程的错题条数(仅 UI 展示用)
    /// Number of mistakes that have been reviewed at least once.
    let reviewedMistakeCount: Int
    /// 总曝光次数(所有错题 exposureCount 之和;仅 UI 展示用)
    /// Total exposure count (sum of all mistakes' exposureCount).
    let totalExposureCount: Int

    static let empty = MistakeContext(
        reviewTimestamps: [],
        averageMastery: 0,
        reviewedMistakeCount: 0,
        totalExposureCount: 0
    )

    /// e(t) = 在 t 时刻(含)的累计复习次数
    /// Cumulative review count at time t.
    /// O(log n) 实现:先排序,再用 `firstIndex(where: { $0 > t })` 取左边界。
    func cumulativeExposure(at t: Date) -> Double {
        guard !reviewTimestamps.isEmpty else { return 0 }
        let sorted = reviewTimestamps.sorted()
        // upperBound:第一个 > t 的索引 = 满足 <= t 的元素数量
        let idx = sorted.firstIndex(where: { $0 > t }) ?? sorted.endIndex
        return Double(idx)
    }

    /// 当前累计复习次数(用 examDate 作为"now")
    /// Current cumulative exposure (using examDate as the snapshot time).
    func currentCumulativeExposure(asOf examDate: Date) -> Double {
        cumulativeExposure(at: examDate)
    }

    /// 从错题集合构建上下文(同科目过滤由调用方负责)。
    /// Build a context from a list of mistakes. Caller is responsible for
    /// subject filtering.
    /// - Parameter mistakes: 候选错题(通常已按 subject / phase 过滤)
    /// - Returns: 聚合后的 `MistakeContext`
    static func build(from mistakes: [MistakeNote]) -> MistakeContext {
        guard !mistakes.isEmpty else { return .empty }
        let timestamps = mistakes.flatMap { $0.masteryHistory.map(\.timestamp) }
        let reviewedCount = mistakes.filter { $0.exposureCount > 0 }.count
        let totalExposure = mistakes.map(\.exposureCount).reduce(0, +)
        let avgMastery = mistakes.map(\.masteryScore).reduce(0, +) / Double(mistakes.count)
        return MistakeContext(
            reviewTimestamps: timestamps,
            averageMastery: max(0, min(1, avgMastery)),
            reviewedMistakeCount: reviewedCount,
            totalExposureCount: totalExposure
        )
    }
}

// MARK: - 预测结果模型

/// 单次成绩预测的结果(v1.4)。
/// Score prediction result returned by `ScorePredictor.predict(...)`.
///
/// - predicted: 点估计 (point estimate)
/// - lowerBound / upperBound: 95% 置信区间 (95% prediction interval)
/// - slope: 时间斜率 β(分/天);`nil` 表示样本不足无法拟合
/// - exposureLift / gamma: 错题曝光斜率 γ(分/次复习);`nil` 表示无错题数据
///   或样本不足以拟合二元模型
/// - rSquared: 决定系数 R²,[0, 1] 越大说明拟合越好
/// - usedSampleSize: 实际参与回归的样本数
/// - lastActual / lastActualDate: 最近一次实际成绩(与 predicted 形成对比)
/// - dataRange: 参与回归数据的日期范围
/// - windowDays: 硬截窗口(天),默认 60
/// - halfLifeDays: EWMA 半衰期(天),默认 30
/// - halfWidth: 95% 预测区间半宽(即"误差范围 ±X 分"的 X)
/// - rawHalfWidth: mastery 缩窄之前的原始半宽(供 UI 解释用)
/// - masteryCIMultiplier: mastery 对 halfWidth 的缩放系数(0.6-1.0)
/// - avgMastery: 传入的平均掌握度(0-1,0 = 未复习 / 无错题)
/// - eNew: 预测时点(examDate)的累计曝光
/// - outlierWarning: 最近一次考试残差 > 3σ 时的离群点告警
/// - regressorCount: 拟合参数个数(2 = 仅日期,3 = 日期 + 曝光)
struct ScorePredictionResult: Equatable {
    let subject: String
    let fullScore: Double
    let predicted: Double
    let lowerBound: Double
    let upperBound: Double
    let confidenceLevel: Double
    let slope: Double?
    let exposureLift: Double?         // v1.4:γ(分/次复习)
    let rSquared: Double?
    let usedSampleSize: Int
    let regressorCount: Int           // v1.4:2 或 3
    let lastActual: Double?
    let lastActualDate: Date?
    let dataRange: ClosedRange<Date>?
    let windowDays: Double
    let halfLifeDays: Double
    let halfWidth: Double             // mastery 缩窄后
    let rawHalfWidth: Double          // v1.4:缩窄前
    let masteryCIMultiplier: Double   // v1.4:0.6-1.0
    let avgMastery: Double            // v1.4:0-1
    let eNew: Double                  // v1.4:预测时点累计曝光
    let outlierWarning: OutlierWarning?

    /// 是否数据足以给出置信区间(n >= 3 且非退化样本)
    var hasConfidenceInterval: Bool {
        usedSampleSize >= 3 && (upperBound - lowerBound).isFinite && upperBound > lowerBound
    }

    /// 相对最近一次实际成绩的预计变化(可正可负)
    /// Expected change relative to last actual score (can be positive or negative).
    var delta: Double? {
        guard let last = lastActual else { return nil }
        return predicted - last
    }

    /// 是否拟合了带错题曝光的二元模型
    var usesExposureRegressor: Bool { regressorCount == 3 && exposureLift != nil }
}

/// 离群点告警:最近一次考试残差超过阈值(默认 3σ)。
/// Outlier warning: the most recent exam's residual exceeded the sigma threshold
/// (default 3σ) relative to the fitted regression, suggesting the score may have
/// been affected by special factors (illness, bad day, etc.) that distort the prediction.
struct OutlierWarning: Equatable {
    let date: Date
    let score: Double
    let fittedValue: Double   // 拟合线在该日期的预测值
    let residual: Double      // score - fittedValue
    let residualStd: Double   // 残差标准差 σ
    let zScore: Double        // residual / residualStd
    let sigmaThreshold: Double
}

// MARK: - 预测器协议

/// 成绩预测器协议。
/// Score predictor interface.
/// 设计目标:默认实现是纯本地的二元加权回归(无外部依赖);
/// 未来可以通过 `ScorePredictorFactory` 切换到 Core ML 模型实现,
/// 而无需修改调用方代码。
protocol ScorePredictor: Sendable {
    /// 引擎类型标识(用于 UI 展示 / 调试)
    var engineName: String { get }

    /// 给定历史成绩 + 错题复习上下文,预测下一次考试分数。
    /// - Parameters:
    ///   - history: 同科目的历史成绩(任意顺序)
    ///   - mistakeContext: 同科目的错题复习上下文(可空;为空时退化为单变量回归)
    ///   - examDate: 下一次考试日期
    ///   - fullScore: 科目满分
    /// - Returns: 预测结果。数据不足(< 2 条)时返回 nil。
    func predict(
        history: [Grade],
        mistakeContext: MistakeContext?,
        examDate: Date,
        fullScore: Double
    ) -> ScorePredictionResult?
}

// MARK: - 3 变量加权最小二乘(Cramer's rule 闭式解)

/// 3 变量加权最小二乘闭式求解器(给 score = α + β·x + γ·e)。
/// 求解 A · θ = b,其中:
///   A = X'WX(3×3 设计矩阵),θ = [α, β, γ]ᵀ,b = X'Wy
///   X = [1, x, e]ᵀ(行),W = diag(w)
/// 设计矩阵:
///   [ Σw,   Σw·x, Σw·e   ]
///   [ Σw·x, Σw·x²,Σw·x·e ]
///   [ Σw·e, Σw·x·e,Σw·e² ]
///
/// 使用 Cramer's rule 3×3 闭式 + 3×3 解析求逆(adjugate)以计算
/// "x_new' · (X'WX)⁻¹ · x_new" (leverage,用于预测区间)。
/// 全部为 O(n) 计算,无矩阵库依赖。
enum WeightedLeastSquares3 {
    /// 11 个加权一阶 / 二阶矩,集中计算一次以避免重复遍历
    struct Sums {
        let W: Double       // Σw
        let Sx: Double      // Σw·x
        let Se: Double      // Σw·e
        let Sy: Double      // Σw·y
        let Sxx: Double     // Σw·x²
        let See: Double     // Σw·e²
        let Sxe: Double     // Σw·x·e
        let Sxy: Double     // Σw·x·y
        let Sey: Double     // Σw·e·y
    }

    /// 解
    struct Solution {
        let alpha: Double
        let beta: Double
        let gamma: Double
        let detA: Double
        /// 伴随矩阵 adj(A)(3×3)。A⁻¹ = adj(A)ᵀ / detA。
        let adjugate: [Double]  // 9 元素,row-major
    }

    /// 计算加权一阶/二阶矩
    static func sums(xs: [Double], es: [Double], ys: [Double], weights: [Double]) -> Sums {
        precondition(xs.count == es.count && xs.count == ys.count && xs.count == weights.count)
        var W: Double = 0, Sx: Double = 0, Se: Double = 0, Sy: Double = 0
        var Sxx: Double = 0, See: Double = 0, Sxe: Double = 0
        var Sxy: Double = 0, Sey: Double = 0
        for i in 0..<xs.count {
            let x = xs[i], e = es[i], y = ys[i], w = weights[i]
            W  += w
            Sx += w * x
            Se += w * e
            Sy += w * y
            Sxx += w * x * x
            See += w * e * e
            Sxe += w * x * e
            Sxy += w * x * y
            Sey += w * e * y
        }
        return Sums(W: W, Sx: Sx, Se: Se, Sy: Sy, Sxx: Sxx, See: See, Sxe: Sxe, Sxy: Sxy, Sey: Sey)
    }

    /// Cramer's rule 3×3 闭式解。detA 接近 0 时返回 nil(设计矩阵奇异)。
    static func solve(sums s: Sums) -> Solution? {
        // 矩阵元素(对称):
        //   a00=W,  a01=Sx,  a02=Se
        //   a10=Sx, a11=Sxx, a12=Sxe
        //   a20=Se, a21=Sxe, a22=See
        // 右手边:
        //   b0=Sy, b1=Sxy, b2=Sey
        let detA = s.W  * (s.Sxx * s.See - s.Sxe * s.Sxe)
                 - s.Sx * (s.Sx  * s.See - s.Sxe * s.Se)
                 + s.Se * (s.Sx  * s.Sxe - s.Sxx * s.Se)
        guard abs(detA) > 1e-9 else { return nil }

        // 替换 col 0(解 α)
        let detA_alpha = s.Sy * (s.Sxx * s.See - s.Sxe * s.Sxe)
                       - s.Sx * (s.Sxy * s.See - s.Sxe * s.Sey)
                       + s.Se * (s.Sxy * s.Sxe - s.Sxx * s.Sey)
        // 替换 col 1(解 β)
        let detA_beta  = s.W  * (s.Sxy * s.See - s.Sxe * s.Sey)
                       - s.Sy * (s.Sx  * s.See - s.Sxe * s.Se)
                       + s.Se * (s.Sx  * s.Sey - s.Sxy * s.Se)
        // 替换 col 2(解 γ)
        let detA_gamma = s.W  * (s.Sxx * s.Sey - s.Sxy * s.Sxe)
                       - s.Sx * (s.Sxx * s.Sey - s.Sxy * s.Se)
                       + s.Sy * (s.Sxx * s.Se  - s.Sx  * s.Sxe)

        let alpha = detA_alpha / detA
        let beta  = detA_beta  / detA
        let gamma = detA_gamma / detA

        // 3×3 对称矩阵的伴随矩阵 adj(A)(用于解析求逆)
        // cofactor[i][j] = (-1)^(i+j) · minor(i,j)
        // adj(A) = cofactorᵀ
        // row 0: [M00, -M01,  M02]  (M01 = M10 因对称)
        // row 1: [-M10, M11, -M12]
        // row 2: [M02, -M12,  M22]
        let M00 = s.Sxx * s.See - s.Sxe * s.Sxe
        let M11 = s.W   * s.See - s.Se  * s.Se
        let M22 = s.W   * s.Sxx - s.Sx  * s.Sx
        let M01 = s.Sx  * s.See - s.Sxe * s.Se
        let M02 = s.Sx  * s.Sxe - s.Sxx * s.Se
        let M12 = s.W   * s.Sxe - s.Sx  * s.Se
        let adj: [Double] = [
            M00,  -M01,  M02,
            -M01,  M11, -M12,
             M02, -M12,  M22
        ]

        return Solution(
            alpha: alpha, beta: beta, gamma: gamma,
            detA: detA, adjugate: adj
        )
    }

    /// 在 (xNew, eNew) 处的 leverage:
    ///   leverage = x_new' · A⁻¹ · x_new = x_new' · adjᵀ · x_new / detA
    ///   x_new = [1, xNew, eNew]
    ///   adjᵀ = adj(对称矩阵的转置仍 = adj 本身,因为 adj[i][j] = -M_ji / ...,
    ///         实际计算时按 cofactor 矩阵的转置取)
    static func leverage(xNew: Double, eNew: Double, adj: [Double], detA: Double) -> Double {
        // adj 是 row-major 的 3×3 矩阵
        // x_new = [1, xNew, eNew]
        // x_newᵀ · adj = [1·adj[0,0] + xNew·adj[1,0] + eNew·adj[2,0],
        //                 1·adj[0,1] + xNew·adj[1,1] + eNew·adj[2,1],
        //                 1·adj[0,2] + xNew·adj[1,2] + eNew·adj[2,2]]
        // (再点乘 x_new)/detA
        // adj 是 cofactor 矩阵(未转置);adjᵀ = transpose
        // 我们的 adj 数组实际上是:adj[3i+j] = cofactor[i][j](cofactor 未转置)
        // 严格说 A⁻¹ = adj(A)ᵀ / detA,这里 cofactor 矩阵的转置就是 adj(A)。
        // 为简洁,我们直接计算 x_new' · cofactor · x_new / detA,等价。
        let t0 = 1.0 * adj[0] + xNew * adj[3] + eNew * adj[6]
        let t1 = 1.0 * adj[1] + xNew * adj[4] + eNew * adj[7]
        let t2 = 1.0 * adj[2] + xNew * adj[5] + eNew * adj[8]
        let xTAx = 1.0 * t0 + xNew * t1 + eNew * t2
        return xTAx / detA
    }
}

// MARK: - EWMA 线性回归预测器(默认实现)

/// EWMA 加权的(2 变量或 3 变量)最小二乘线性回归预测器。
/// 公式:
///   x = 距首条成绩的天数
///   e = 截至该成绩日期的累计错题复习次数(cumulative exposure)
///   y = 分数
///   w_i = exp(-(x_max - x_i) / halfLife)   (EWMA 权重,越近越大)
///
///   3 变量 WLS(score = α + β·x + γ·e,默认):
///     求解 X'WX · θ = X'Wy
///     X = [1, x, e]ᵀ;θ = [α, β, γ]ᵀ
///     闭式解:Cramer's rule 3×3 闭式(见 WeightedLeastSquares3.solve)
///     残差标准差: s = sqrt( SSE / (n−3) ),SSE = Σ (y_i − ŷ_i)²
///     95% PI: ŷ ± t_{n−3, .025} · s · sqrt( 1 + leverage )
///       leverage = x_new' · (X'WX)⁻¹ · x_new  (解析 3×3 求逆)
///
///   2 变量 WLS(score = α + β·x,fallback):n<3 或错题无数据或设计矩阵退化时
///     β = Sxy / Sxx   (slope)
///     α = mean_w(y) − β·mean_w(x)  (intercept)
///     95% PI: ŷ ± t_{n−2, .025} · s · sqrt( 1 + 1/n + (x_new−x̄_w)² / Sxx_w )
///
///   mastery 缩窄 CI(v1.4): halfWidth *= (1 − 0.4 · avgMastery)
///     mastery = 0 → 系数 1.0(全宽);mastery = 1.0 → 系数 0.6(缩窄 40%)
///
///   离群点检测: 若最近一次考试残差 |r_last| > 3s → 视为异常
struct LinearRegressionScorePredictor: ScorePredictor {
    let engineName: String = "EWMA Bivariate Regression"

    /// EWMA 半衰期(天)。权重衰减:w_i = exp(-(x_max - x_i) / halfLife)
    /// 30 天半衰期意味着:0 天前=1.0、30 天前≈0.5、60 天前≈0.25、90 天前≈0.125
    let halfLifeDays: Double

    /// 硬截窗口(天)。超过该窗口的历史成绩直接丢弃,避免远古数据干扰。
    let maxWindowDays: Double

    /// 最少需要的样本数。低于此值时返回 nil。
    let minimumSampleSize: Int

    /// 离群点判定阈值(残差标准差的倍数),默认 3σ(经典 3σ 准则)
    let outlierSigma: Double

    /// mastery 对 CI 的最大缩窄比例。
    /// 0.4 意味着:mastery = 1.0 时 CI 半宽变为 60%(缩窄 40%)。
    let masteryMaxShrink: Double

    init(
        halfLifeDays: Double = 30,
        maxWindowDays: Double = 60,
        minimumSampleSize: Int = 2,
        outlierSigma: Double = 3.0,
        masteryMaxShrink: Double = 0.4
    ) {
        self.halfLifeDays = max(7, halfLifeDays)
        self.maxWindowDays = max(self.halfLifeDays * 2, maxWindowDays)
        self.minimumSampleSize = max(2, minimumSampleSize)
        self.outlierSigma = max(1.0, outlierSigma)
        self.masteryMaxShrink = max(0.0, min(0.8, masteryMaxShrink))
    }

    func predict(
        history: [Grade],
        mistakeContext: MistakeContext?,
        examDate: Date,
        fullScore: Double
    ) -> ScorePredictionResult? {
        guard fullScore > 0 else { return nil }

        // 1. 选 EWMA 权重锚点:用"最近一次成绩的日期"(不是 examDate,也不是 now),
        //    保证同一条 history 多次调用结果稳定;之后再用 maxWindowDays 做硬截。
        guard let anchor = history.map(\.date).max() else { return nil }
        let cutoff = anchor.addingTimeInterval(-maxWindowDays * 86400.0)
        let recent = history
            .filter { $0.date >= cutoff }
            .sorted { $0.date < $1.date }
        guard recent.count >= minimumSampleSize else { return nil }

        // 2. EWMA 权重(基于 anchor):0 天前 = 1.0,halfLife 天前 ≈ 0.5
        let weights: [Double] = recent.map { g in
            let interval = anchor.timeIntervalSince(g.date)
            let daysBefore = max(0.0, interval / 86400.0)
            return exp(-daysBefore / halfLifeDays)
        }
        let weightSum = weights.reduce(0, +)

        // 3. 日期 → 距首条成绩的天数,x = Double(天数)
        let t0 = recent.first!.date
        let xs: [Double] = recent.map { $0.date.timeIntervalSince(t0) / 86400.0 }
        let ys: [Double] = recent.map { max(0, min($0.score, fullScore)) }
        let n = Double(recent.count)

        // 4. 错题累计曝光 e_i(截至第 i 条成绩的日期)
        let ctx = mistakeContext ?? .empty
        let hasExposureData = !ctx.reviewTimestamps.isEmpty
        let es: [Double] = recent.map { g in
            hasExposureData ? ctx.cumulativeExposure(at: g.date) : 0
        }
        let eAllZero = es.allSatisfy { $0 == 0 }

        // 5. 决定用 3 变量还是 2 变量 WLS
        //    3 变量: n >= 3 && 有错题数据 && 设计矩阵非退化
        //    2 变量: 其它情况(fallback,γ = 0)
        let useBivariate = recent.count >= 3 && hasExposureData && !eAllZero

        // 6. 解 WLS
        let xNew = max(0, examDate.timeIntervalSince(t0) / 86400.0)
        let eNew: Double = hasExposureData ? ctx.currentCumulativeExposure(asOf: examDate) : 0

        var alpha: Double = 0
        var beta: Double = 0
        var gamma: Double? = nil  // 仅 3 变量时有值
        var leverageNew: Double = 0  // x_new' · (X'WX)⁻¹ · x_new,用于 PI

        if useBivariate {
            // --- 3 变量 WLS(显式 Cramer's rule) ---
            let sums = WeightedLeastSquares3.sums(xs: xs, es: es, ys: ys, weights: weights)
            if let sol = WeightedLeastSquares3.solve(sums: sums) {
                alpha = sol.alpha
                beta = sol.beta
                gamma = sol.gamma
                // leverage: x_new' · adj(A) · x_new / detA
                leverageNew = WeightedLeastSquares3.leverage(
                    xNew: xNew, eNew: eNew, adj: sol.adjugate, detA: sol.detA
                )
            } else {
                // 设计矩阵奇异 → 退化为 2 变量
                gamma = nil
            }
        }

        if gamma == nil {
            // --- 2 变量 WLS(fallback) ---
            let meanX = zip(xs, weights).map(*).reduce(0, +) / weightSum
            let meanY = zip(ys, weights).map(*).reduce(0, +) / weightSum
            var sxx: Double = 0
            var sxy: Double = 0
            for i in 0..<recent.count {
                let dx = xs[i] - meanX
                sxx += weights[i] * dx * dx
                sxy += weights[i] * dx * (ys[i] - meanY)
            }
            if sxx > 1e-9 {
                beta = sxy / sxx
            } else if ys.allSatisfy({ abs($0 - meanY) < 1e-9 }) {
                beta = 0
            }
            alpha = meanY - beta * meanX
            // leverage ≈ 1/n + (xNew - x̄)² / Sxx
            if sxx > 1e-9 {
                leverageNew = 1.0 / n + (xNew - meanX) * (xNew - meanX) / sxx
            } else {
                leverageNew = 1.0 / n
            }
        }

        // 7. 点估计 ŷ = α + β·xNew + γ·eNew
        let slope: Double? = beta.isFinite ? beta : nil
        let exposureLift: Double? = gamma
        var yHat = alpha + beta * xNew + (gamma ?? 0) * eNew
        yHat = max(0, min(yHat, fullScore))

        // 8. 残差 + 决定系数 R²(未加权残差平方和,便于跨样本解释)
        var sse: Double = 0
        var sst: Double = 0
        var residuals: [Double] = []
        residuals.reserveCapacity(recent.count)
        for i in 0..<recent.count {
            let yi = ys[i]
            let yFit = alpha + beta * xs[i] + (gamma ?? 0) * es[i]
            let r = yi - yFit
            residuals.append(r)
            sse += r * r
            sst += (yi - meanY(ys: ys, weights: weights, wSum: weightSum)) * (yi - meanY(ys: ys, weights: weights, wSum: weightSum))
        }
        let rSquared: Double? = sst > 1e-9 ? max(0, min(1, 1 - sse / sst)) : nil

        // 9. 95% 预测区间 + 原始半宽
        let paramCount = (gamma == nil) ? 2 : 3
        let df = recent.count - paramCount
        let tCrit = ScorePredictorMath.tValue95(df: df)
        var lower = yHat
        var upper = yHat
        var rawHalfWidth: Double = 0

        if df > 0, sse.isFinite {
            let s = (sse / Double(df)).squareRoot()
            if s.isFinite {
                let se = s * (1.0 + leverageNew).squareRoot()
                let h = tCrit * se
                lower = max(0, yHat - h)
                upper = min(fullScore, yHat + h)
                rawHalfWidth = h
            }
        } else if df <= 0 {
            // df <= 0:无法计算标准误差,退化为仅点估计
            lower = yHat
            upper = yHat
        }

        // 10. mastery 缩窄 CI(v1.4 新增)
        //     halfWidth *= (1 - masteryMaxShrink · avgMastery)
        //     mastery 越高 → CI 越窄(更确定);mastery 0 → 不缩窄
        let clampedMastery = max(0.0, min(1.0, ctx.averageMastery))
        let ciMultiplier = 1.0 - masteryMaxShrink * clampedMastery
        let masteryHalfWidth = rawHalfWidth * ciMultiplier
        // 重新计算 lower/upper(以 masteryHalfWidth 为半宽,以 yHat 为中心)
        if rawHalfWidth > 0, df > 0 {
            lower = max(0, yHat - masteryHalfWidth)
            upper = min(fullScore, yHat + masteryHalfWidth)
        }

        // 11. 离群点检测:最近一次考试(weight 最大)残差是否 > 3σ
        var outlierWarning: OutlierWarning? = nil
        if df > 0, let lastResidual = residuals.last {
            let sResid = (sse / Double(df)).squareRoot()
            if sResid.isFinite, sResid > 1e-9, abs(lastResidual) > outlierSigma * sResid {
                let lastIdx = recent.count - 1
                outlierWarning = OutlierWarning(
                    date: recent[lastIdx].date,
                    score: ys[lastIdx],
                    fittedValue: alpha + beta * xs[lastIdx] + (gamma ?? 0) * es[lastIdx],
                    residual: lastResidual,
                    residualStd: sResid,
                    zScore: lastResidual / sResid,
                    sigmaThreshold: outlierSigma
                )
            }
        }

        // 12. 最后一次实际成绩(从全集取,不受窗口影响)
        let lastActualEntry = history.max(by: { $0.date < $1.date })

        // 13. 数据范围
        let firstDate = recent.first!.date
        let lastDate = recent.last!.date
        let dataRange: ClosedRange<Date>? = firstDate <= lastDate ? (firstDate...lastDate) : nil

        let result = ScorePredictionResult(
            subject: recent.first?.subject ?? "",
            fullScore: fullScore,
            predicted: yHat,
            lowerBound: lower,
            upperBound: upper,
            confidenceLevel: 0.95,
            slope: slope,
            exposureLift: exposureLift,
            rSquared: rSquared,
            usedSampleSize: recent.count,
            regressorCount: paramCount,
            lastActual: lastActualEntry?.score,
            lastActualDate: lastActualEntry?.date,
            dataRange: dataRange,
            windowDays: maxWindowDays,
            halfLifeDays: halfLifeDays,
            halfWidth: masteryHalfWidth,
            rawHalfWidth: rawHalfWidth,
            masteryCIMultiplier: ciMultiplier,
            avgMastery: clampedMastery,
            eNew: eNew,
            outlierWarning: outlierWarning
        )
        Log.prediction.info(
            "EWMA predict v1.4: n=\(result.usedSampleSize, privacy: .public), params=\(paramCount, privacy: .public), γ=\(String(format: "%.3f", exposureLift ?? 0), privacy: .public), mastery=\(String(format: "%.2f", clampedMastery), privacy: .public), rawHW=\(String(format: "%.1f", rawHalfWidth), privacy: .public), finalHW=\(String(format: "%.1f", masteryHalfWidth), privacy: .public), outlier=\(outlierWarning != nil, privacy: .public)"
        )
        return result
    }

    /// 辅助:加权均值
    private func meanY(ys: [Double], weights: [Double], wSum: Double) -> Double {
        return zip(ys, weights).map(*).reduce(0, +) / wSum
    }
}

// MARK: - Core ML 预测器(占位 / 未启用)

/// Core ML 模型预测器(占位实现,目前未启用)。
/// Core ML model-based predictor (placeholder, not enabled yet)。
///
/// 接入步骤(未来):
///   1. 在 Xcode 中拖入训练好的 `ScorePredictor.mlmodel`
///   2. Xcode 会自动生成 `ScorePredictorInput` / `ScorePredictorOutput` 类型
///   3. 在本类的 `predict(...)` 里实例化 `ScorePredictor` 并调用 `prediction(...)`
///   4. 把模型输出映射成 `ScorePredictionResult` 即可
///   5. 在 `ScorePredictorFactory.active` 里把 `.linearRegression(...)` 换成 `.coreML(...)`
struct CoreMLScorePredictor: ScorePredictor {
    let engineName: String = "Core ML (disabled)"

    /// 故意保留为 nil,方便 UI 在选择本引擎时显示"暂未启用"占位。
    /// Intentionally returns nil so the UI can show a "not yet enabled" placeholder
    /// when this engine is selected.
    func predict(
        history: [Grade],
        mistakeContext: MistakeContext?,
        examDate: Date,
        fullScore: Double
    ) -> ScorePredictionResult? {
        Log.prediction.warning("CoreMLScorePredictor 被调用但尚未启用 / Core ML predictor invoked but not yet enabled. history=\(history.count, privacy: .public), mistakes=\(mistakeContext?.reviewedMistakeCount ?? 0, privacy: .public)")
        return nil
    }
}

// MARK: - 预测器工厂

/// 预测器工厂:暴露当前激活的预测器。
/// 当前默认始终返回 EWMA 二元(日期 + 错题曝光)回归预测器
/// (60 天硬截 + 30 天半衰期 + 错题累计曝光协变量)。
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
            return "EWMA + mistake exposure bivariate regression, no network required.".localized()
        case .coreML:
            return "On-device ML model, currently disabled.".localized()
        }
    }
}

enum ScorePredictorFactory {
    /// 当前激活的预测器。默认使用 EWMA 二元加权回归
    /// (60 天硬截 + 30 天半衰期 + 错题曝光协变量 + mastery 缩窄 CI)。
    /// Active predictor. Defaults to EWMA bivariate weighted regression.
    static let active: ScorePredictor = LinearRegressionScorePredictor(
        halfLifeDays: 30,
        maxWindowDays: 60,
        masteryMaxShrink: 0.4
    )

    /// 给定 kind 返回对应预测器实例(仅用于调试 / 设置面板演示)。
    /// Build a predictor for a given kind (debug / settings preview only).
    static func predictor(for kind: ScorePredictorKind) -> ScorePredictor {
        switch kind {
        case .linearRegression:
            return LinearRegressionScorePredictor(
                halfLifeDays: 30,
                maxWindowDays: 60,
                masteryMaxShrink: 0.4
            )
        case .coreML:
            return CoreMLScorePredictor()
        }
    }
}

// MARK: - 数学工具

/// 集中放置预测相关的纯函数。
enum ScorePredictorMath {
    /// 95% 置信水平(双侧)下,自由度 df 对应的 t 分位数。
    /// 覆盖 df = 1 ... 30。df > 30 时使用 1.96(正态近似)。
    /// df = 0 或负数视为无穷(不应用 CI)。
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

/// 错题推荐条目:为达到目标分,用户应当复习的错题。
/// A single mistake (or mistake set) recommended for review to bridge a score gap.
struct MistakeRecommendation: Identifiable, Equatable {
    let id: UUID
    let title: String
    let subject: String
    let date: Date
    let masteryScore: Double   // 0-1
    let exposureCount: Int
    let priority: Double       // 内部打分,越大越靠前
}

/// 错题差距分析:根据目标分与预测区间下界,挑选最值得复习的错题。
/// Mistake gap analyzer: pick the most impactful mistakes to review in order
/// to reach a target score.
enum MistakeGapAnalyzer {
    /// 输出推荐错题列表(按 priority 降序,最多 `maxCount` 条)。
    /// - Parameters:
    ///   - mistakes: 候选错题(已按科目过滤)
    ///   - targetScore: 用户设定的目标分(如 130)
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
            // 半衰期 30 天:exp(-days/30) 越新越接近 1
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

    /// 计算还需要弥补的分数差(>= 0)。
    /// gap = max(0, target - predicted_lower_bound)
    /// 若用户的目标分已经低于预测下界,认为差距为 0("无压力")。
    static func scoreGap(target: Double, result: ScorePredictionResult) -> Double {
        let safeTarget = max(0, target)
        let gap = safeTarget - result.lowerBound
        return max(0, gap)
    }
}
