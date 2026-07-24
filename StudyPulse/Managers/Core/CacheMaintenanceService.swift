//
//  CacheMaintenanceService.swift
//  StudyPulse
//

import Foundation
import os

enum CacheCategory: String, CaseIterable, Identifiable, Sendable {
    case images
    case llmResponses
    case mindMaps
    case healthSnapshot

    var id: String { rawValue }
}

struct CacheCategoryUsage: Sendable, Equatable {
    let diskBytes: Int64
    let memoryEntryCount: Int

    static let zero = CacheCategoryUsage(diskBytes: 0, memoryEntryCount: 0)
}

struct CacheUsage: Sendable, Equatable {
    let diskBytes: Int64
    let memoryEntryCount: Int
    let categories: [CacheCategory: CacheCategoryUsage]

    static let zero = CacheUsage(
        diskBytes: 0,
        memoryEntryCount: 0,
        categories: [:]
    )

    func usage(for category: CacheCategory) -> CacheCategoryUsage {
        categories[category] ?? .zero
    }
}

struct CacheClearResult: Sendable, Equatable {
    let clearedCategories: Set<CacheCategory>
    let releasedDiskBytes: Int64
    let failures: [CacheCategory: String]
}

/// Injectable disk operations keep the service testable and constrain every
/// deletion to the two explicitly named cache files.
nonisolated struct CacheDiskOperations: Sendable {
    let mindMapSize: @Sendable () -> Int64
    let mindMapEntryCount: @Sendable () -> Int
    let clearMindMaps: @Sendable () throws -> Void
    let healthSnapshotSize: @Sendable () -> Int64
    let clearHealthSnapshot: @Sendable () throws -> Void

    static let live = CacheDiskOperations(
        mindMapSize: { AutoMindMapCacheStore.cacheSize() },
        mindMapEntryCount: { AutoMindMapCacheStore.entryCount() },
        clearMindMaps: { try AutoMindMapCacheStore.clear() },
        healthSnapshotSize: { IntentHealthCacheStore.cacheSize() },
        clearHealthSnapshot: { try IntentHealthCacheStore.clear() }
    )
}

@MainActor
final class CacheMaintenanceService {
    private let imageCache: ImageCache
    private let llmResponseCache: LLMResponseCache
    private let disk: CacheDiskOperations
    private var activeClearTask: Task<CacheClearResult, Never>?

    init(
        imageCache: ImageCache = .shared,
        llmResponseCache: LLMResponseCache = .shared,
        disk: CacheDiskOperations = .live
    ) {
        self.imageCache = imageCache
        self.llmResponseCache = llmResponseCache
        self.disk = disk
    }

    /// Disk inspection runs away from the main actor; only the two small
    /// in-memory cache counts are read synchronously.
    func usage() async -> CacheUsage {
        let imageCount = imageCache.entryCount
        let llmCount = llmResponseCache.entryCount
        let diskUsage = await Task.detached(priority: .utility) { [disk] in
            (
                mindMapBytes: disk.mindMapSize(),
                mindMapCount: disk.mindMapEntryCount(),
                healthBytes: disk.healthSnapshotSize()
            )
        }.value

        let categories: [CacheCategory: CacheCategoryUsage] = [
            .images: CacheCategoryUsage(diskBytes: 0, memoryEntryCount: imageCount),
            .llmResponses: CacheCategoryUsage(diskBytes: 0, memoryEntryCount: llmCount),
            .mindMaps: CacheCategoryUsage(
                diskBytes: diskUsage.mindMapBytes,
                memoryEntryCount: diskUsage.mindMapCount
            ),
            .healthSnapshot: CacheCategoryUsage(
                diskBytes: diskUsage.healthBytes,
                memoryEntryCount: 0
            ),
        ]
        return CacheUsage(
            diskBytes: diskUsage.mindMapBytes + diskUsage.healthBytes,
            memoryEntryCount: imageCount + llmCount + diskUsage.mindMapCount,
            categories: categories
        )
    }

    /// Concurrent calls share one active clear operation instead of deleting
    /// the same files twice.
    func clear(_ categories: Set<CacheCategory>) async -> CacheClearResult {
        if let activeClearTask {
            return await activeClearTask.value
        }
        guard !categories.isEmpty else {
            return CacheClearResult(
                clearedCategories: [],
                releasedDiskBytes: 0,
                failures: [:]
            )
        }

        let task = Task { [self] in
            await performClear(categories)
        }
        activeClearTask = task
        let result = await task.value
        activeClearTask = nil
        return result
    }

    func clearAll() async -> CacheClearResult {
        await clear(Set(CacheCategory.allCases))
    }

    private func performClear(_ categories: Set<CacheCategory>) async -> CacheClearResult {
        let before = await usage()
        var cleared: Set<CacheCategory> = []
        var failures: [CacheCategory: String] = [:]

        if categories.contains(.images) {
            imageCache.clear()
            cleared.insert(.images)
        }
        if categories.contains(.llmResponses) {
            llmResponseCache.clear()
            cleared.insert(.llmResponses)
        }

        let diskResult = await Task.detached(priority: .utility) { [disk] in
            var cleared: Set<CacheCategory> = []
            var failures: [CacheCategory: String] = [:]
            if categories.contains(.mindMaps) {
                do {
                    try disk.clearMindMaps()
                    cleared.insert(.mindMaps)
                } catch {
                    failures[.mindMaps] = error.localizedDescription
                }
            }
            if categories.contains(.healthSnapshot) {
                do {
                    try disk.clearHealthSnapshot()
                    cleared.insert(.healthSnapshot)
                } catch {
                    failures[.healthSnapshot] = error.localizedDescription
                }
            }
            return (cleared, failures)
        }.value
        cleared.formUnion(diskResult.0)
        failures.merge(diskResult.1) { current, _ in current }

        let after = await usage()
        let released = max(0, before.diskBytes - after.diskBytes)
        Log.data.info(
            "Cache maintenance completed: cleared=\(cleared.count), failures=\(failures.count), releasedBytes=\(released)"
        )
        return CacheClearResult(
            clearedCategories: cleared,
            releasedDiskBytes: released,
            failures: failures
        )
    }
}
