//
//  MockProfileRepository.swift
//  StudyPulseTests
//
//  ProfileRepository 的纯内存 Mock 测试替身。
//  In-memory mock implementation of ProfileRepository for unit tests.
//

import Foundation
import SwiftData
@testable import StudyPulse

@MainActor
final class MockProfileRepository: ProfileRepository, @unchecked Sendable {
    var profile: UserProfile

    var avatarData: Data?

    // MARK: - 调用状态追踪

    var loadAllCalledCount = 0
    var saveProfileCalledCount = 0
    var commitOnboardingProfileCalledCount = 0
    var saveAvatarCalledCount = 0
    var loadAvatarCalledCount = 0
    var deleteAvatarCalledCount = 0

    var lastCommittedDraft: OnboardingProfileDraft?
    var lastCommittedSubjects: [String]?

    init(profile: UserProfile = UserProfile()) {
        self.profile = profile
    }

    func loadAll(context: ModelContext) async {
        loadAllCalledCount += 1
    }

    func saveProfile() {
        saveProfileCalledCount += 1
    }

    func commitOnboardingProfile(draft: OnboardingProfileDraft, selectedSubjectNames: [String]) {
        commitOnboardingProfileCalledCount += 1
        lastCommittedDraft = draft
        lastCommittedSubjects = selectedSubjectNames
        profile.username = draft.username
        profile.realName = draft.realName
        profile.age = max(draft.age, 0)
        profile.gender = draft.gender
        profile.educationStage = draft.educationStage
        profile.educationLevel = draft.educationStage
        profile.regionCode = draft.regionCode
        profile.schoolName = draft.schoolName
        profile.grade = draft.grade
        profile.className = draft.className
        profile.studentId = draft.studentId
        profile.enrollmentYear = draft.enrollmentYear
        profile.examYear = draft.examYear
        profile.targetSchool = draft.targetSchool
        profile.targetScore = draft.targetScore
    }

    @discardableResult
    func saveAvatar(_ data: Data) -> String? {
        saveAvatarCalledCount += 1
        avatarData = data
        let filename = "mock_avatar.jpg"
        profile.avatarFileName = filename
        return filename
    }

    func loadAvatar() -> Data? {
        loadAvatarCalledCount += 1
        return avatarData
    }

    func loadAvatarAsync() async -> Data? {
        loadAvatarCalledCount += 1
        return avatarData
    }

    func deleteAvatar(filename: String) {
        deleteAvatarCalledCount += 1
        avatarData = nil
        if profile.avatarFileName == filename {
            profile.avatarFileName = nil
        }
    }
}
