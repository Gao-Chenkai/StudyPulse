//
//  PersistentStoreLaunchController.swift
//  StudyPulse
//

import Foundation
import SwiftData

/// Owns the persistent-store launch state so a migration failure can be shown
/// before any repository or data-backed view is initialized.
@Observable
@MainActor
final class PersistentStoreLaunchController {
    private(set) var modelContainer: ModelContainer?
    private(set) var error: ModelContainerFactory.StoreError?
    private(set) var isWorking = false
    private(set) var lastBackupURL: URL?

    init() {
        retry()
    }

    func retry() {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        do {
            modelContainer = try ModelContainerFactory.makeContainer()
            error = nil
        } catch let storeError as ModelContainerFactory.StoreError {
            modelContainer = nil
            error = storeError
        } catch {
            modelContainer = nil
            self.error = .applicationSupportUnavailable(error.localizedDescription)
        }
    }

    /// Must only be called after explicit user confirmation in the recovery UI.
    func performDisasterRecovery() {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        do {
            let result = try ModelContainerFactory.performDisasterRecovery()
            lastBackupURL = result.backupURL
            modelContainer = result.container
            error = nil
        } catch let storeError as ModelContainerFactory.StoreError {
            modelContainer = nil
            error = storeError
        } catch {
            modelContainer = nil
            self.error = .recoveryFailed(
                backupURL: lastBackupURL,
                reason: error.localizedDescription
            )
        }
    }
}
