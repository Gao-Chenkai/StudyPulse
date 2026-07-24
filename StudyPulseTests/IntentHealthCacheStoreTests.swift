import XCTest
@testable import StudyPulse

final class IntentHealthCacheStoreTests: XCTestCase {
    func testWriteLoadSizeAndClear() throws {
        let fixture = try CacheFileFixture(name: IntentHealthCacheStore.fileName)
        defer { fixture.cleanup() }
        let snapshot = makeSnapshot()

        try IntentHealthCacheStore.write(snapshot, at: fixture.location)

        XCTAssertNotNil(IntentHealthCacheStore.load(at: fixture.location))
        XCTAssertGreaterThan(IntentHealthCacheStore.cacheSize(at: fixture.location), 0)
        try IntentHealthCacheStore.clear(at: fixture.location)
        XCTAssertNil(IntentHealthCacheStore.load(at: fixture.location))
    }

    func testMissingFileClearSucceeds() throws {
        let fixture = try CacheFileFixture(name: IntentHealthCacheStore.fileName)
        defer { fixture.cleanup() }

        XCTAssertNoThrow(try IntentHealthCacheStore.clear(at: fixture.location))
    }

    func testLegacySnapshotMigratesToCachesDirectory() throws {
        let fixture = try CacheFileFixture(name: IntentHealthCacheStore.fileName)
        defer { fixture.cleanup() }
        try JSONEncoder().encode(makeSnapshot()).write(to: fixture.location.legacyURL)

        XCTAssertNotNil(IntentHealthCacheStore.load(at: fixture.location))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.location.preferredURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.location.legacyURL.path))
    }

    private func makeSnapshot() -> IntentHealthCache {
        IntentHealthCache(
            readinessCategory: "ready",
            readinessSuggestion: "study",
            sleepHours: 8,
            sleepQuality: "good",
            restingHeartRate: 60,
            exerciseMinutes: 20,
            lastUpdated: Date()
        )
    }
}
