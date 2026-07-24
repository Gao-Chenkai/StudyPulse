//
//  PersistenceExecutorTests.swift
//  StudyPulseTests
//

import XCTest
import SwiftData
import Darwin
@testable import StudyPulse

@MainActor
final class PersistenceExecutorTests: XCTestCase {
    func testConcurrentReadsAndWritesRemainConsistent() async throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let executor = PersistenceExecutor(modelContainer: container)

        try await withThrowingTaskGroup(of: Void.self) { group in
            for shard in 0..<10 {
                group.addTask {
                    let values = (0..<100).map { index in
                        Grade(
                            id: UUID(),
                            subject: "S\(shard)",
                            score: Double(index),
                            date: Date(timeIntervalSince1970: Double(shard * 100 + index)),
                            examName: "Concurrent"
                        )
                    }
                    try await executor.insertGrades(values)
                }
            }
            try await group.waitForAll()
        }

        async let firstRead = executor.fetchGrades(batchSize: 73)
        async let secondRead = executor.fetchGrades(batchSize: 127)
        let (first, second) = try await (firstRead, secondRead)

        XCTAssertEqual(first.count, 1_000)
        XCTAssertEqual(second.count, 1_000)
        XCTAssertEqual(Set(first.map(\.id)), Set(second.map(\.id)))
    }

    func testCancelledBatchDoesNotPublishPartialRepositoryState() async throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let environment = AppEnvironmentManager.shared
        let repository = DefaultGradeRepository(envManager: environment)
        let executor = PersistenceExecutor(modelContainer: container)
        repository.attachPersistenceExecutor(executor)
        await repository.loadAll(context: container.mainContext)

        let values = (0..<20_000).map {
            Grade(subject: "Cancellation", score: Double($0 % 100), examName: "Cancelled")
        }
        repository.add(values)
        repository.cancelPendingPersistence()
        await repository.flushPendingPersistence()

        XCTAssertTrue(repository.grades.isEmpty)
        let persisted = try await executor.fetchGrades()
        XCTAssertTrue(persisted.isEmpty)
    }

    func testBatchImportAndBulkDeletePublishOnlyFinalSnapshots() async throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let repository = DefaultMistakeRepository(envManager: .shared)
        let executor = PersistenceExecutor(modelContainer: container)
        repository.attachPersistenceExecutor(executor)
        await repository.loadAll(context: container.mainContext)

        let values = (0..<2_000).map {
            MistakeNote(
                title: "M\($0)",
                subject: "Math",
                originalQuestion: "Q",
                source: "Import",
                errorReason: "R",
                wrongSolution: "W",
                correctSolution: "C"
            )
        }
        let clock = ContinuousClock()
        let importStart = clock.now
        repository.add(values)
        XCTAssertTrue(repository.mistakeSets.isEmpty)
        await repository.flushPendingPersistence()
        let importDuration = importStart.duration(to: clock.now)
        XCTAssertEqual(repository.mistakeSets.count, 2_000)

        let deleteStart = clock.now
        XCTAssertEqual(repository.clearAll(), 2_000)
        await repository.flushPendingPersistence()
        let deleteDuration = deleteStart.duration(to: clock.now)
        XCTAssertTrue(repository.mistakeSets.isEmpty)
        let persisted = try await executor.fetchMistakes()
        XCTAssertTrue(persisted.isEmpty)
        print(
            "PHASE5_BATCH import_mistakes_2k=\(importDuration) " +
            "delete_mistakes_2k=\(deleteDuration)"
        )
    }

    func testFiveThousandGradesAndMistakesStartupAndFilteringBaseline() async throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let executor = PersistenceExecutor(modelContainer: container)
        let phaseA = UUID()
        let phaseB = UUID()

        let grades = (0..<5_000).map { index in
            Grade(
                subject: "S\(index % 8)",
                score: Double(index % 100),
                date: Date(timeIntervalSince1970: Double(index)),
                examName: "Performance",
                phaseId: index.isMultiple(of: 2) ? phaseA : phaseB
            )
        }
        let mistakes = (0..<5_000).map { index in
            MistakeNote(
                title: "M\(index)",
                subject: "S\(index % 8)",
                originalQuestion: "Q",
                source: "Performance",
                date: Date(timeIntervalSince1970: Double(index)),
                errorReason: "R",
                wrongSolution: "W",
                correctSolution: "C",
                phaseId: index.isMultiple(of: 2) ? phaseA : phaseB
            )
        }
        try await executor.insertGrades(grades)
        try await executor.insertMistakes(mistakes)

        let clock = ContinuousClock()
        let legacyMemoryBefore = residentMemoryBytes()
        let legacyStart = clock.now
        let legacyGrades = try container.mainContext
            .fetch(FetchDescriptor<GradeRecord>())
            .map { $0.toSnapshot() }
        let legacyMistakes = try container.mainContext
            .fetch(FetchDescriptor<MistakeNoteRecord>())
            .map { $0.toSnapshot() }
        let legacyLoadDuration = legacyStart.duration(to: clock.now)
        let legacyMemoryAfter = residentMemoryBytes()

        let legacyFilterStart = clock.now
        var legacyFilterCount = 0
        for iteration in 0..<200 {
            let phase = iteration.isMultiple(of: 2) ? phaseA : phaseB
            legacyFilterCount += legacyGrades.filter { $0.phaseId == phase }.count
            legacyFilterCount += legacyMistakes.filter { $0.phaseId == phase }.count
        }
        let legacyFilterDuration = legacyFilterStart.duration(to: clock.now)

        let memoryBefore = residentMemoryBytes()
        let start = clock.now
        async let loadedGrades = executor.fetchGrades()
        async let loadedMistakes = executor.fetchMistakes()
        let snapshots = try await (loadedGrades, loadedMistakes)
        let loadDuration = start.duration(to: clock.now)
        let filterStart = clock.now
        let filteredGrades = Dictionary(grouping: snapshots.0.compactMap { value in
            value.phaseId.map { ($0, value) }
        }, by: \.0)
        let filteredMistakes = Dictionary(grouping: snapshots.1.compactMap { value in
            value.phaseId.map { ($0, value) }
        }, by: \.0)
        var indexedFilterCount = 0
        for iteration in 0..<200 {
            let phase = iteration.isMultiple(of: 2) ? phaseA : phaseB
            indexedFilterCount += filteredGrades[phase]?.count ?? 0
            indexedFilterCount += filteredMistakes[phase]?.count ?? 0
        }
        let filterDuration = filterStart.duration(to: clock.now)
        let memoryAfter = residentMemoryBytes()

        XCTAssertEqual(snapshots.0.count, 5_000)
        XCTAssertEqual(snapshots.1.count, 5_000)
        XCTAssertEqual(filteredGrades[phaseA]?.count, 2_500)
        XCTAssertEqual(filteredMistakes[phaseB]?.count, 2_500)
        XCTAssertEqual(indexedFilterCount, legacyFilterCount)
        XCTAssertLessThan(loadDuration, .seconds(5))
        XCTAssertLessThan(filterDuration, .seconds(1))

        print(
            "PHASE5_BASELINE legacy_startup_5k_5k=\(legacyLoadDuration) " +
            "legacy_phase_switch_200=\(legacyFilterDuration) " +
            "legacy_resident_delta=\(Int64(legacyMemoryAfter) - Int64(legacyMemoryBefore))"
        )
        print(
            "PHASE5_METRIC actor_startup_5k_5k=\(loadDuration) " +
            "indexed_phase_switch_200=\(filterDuration) " +
            "actor_resident_delta=\(Int64(memoryAfter) - Int64(memoryBefore))"
        )
    }

    private func residentMemoryBytes() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }
        return result == KERN_SUCCESS ? UInt64(info.resident_size) : 0
    }
}
