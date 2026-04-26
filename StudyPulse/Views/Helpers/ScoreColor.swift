//
//  ScoreColor.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/4/26.
//

import SwiftUI
import UIKit

func scoreColor(_ score: Double) -> Color {
    // 假设满分150，如果满分不同可自行调整阈值
    score >= 120 ? Color(.systemGreen) : score >= 90 ? Color(.systemBlue) : score >= 60 ? Color(.systemOrange) : Color(.systemRed)
}
