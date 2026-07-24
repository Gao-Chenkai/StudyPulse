//
//  IntentHealthCacheStore.swift
//  StudyPulse
//

import Foundation
import os

/// Thread-safe storage for the rebuildable App Intent readiness snapshot.
/// The cache intentionally contains no health history.
nonisolated enum IntentHealthCacheStore {
    static let fileName = "readiness_cache.json"
    private static let lock = NSLock()

    static func location() throws -> RegenerableCacheFileLocation {
        try RegenerableCacheFile.productionLocation(fileName: fileName)
    }

    static func fileURL() throws -> URL {
        lock.lock()
        defer { lock.unlock() }
        return try RegenerableCacheFile.resolvedURL(for: location())
    }

    static func load() -> IntentHealthCache? {
        guard let location = try? location() else { return nil }
        return load(at: location)
    }

    static func load(at location: RegenerableCacheFileLocation) -> IntentHealthCache? {
        lock.lock()
        defer { lock.unlock() }
        guard let url = try? RegenerableCacheFile.resolvedURL(for: location),
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        do {
            return try JSONDecoder().decode(IntentHealthCache.self, from: data)
        } catch {
            Log.data.error("Intent health cache decode failed")
            return nil
        }
    }

    static func write(_ snapshot: IntentHealthCache) throws {
        try write(snapshot, at: location())
    }

    static func write(
        _ snapshot: IntentHealthCache,
        at location: RegenerableCacheFileLocation
    ) throws {
        lock.lock()
        defer { lock.unlock() }
        let data = try JSONEncoder().encode(snapshot)
        let url = try RegenerableCacheFile.resolvedURL(for: location)
        try data.write(to: url, options: .atomic)
    }

    static func cacheSize() -> Int64 {
        guard let location = try? location() else { return 0 }
        return cacheSize(at: location)
    }

    static func cacheSize(at location: RegenerableCacheFileLocation) -> Int64 {
        lock.lock()
        defer { lock.unlock() }
        return (try? RegenerableCacheFile.size(at: location)) ?? 0
    }

    /// Removes only `readiness_cache.json`; health_history.json is never read,
    /// written or deleted by this store.
    static func clear() throws {
        try clear(at: location())
    }

    static func clear(at location: RegenerableCacheFileLocation) throws {
        lock.lock()
        defer { lock.unlock() }
        try RegenerableCacheFile.clear(location)
        Log.data.info("Intent health readiness cache cleared")
    }
}
