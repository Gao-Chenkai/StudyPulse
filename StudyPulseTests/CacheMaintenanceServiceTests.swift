import XCTest
import UIKit
@testable import StudyPulse

@MainActor
final class CacheMaintenanceServiceTests: XCTestCase {
    func testOnlySelectedCategoryIsCleared() async throws {
        let mindMap = try CacheFileFixture(name: AutoMindMapCacheStore.fileName)
        let health = try CacheFileFixture(name: IntentHealthCacheStore.fileName)
        defer {
            mindMap.cleanup()
            health.cleanup()
        }
        AutoMindMapCacheStore.save(
            contextTitle: "Math",
            mistakeIds: [],
            themes: [],
            at: mindMap.location
        )
        try IntentHealthCacheStore.write(makeSnapshot(), at: health.location)
        let service = makeService(mindMap: mindMap.location, health: health.location)

        let result = await service.clear([.mindMaps])

        XCTAssertEqual(result.clearedCategories, [.mindMaps])
        XCTAssertFalse(FileManager.default.fileExists(atPath: mindMap.location.preferredURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: health.location.preferredURL.path))
    }

    func testClearAllPreservesNeighboringPersonalData() async throws {
        let mindMap = try CacheFileFixture(name: AutoMindMapCacheStore.fileName)
        let health = try CacheFileFixture(name: IntentHealthCacheStore.fileName)
        defer {
            mindMap.cleanup()
            health.cleanup()
        }
        let healthHistory = health.root
            .appendingPathComponent("Documents/health_history.json")
        let originalImage = mindMap.root
            .appendingPathComponent("Documents/original-photo.jpg")
        try Data("history".utf8).write(to: healthHistory)
        try Data("image".utf8).write(to: originalImage)
        AutoMindMapCacheStore.save(
            contextTitle: "Math",
            mistakeIds: [],
            themes: [],
            at: mindMap.location
        )
        try IntentHealthCacheStore.write(makeSnapshot(), at: health.location)

        let imageCache = ImageCache()
        imageCache.putImage(UIImage(), Data("image-key".utf8))
        let llmCache = LLMResponseCache()
        let prompt = LLMPrompt(system: "system", messages: [.user("question")])
        await llmCache.set(caller: "test", prompt: prompt, config: .empty, response: "answer")
        let service = makeService(
            mindMap: mindMap.location,
            health: health.location,
            imageCache: imageCache,
            llmCache: llmCache
        )

        let result = await service.clearAll()

        XCTAssertEqual(result.clearedCategories, Set(CacheCategory.allCases))
        XCTAssertEqual(imageCache.entryCount, 0)
        let llmEntryCount = await llmCache.entryCount
        XCTAssertEqual(llmEntryCount, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: healthHistory.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: originalImage.path))
    }

    func testPartialDeletionFailureIsReported() async {
        enum ExpectedError: Error { case denied }
        let disk = CacheDiskOperations(
            mindMapSize: { 100 },
            mindMapEntryCount: { 1 },
            clearMindMaps: { throw ExpectedError.denied },
            healthSnapshotSize: { 0 },
            clearHealthSnapshot: {}
        )
        let service = CacheMaintenanceService(
            imageCache: ImageCache(),
            llmResponseCache: LLMResponseCache(),
            disk: disk
        )

        let result = await service.clear([.mindMaps, .healthSnapshot])

        XCTAssertNotNil(result.failures[.mindMaps])
        XCTAssertTrue(result.clearedCategories.contains(.healthSnapshot))
        XCTAssertFalse(result.clearedCategories.contains(.mindMaps))
    }

    func testConcurrentClearCallsShareOneOperation() async {
        let counter = LockedCounter()
        let disk = CacheDiskOperations(
            mindMapSize: { 1 },
            mindMapEntryCount: { 1 },
            clearMindMaps: { counter.increment() },
            healthSnapshotSize: { 0 },
            clearHealthSnapshot: {}
        )
        let service = CacheMaintenanceService(
            imageCache: ImageCache(),
            llmResponseCache: LLMResponseCache(),
            disk: disk
        )

        async let first = service.clear([.mindMaps])
        async let second = service.clear([.mindMaps])
        _ = await (first, second)

        XCTAssertEqual(counter.value, 1)
    }

    private func makeService(
        mindMap: RegenerableCacheFileLocation,
        health: RegenerableCacheFileLocation,
        imageCache: ImageCache = ImageCache(),
        llmCache: LLMResponseCache = LLMResponseCache()
    ) -> CacheMaintenanceService {
        CacheMaintenanceService(
            imageCache: imageCache,
            llmResponseCache: llmCache,
            disk: CacheDiskOperations(
                mindMapSize: { AutoMindMapCacheStore.cacheSize(at: mindMap) },
                mindMapEntryCount: { AutoMindMapCacheStore.entryCount(at: mindMap) },
                clearMindMaps: { try AutoMindMapCacheStore.clear(at: mindMap) },
                healthSnapshotSize: { IntentHealthCacheStore.cacheSize(at: health) },
                clearHealthSnapshot: { try IntentHealthCacheStore.clear(at: health) }
            )
        )
    }

    private func makeSnapshot() -> IntentHealthCache {
        IntentHealthCache(
            readinessCategory: "ready",
            readinessSuggestion: nil,
            sleepHours: nil,
            sleepQuality: nil,
            restingHeartRate: nil,
            exerciseMinutes: nil,
            lastUpdated: Date()
        )
    }
}

private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func increment() {
        lock.lock()
        storage += 1
        lock.unlock()
    }
}
