//
//  TestRepositoryContainerFactory.swift
//  StudyPulseTests
//
//  提供双模式 Repository 容器测试工厂：
//  1. Mock 模式 (`makeMockContainer()`) - 为纯内存单元测试极速构建
//  2. Real In-Memory 模式 (`makeInMemoryRealContainer()`) - 为集成/跨域测试构建
//

import Foundation
import SwiftData
@testable import StudyPulse

/// 聚合 9 个 Mock Repository 的访问枢纽，方便测试用例直接对特定 Repo 进行控制与断言
@MainActor
struct MockRepositoryHub {
    let grade: MockGradeRepository
    let mistake: MockMistakeRepository
    let exam: MockExamRepository
    let task: MockTaskRepository
    let phase: MockPhaseRepository
    let profile: MockProfileRepository
    let subject: MockSubjectRepository
    let routine: MockRoutineRepository
    let routineInstance: MockRoutineInstanceRepository
}

/// 测试用 RepositoryContainer 工厂
@MainActor
enum TestRepositoryContainerFactory {

    /// 创建纯内存 Mock Repository 组装的 RepositoryContainer 和访问枢纽
    static func makeMockContainer() -> (container: RepositoryContainer, mocks: MockRepositoryHub) {
        let g = MockGradeRepository()
        let m = MockMistakeRepository()
        let e = MockExamRepository()
        let t = MockTaskRepository()
        let p = MockPhaseRepository()
        let prof = MockProfileRepository()
        let s = MockSubjectRepository()
        let r = MockRoutineRepository()
        let ri = MockRoutineInstanceRepository()

        let container = RepositoryContainer(
            gradeRepo: g,
            mistakeRepo: m,
            examRepo: e,
            taskRepo: t,
            phaseRepo: p,
            profileRepo: prof,
            subjectRepo: s,
            routineRepo: r,
            routineInstanceRepo: ri
        )

        let hub = MockRepositoryHub(
            grade: g,
            mistake: m,
            exam: e,
            task: t,
            phase: p,
            profile: prof,
            subject: s,
            routine: r,
            routineInstance: ri
        )

        return (container, hub)
    }

    /// 创建使用真实 DefaultRepository 并绑定 In-Memory SwiftData 内存容器的 RepositoryContainer
    static func makeInMemoryRealContainer() async throws -> RepositoryContainer {
        let inMemoryModelContainer = try TestModelContainerFactory.makeInMemoryContainer()
        let container = RepositoryContainer()
        await container.asyncTestInit(with: inMemoryModelContainer)
        return container
    }
}
