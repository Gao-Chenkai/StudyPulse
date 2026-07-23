import Foundation
import ZIPFoundation

nonisolated enum BackupArchive {
    static func create(from directory: URL, at archiveURL: URL) throws {
        do {
            try FileManager.default.zipItem(
                at: directory,
                to: archiveURL,
                shouldKeepParent: false,
                compressionMethod: .deflate
            )
        } catch {
            throw BackupError.exportFailed(error.localizedDescription)
        }
    }

    /// Examines every central-directory entry before extraction. Symlinks are
    /// not required by the format and are rejected to keep containment simple.
    static func validateEntryPaths(at archiveURL: URL) throws -> [String] {
        let archive: Archive
        do {
            archive = try Archive(url: archiveURL, accessMode: .read)
        } catch {
            throw BackupError.invalidArchive
        }
        var paths: [String] = []
        for entry in archive {
            let path = entry.path.replacingOccurrences(of: "\\", with: "/")
            // ZIP directory entries conventionally end in "/". Validate the
            // directory name itself rather than treating that one trailing
            // separator as an empty path component. Empty components anywhere
            // else (for example "media//file") remain invalid.
            let pathToValidate: String
            if entry.type == .directory, path.hasSuffix("/") {
                pathToValidate = String(path.dropLast())
            } else {
                pathToValidate = path
            }
            guard isSafeRelativePath(pathToValidate), entry.type != .symlink else {
                throw BackupError.dangerousPath(entry.path)
            }
            paths.append(path)
        }
        return paths
    }

    static func extractSafely(from archiveURL: URL, to destination: URL) throws {
        _ = try validateEntryPaths(at: archiveURL)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        do {
            try FileManager.default.unzipItem(at: archiveURL, to: destination)
        } catch {
            throw BackupError.invalidArchive
        }

        let root = destination.standardizedFileURL.path
        let enumerator = FileManager.default.enumerator(
            at: destination,
            includingPropertiesForKeys: [.isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        )
        while let url = enumerator?.nextObject() as? URL {
            let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey])
            guard values.isSymbolicLink != true,
                  url.standardizedFileURL.path == root
                    || url.standardizedFileURL.path.hasPrefix(root + "/") else {
                throw BackupError.dangerousPath(url.lastPathComponent)
            }
        }
    }

    static func isSafeRelativePath(_ path: String) -> Bool {
        guard !path.isEmpty, !path.hasPrefix("/"), !path.hasPrefix("\\") else { return false }
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        guard !components.contains(where: { $0 == ".." || $0 == "." || $0.isEmpty }) else { return false }
        if let first = components.first, first.contains(":") { return false }
        return true
    }
}
