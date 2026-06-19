//
//  ScoreColor.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/4/26.
//

import SwiftUI
import UIKit

// MARK: - 兼容旧接口（默认按 100 分制）
func scoreColor(_ score: Double) -> Color {
    return scoreColor(score, fullScore: 100)
}

// MARK: - 按比例显示颜色（推荐使用）
/// 根据分数和满分按比例返回颜色
/// - 90% 及以上：绿色 (优)
/// - 75% - 90%：蓝色 (良)
/// - 60% - 75%：橙色 (中)
/// - 60% 以下：红色 (差)
func scoreColor(_ score: Double, fullScore: Double) -> Color {
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

// MARK: - 文本显示（带括号显示满分）
func scoreColorText(_ score: Double, fullScore: Double) -> String {
    let rate = fullScore > 0 ? score / fullScore : 0
    return String(format: "%.1f/%.0f (%.0f%%)", score, fullScore, rate * 100)
}
