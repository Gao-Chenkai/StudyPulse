//
//  SubjectInfo.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/25.
//

import Foundation
import Combine
import SwiftUI

// MARK: - 科目名称显示辅助
/// 提供科目的本地化显示名（包括 displayName、本地化名、原始名）
nonisolated enum SubjectDisplay {
    /// 获取科目的最佳显示名
    /// 优先顺序：displayName > 本地化字符串 > 原始 name
    @MainActor static func displayName(for name: String, custom: String? = nil) -> String {
        if let custom = custom, !custom.isEmpty {
            return custom
        }
        return name.localized()
    }
}

class SubjectInfo: ObservableObject {
    /// 获取科目的满分（兼容旧接口）
    func getMaxScore(level: String, subject: String) -> Double {
        if level == "Middle School" {
            if subject == "Chinese" || subject == "Mathematics" || subject == "English" {
                return 120.0
            } else if subject == "Science" {
                return 160.0
            } else {
                return 100.0
            }
        } else if level == "High School" {
            if subject == "Chinese" || subject == "Mathematics" || subject == "English" {
                return 150.0
            } else {
                return 100.0
            }
        } else if level == "Primary School" {
            return 100.0
        }
        return 100.0
    }
}
