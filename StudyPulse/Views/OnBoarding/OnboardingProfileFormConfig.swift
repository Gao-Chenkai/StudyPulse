//
//  OnboardingProfileFormConfig.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/6/30.
//
//  首次启动 OnBoarding 流程中的「基础信息填写」步骤配置。
//  与 OnboardingConfig 解耦，便于在保持原有 OnBoarding 设计风格的同时复用页面模板。
//

import SwiftUI

/// 首次启动填写流程的 6 个步骤，按顺序展示
enum OnboardingProfileStep: Int, CaseIterable, Identifiable, Equatable {
    case identity        // 昵称 / 真实姓名
    case ageGender       // 年龄 / 性别
    case school          // 学校 / 年级 / 班级
    case education       // 教育阶段 / 地区
    case subjects        // 选科
    case goals           // 目标学校 / 目标分

    var id: Int { rawValue }

    /// 该步骤在「介绍 + 填写」总流程中的索引基址
    /// 由 OnboardingView 注入，default = 0（介绍全部结束后再开始填写）
    func stepIndex(base: Int) -> Int { base + rawValue }

    /// 标题（出现在卡片顶部）
    var title: String {
        switch self {
        case .identity:   return "Tell us about you".localized()
        case .ageGender:  return "How old are you?".localized()
        case .school:     return "Where do you study?".localized()
        case .education:  return "Pick your education system".localized()
        case .subjects:   return "Choose your subjects".localized()
        case .goals:      return "Set your goals".localized()
        }
    }

    /// 副标题（标题下方一行说明）
    var subtitle: String {
        switch self {
        case .identity:   return "We'll use this name across the app.".localized()
        case .ageGender:  return "Helps personalize your study suggestions.".localized()
        case .school:     return "Optional — but it powers reminders and trends.".localized()
        case .education:  return "We'll pre-fill subjects and grading scales for you.".localized()
        case .subjects:   return "Tap a subject to enable or disable it.".localized()
        case .goals:      return "Optional — you can update this anytime later.".localized()
        }
    }

    /// 图标
    var icon: String {
        switch self {
        case .identity:   return "person.crop.circle.badge.plus"
        case .ageGender:  return "calendar.badge.clock"
        case .school:     return "building.columns"
        case .education:  return "graduationcap"
        case .subjects:   return "books.vertical"
        case .goals:      return "target"
        }
    }

    /// 颜色
    var color: Color {
        switch self {
        case .identity:   return .blue
        case .ageGender:  return .pink
        case .school:     return .indigo
        case .education:  return .purple
        case .subjects:   return .orange
        case .goals:      return .red
        }
    }

    /// 该步骤是否必填（不可跳过）
    var isRequired: Bool {
        switch self {
        case .identity, .ageGender, .school, .education, .subjects: return true
        case .goals: return false
        }
    }
}

/// 草稿表单的辅助计算：通过 step 上下文给出当前 region / 选科集合等派生数据
struct OnboardingProfileContext {
    let educationStage: EducationStage
    let regionCode: String
    let region: EducationRegion?
    let availableSubjects: [SubjectConfig]
    let currentYear: Int
}
