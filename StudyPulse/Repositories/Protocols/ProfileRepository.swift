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
/// User profile repository protocol.
/// 负责 UserProfile 增删改查、头像文件管理、onboarding profile 提交、SwiftData 持久化。
/// Owns `UserProfile` CRUD, avatar file management, onboarding profile
/// submission, and SwiftData persistence.
@MainActor
protocol ProfileRepository: AnyObject, Sendable {
    /// 内存中的 profile（单例）
    /// In-memory profile (singleton).
    var profile: UserProfile { get set }

    // MARK: - Lifecycle
    // MARK: - 生命周期 / Lifecycle

    /// 加载资料
    /// Load the profile.
    func loadAll(context: ModelContext) async

    // MARK: - CRUD
    // MARK: - 增删改查 / CRUD

    /// 把当前 profile 同步到 SwiftData(更新或插入单例)
    /// Persist the current profile to SwiftData (upsert singleton).
    func saveProfile()
    /// 首次启动 OnBoarding 完成时一次性提交用户资料 + 选科
    /// One-shot onboarding commit: profile fields + selected subject names.
    func commitOnboardingProfile(draft: OnboardingProfileDraft, selectedSubjectNames: [String])

    // MARK: - 头像
    // MARK: - 头像 / Avatar

    /// 保存头像并返回写入的文件名
    /// Save avatar data and return the stored filename.
    @discardableResult
    func saveAvatar(_ data: Data) -> String?
    /// 同步加载头像(磁盘读)
    /// Synchronous avatar load (disk read).
    func loadAvatar() -> Data?
    /// 异步加载头像(IO 线程)
    /// Asynchronous avatar load (off main).
    func loadAvatarAsync() async -> Data?
    /// 删除头像文件
    /// Delete an avatar file by filename.
    func deleteAvatar(filename: String)
}
