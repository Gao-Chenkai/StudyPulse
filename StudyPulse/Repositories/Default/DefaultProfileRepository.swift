//
//  DefaultProfileRepository.swift
//  StudyPulse
//
//  用户资料 (UserProfile) Repository 默认实现。
//  Default ProfileRepository implementation backed by SwiftData.
//

import Foundation
import SwiftData
import os

@Observable @MainActor
final class DefaultProfileRepository: ProfileRepository {
    var profile: UserProfile = UserProfile()

    @ObservationIgnored
    private var modelContext: ModelContext?

    /// 跨域引用:commitOnboardingProfile 会写 subjects(由 SubjectRepository 持有)
    @ObservationIgnored
    weak var subjectRef: (any SubjectRepository)?

    init() {}

    /// 容器在 init 时调用,注入 SubjectRepository weak 引用。
    func setSubjectRef(_ repo: any SubjectRepository) {
        self.subjectRef = repo
    }

    // MARK: - Lifecycle

    func loadAll(context: ModelContext) async {
        self.modelContext = context
        do {
            let profiles = try context.fetch(FetchDescriptor<UserProfileRecord>())
            if let entity = profiles.first {
                self.profile = entity.toSnapshot()
            }
        } catch {
            Log.data.error("DefaultProfileRepository loadAll failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - CRUD

    func saveProfile() {
        guard let context = modelContext else { return }
        do {
            let existing = try context.fetch(FetchDescriptor<UserProfileRecord>())
            if let entity = existing.first {
                entity.username = profile.username
                entity.age = profile.age
                entity.educationLevel = profile.educationLevel
                entity.educationSystem = profile.educationSystem
                entity.region = profile.region
                entity.selectedSubjectsData = try? JSONEncoder().encode(profile.selectedSubjects)
                entity.theme = profile.theme
                entity.avatarFileName = profile.avatarFileName
                entity.realName = profile.realName
                entity.grade = profile.grade
                entity.className = profile.className
                entity.schoolName = profile.schoolName
                entity.studentId = profile.studentId
                entity.enrollmentYear = profile.enrollmentYear
                entity.examYear = profile.examYear
                entity.educationStage = profile.educationStage
                entity.regionCode = profile.regionCode
                entity.gender = profile.gender
                entity.targetSchool = profile.targetSchool
                entity.targetScore = profile.targetScore
            } else {
                context.insert(UserProfileRecord(from: profile))
            }
            try context.save()
            Log.data.debug("ProfileRepository saved profile to SwiftData")
            Log.record(.info, category: "Data", message: "ProfileRepository saved profile to SwiftData")
        } catch {
            Log.data.error("ProfileRepository saveProfile failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func commitOnboardingProfile(draft: OnboardingProfileDraft, selectedSubjectNames: [String]) {
        let stage = EducationStage(rawValue: draft.educationStage) ?? .highSchool
        let region = EducationConfig.region(named: draft.regionCode, stage: stage)
            ?? EducationConfig.defaultRegion(for: stage)

        // 同步基础字段
        profile.username = draft.username
        profile.realName = draft.realName
        profile.age = max(draft.age, 0)
        profile.gender = draft.gender
        profile.educationStage = draft.educationStage
        profile.educationLevel = draft.educationStage
        profile.educationSystem = region.displayName
        profile.regionCode = draft.regionCode
        profile.region = region.displayName
        profile.schoolName = draft.schoolName
        profile.grade = draft.grade
        profile.className = draft.className
        profile.studentId = draft.studentId
        profile.enrollmentYear = draft.enrollmentYear
        profile.examYear = draft.examYear
        profile.targetSchool = draft.targetSchool
        profile.targetScore = draft.targetScore

        // 同步选科:通过 SubjectRepository 间接持有 subjects 数组
        let configByName = Dictionary(uniqueKeysWithValues: (region.subjects).map { ($0.name, $0) })
        let newSubjects: [Subject] = selectedSubjectNames.compactMap { name in
            if let cfg = configByName[name] {
                return Subject(
                    name: cfg.name,
                    displayName: cfg.displayName,
                    enabled: true,
                    fullScore: cfg.fullScore
                )
            }
            return Subject(name: name, displayName: name, enabled: true, fullScore: 100)
        }
        if let subjectRepo = subjectRef {
            if !newSubjects.isEmpty {
                subjectRepo.subjects = newSubjects
                subjectRepo.saveSubjects()
            } else {
                subjectRepo.applySmartSubjectRecommendation(stage: stage, regionCode: region.name)
            }
        } else {
            Log.data.warning("ProfileRepository commitOnboardingProfile: subjectRef is nil; subjects not synced")
        }

        // 写入 SwiftData
        saveProfile()
        Log.data.info("ProfileRepository onboarding committed: username=\(draft.username, privacy: .public) subjects=\(selectedSubjectNames.count, privacy: .public)")
        Log.record(.info, category: "Data", message: "ProfileRepository onboarding committed: username=\(draft.username) subjects=\(selectedSubjectNames.count)")
    }

    // MARK: - 头像

    @discardableResult
    func saveAvatar(_ data: Data) -> String? {
        let filename = "avatar_\(UUID().uuidString).jpg"
        if !ImageStorage.save(data, filename: filename) { return nil }
        if let oldFilename = profile.avatarFileName, oldFilename != filename {
            ImageStorage.delete(filename: oldFilename)
        }
        profile.avatarFileName = filename
        Log.data.info("ProfileRepository saved avatar: \(filename, privacy: .public) bytes=\(data.count, privacy: .public)")
        return filename
    }

    func loadAvatar() -> Data? {
        guard let filename = profile.avatarFileName else { return nil }
        return ImageStorage.load(filename: filename)
    }

    func loadAvatarAsync() async -> Data? {
        guard let filename = profile.avatarFileName else { return nil }
        return await ImageStorage.loadAsync(filename: filename)
    }

    func deleteAvatar(filename: String) {
        ImageStorage.delete(filename: filename)
    }
}
