//
//  ProfileRepository.swift
//  StudyPulse
//
//  用户资料 (UserProfile) 域 Repository 协议。
//  User profile domain repository protocol.
//

import Foundation
import SwiftData

/// 用户资料 Repository 协议。
/// 负责 UserProfile 增删改查、头像文件管理、onboarding profile 提交、SwiftData 持久化。
@MainActor
protocol ProfileRepository: AnyObject, Sendable {
    var profile: UserProfile { get set }

    // MARK: - Lifecycle
    func loadAll(context: ModelContext) async

    // MARK: - CRUD
    /// 把当前 profile 同步到 SwiftData(更新或插入单例)
    func saveProfile()
    /// 首次启动 OnBoarding 完成时一次性提交用户资料 + 选科
    func commitOnboardingProfile(draft: OnboardingProfileDraft, selectedSubjectNames: [String])

    // MARK: - 头像
    @discardableResult
    func saveAvatar(_ data: Data) -> String?
    func loadAvatar() -> Data?
    func loadAvatarAsync() async -> Data?
    func deleteAvatar(filename: String)
}
