//
//  ScoreColor.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/4/26.
//
//  分数相关颜色与展示工具:旧接口默认 100 分制;推荐走 fullScore 入参。
//  Score-related color and display utilities: the legacy entrypoint defaults
//  to a 100-point scale; the recommended entrypoint takes `fullScore`.
//

import SwiftUI
import UIKit

// MARK: - 兼容旧接口(默认按 100 分制)
// MARK: - Legacy entrypoint (defaults to 100-point scale)

/// 旧版便捷入口,默认满分 100。
/// Legacy convenience entrypoint that assumes a 100-point scale.
func scoreColor(_ score: Double) -> Color {
    return scoreColor(score, fullScore: 100)
}

// MARK: - 按比例显示颜色(推荐使用)
// MARK: - Color by score ratio (recommended)

/// 根据分数和满分按比例返回颜色。
/// - 90% 及以上:绿色 (优)
/// - 75% - 90%:蓝色 (良)
/// - 60% - 75%:橙色 (中)
/// - 60% 以下:红色 (差)
/// Returns a color for a score given its full-score ceiling.
/// - ≥ 90%: green (excellent)
/// - 75% – 90%: blue (good)
/// - 60% – 75%: orange (fair)
/// - < 60%: red (poor)
func scoreColor(_ score: Double, fullScore: Double) -> Color {
    // 阈值 0.9 / 0.75 / 0.6,避免改动现有的色值映射
    // Thresholds 0.9 / 0.75 / 0.6; do not change without re-skinning other views.
    guard fullScore > 0 else { return .secondary }
    let rate = score / fullScore
    if rate >= 0.9 {
        return Color(.systemGreen)
    } else if rate >= 0.75 {
        return Color(.systemBlue)
    } else if rate >= 0.6 {
        return Color(.systemOrange)
    } else {
        return Color(.systemRed)
    }
}

// MARK: - 文本显示(带括号显示满分)
// MARK: - Score text helper (includes full-score and percent)

/// 把分数 / 满分 / 百分比格式化为单行字符串。
/// Format score / full-score / percent into a single line of text.
func scoreColorText(_ score: Double, fullScore: Double) -> String {
    let rate = fullScore > 0 ? score / fullScore : 0
    return String(format: "%.1f/%.0f (%.0f%%)", score, fullScore, rate * 100)
}
