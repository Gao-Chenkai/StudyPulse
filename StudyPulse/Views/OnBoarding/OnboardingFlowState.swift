//
//  OnboardingFlowState.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/6/30.
//
//  首次启动 OnBoarding 流程的草稿状态：
//  - 用户在「介绍 → 基础信息填写」流程中填到一半被强杀后，
//    下次启动可以从该步骤继续，已填写数据不丢失。
//  - 仅用于「首次安装的 welcome 流程」；whatsNew 不写草稿。
//

import Foundation

/// 首次启动 onboarding 草稿状态（UserDefaults 单例）
struct OnboardingFlowState: Codable, Equatable {
    /// 用户已选择开启的草稿版本（防止旧版本遗留字段导致解码失败）
    static let currentSchemaVersion: Int = 1

    /// 用户当前停留的 step 索引（0 = 第一页介绍，最后一页 = 介绍结束）
    var currentStep: Int = 0

    /// 草稿 schema 版本
    var schemaVersion: Int = OnboardingFlowState.currentSchemaVersion

    /// 草稿：用户资料（任何填写页都共用同一份草稿）
    var draft: OnboardingProfileDraft = OnboardingProfileDraft()

    /// 用户已选科目（按 Subject.name 存储，避免在草稿中重复保存 SubjectConfig）
    var selectedSubjectNames: [String] = []
}

/// 单页草稿：与 UserProfile 字段一一对应，但都用可选 / 默认值。
struct OnboardingProfileDraft: Codable, Equatable {
    var username: String = ""
    var realName: String = ""
    var age: Int = 0
    var gender: String = "Not Specified"
    var schoolName: String = ""
    var grade: String = ""
    var className: String = ""
    var studentId: String = ""
    var enrollmentYear: Int = Calendar.current.component(.year, from: Date())
    var examYear: Int = Calendar.current.component(.year, from: Date())
    var educationStage: String = "High School"
    var regionCode: String = "mainland"
    var targetSchool: String = ""
    var targetScore: Double = 0
}

// MARK: - 持久化辅助

enum OnboardingFlowStateStore {
    private static let key = "onboardingFlowDraft_v1"

    /// 读取草稿；不存在或解析失败时返回 nil
    static func load() -> OnboardingFlowState? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        do {
            let state = try JSONDecoder().decode(OnboardingFlowState.self, from: data)
            // 旧 schema 视为无效，丢弃以免影响新流程
            guard state.schemaVersion == OnboardingFlowState.currentSchemaVersion else {
                return nil
            }
            return state
        } catch {
            return nil
        }
    }

    /// 保存草稿
    static func save(_ state: OnboardingFlowState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    /// 清除草稿（完成首次 onboarding 或跳过填写时调用）
    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    /// 是否存在未完成的草稿
    static var hasDraft: Bool {
        load() != nil
    }
}
