//
//  SubjectInfo.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/25.
//

import Foundation
import SwiftUI

// MARK: - 科目名称显示辅助 / Subject display helper
// MARK: - 科目名称显示辅助
/// 提供科目的本地化显示名(包括 displayName、本地化名、原始名)。
/// Helpers for resolving a subject's localized display name.
nonisolated enum SubjectDisplay {
    /// 获取科目的最佳显示名。
    /// 优先顺序:displayName > 本地化字符串 > 原始 name。
    /// Best display name for a subject. Priority: custom > localized name > raw name.
    @MainActor static func displayName(for name: String, custom: String? = nil) -> String {
        if let custom = custom, !custom.isEmpty {
            return custom
        }
        return name.localized()
    }
}

@Observable
class SubjectInfo {
    /// 获取科目的满分(兼容旧接口)。
    /// Legacy API: return the full-score for a (level, subject) pair.
    func getMaxScore(level: String, subject: String) -> Double {
        // 旧的硬编码表:初中 3 主科 120,科学 160,其他 100;高中 3 主科 150,其他 100;小学统一 100
        // Legacy hard-coded table: middle school 3 mains 120, Science 160, others 100; etc.
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
