//
//  RegenerableCacheFile.swift
//  StudyPulse
//

import Foundation
import os

/// Exact file locations for a rebuildable cache. Keeping this value injectable
/// lets tests prove that cache maintenance never touches neighboring user data.
nonisolated struct RegenerableCacheFileLocation: Sendable {
    let preferredURL: URL
    let legacyURL: URL
}

/// Shared path and one-time migration support for rebuildable JSON caches.
nonisolated enum RegenerableCacheFile {
    static let directoryName = "StudyPulse"

    static func productionLocation(
        fileName: String,
        fileManager: FileManager = .default
    ) throws -> RegenerableCacheFileLocation {
        let caches = try fileManager.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let documents = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return RegenerableCacheFileLocation(
            preferredURL: caches
                .appendingPathComponent(directoryName, isDirectory: true)
                .appendingPathComponent(fileName, isDirectory: false),
            legacyURL: documents.appendingPathComponent(fileName, isDirectory: false)
        )
    }

    /// Returns the new cache URL, migrating the exact legacy file when possible.
    /// A failed migration falls back to the legacy file and never blocks launch.
    static func resolvedURL(
        for location: RegenerableCacheFileLocation,
        fileManager: FileManager = .default
    ) throws -> URL {
        if fileManager.fileExists(atPath: location.preferredURL.path) {
            return location.preferredURL
        }

        if fileManager.fileExists(atPath: location.legacyURL.path) {
            do {
                try fileManager.createDirectory(
                    at: location.preferredURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try fileManager.moveItem(at: location.legacyURL, to: location.preferredURL)
                return location.preferredURL
            } catch {
                Log.data.warning(
                    "Cache file migration failed; using legacy location: \(location.legacyURL.lastPathComponent, privacy: .public)"
                )
                return location.legacyURL
            }
        }

        try fileManager.createDirectory(
            at: location.preferredURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        return location.preferredURL
    }

    static func size(
        at location: RegenerableCacheFileLocation,
        fileManager: FileManager = .default
    ) throws -> Int64 {
        let url = try resolvedURL(for: location, fileManager: fileManager)
        guard fileManager.fileExists(atPath: url.path) else { return 0 }
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values.fileSize ?? 0)
    }

    /// Deletes only the two known file URLs. No directory or recursive removal
    /// is ever performed.
    static func clear(
        _ location: RegenerableCacheFileLocation,
        fileManager: FileManager = .default
    ) throws {
        var firstError: Error?
        for url in [location.preferredURL, location.legacyURL] {
            guard fileManager.fileExists(atPath: url.path) else { continue }
            do {
                try fileManager.removeItem(at: url)
            } catch {
                if firstError == nil { firstError = error }
            }
        }
        if let firstError { throw firstError }
    }
}
