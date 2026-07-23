import Foundation
import os

@MainActor
enum BackupRestoreCoordinator {
    static func restore(
        validated: ValidatedBackup,
        mode: BackupRestoreMode,
        container: RepositoryContainer,
        progress: @escaping @MainActor (Double) -> Void
    ) async throws -> BackupImporter.ImportResult {
        progress(0.01)
        let recovery = try await BackupExporter.export(
            container: container,
            options: BackupExportOptions(includesMedia: true, includesDerivedHealthData: false)
        )
        let recoveryURL = try persistRecoveryPoint(recovery.archiveURL)
        defer { try? FileManager.default.removeItem(at: recovery.archiveURL) }
        do {
            return try await BackupImporter.apply(
                validated: validated,
                mode: mode,
                container: container,
                progress: progress
            )
        } catch {
            Log.data.error("Backup restore failed; applying recovery point. Stage detail: \(error.localizedDescription, privacy: .public)")
            do {
                let rollback = try await BackupValidator.validate(archiveURL: recoveryURL)
                defer { rollback.cleanup() }
                _ = try await BackupImporter.apply(
                    validated: rollback,
                    mode: .replace,
                    container: container,
                    progress: { _ in }
                )
            } catch {
                throw BackupError.rollbackFailed(error.localizedDescription)
            }
            throw error
        }
    }

    private static func persistRecoveryPoint(_ source: URL) throws -> URL {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = support.appendingPathComponent("StudyPulseRecoveryPoints", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let target = directory.appendingPathComponent("BeforeRestore-\(UUID().uuidString).studypulsebackup")
        try FileManager.default.copyItem(at: source, to: target)
        return target
    }
}
