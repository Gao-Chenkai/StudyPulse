import XCTest
@testable import StudyPulse

final class AutoMindMapCacheStoreTests: XCTestCase {
    func testMissingFileClearSucceeds() throws {
        let fixture = try CacheFileFixture(name: AutoMindMapCacheStore.fileName)
        defer { fixture.cleanup() }

        XCTAssertNoThrow(try AutoMindMapCacheStore.clear(at: fixture.location))
        XCTAssertEqual(AutoMindMapCacheStore.cacheSize(at: fixture.location), 0)
        XCTAssertEqual(AutoMindMapCacheStore.entryCount(at: fixture.location), 0)
    }

    func testSizeAndEntryCountAreAccurate() throws {
        let fixture = try CacheFileFixture(name: AutoMindMapCacheStore.fileName)
        defer { fixture.cleanup() }
        AutoMindMapCacheStore.save(
            contextTitle: "Math",
            mistakeIds: ["one"],
            themes: [MindMapTheme(theme: "Algebra", knowledgePoints: [])],
            at: fixture.location
        )

        let data = try Data(contentsOf: fixture.location.preferredURL)
        XCTAssertEqual(AutoMindMapCacheStore.cacheSize(at: fixture.location), Int64(data.count))
        XCTAssertEqual(AutoMindMapCacheStore.entryCount(at: fixture.location), 1)

        try AutoMindMapCacheStore.clear(at: fixture.location)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.location.preferredURL.path))
    }

    func testLegacyFileMigratesToCachesDirectory() throws {
        let fixture = try CacheFileFixture(name: AutoMindMapCacheStore.fileName)
        defer { fixture.cleanup() }
        let entry = MindMapCacheEntry(
            contextTitle: "Legacy",
            mistakeIds: [],
            themes: [],
            timestamp: Date()
        )
        try JSONEncoder().encode(["Legacy": entry]).write(to: fixture.location.legacyURL)

        XCTAssertEqual(AutoMindMapCacheStore.loadAll(at: fixture.location).count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.location.preferredURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.location.legacyURL.path))
    }

    func testConcurrentReadsWritesAndClearDoNotCrash() async throws {
        let fixture = try CacheFileFixture(name: AutoMindMapCacheStore.fileName)
        defer { fixture.cleanup() }
        await withTaskGroup(of: Void.self) { group in
            for index in 0..<20 {
                group.addTask {
                    AutoMindMapCacheStore.save(
                        contextTitle: "Context \(index)",
                        mistakeIds: [],
                        themes: [],
                        at: fixture.location
                    )
                }
                group.addTask {
                    _ = AutoMindMapCacheStore.loadAll(at: fixture.location)
                }
            }
            group.addTask {
                try? AutoMindMapCacheStore.clear(at: fixture.location)
            }
        }
        XCTAssertGreaterThanOrEqual(AutoMindMapCacheStore.entryCount(at: fixture.location), 0)
    }
}

struct CacheFileFixture: @unchecked Sendable {
    let root: URL
    let location: RegenerableCacheFileLocation

    init(name: String) throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("StudyPulseCacheTests-\(UUID().uuidString)", isDirectory: true)
        let caches = root.appendingPathComponent("Library/Caches/StudyPulse", isDirectory: true)
        let documents = root.appendingPathComponent("Documents", isDirectory: true)
        try FileManager.default.createDirectory(at: caches, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
        location = RegenerableCacheFileLocation(
            preferredURL: caches.appendingPathComponent(name),
            legacyURL: documents.appendingPathComponent(name)
        )
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: root)
    }
}
