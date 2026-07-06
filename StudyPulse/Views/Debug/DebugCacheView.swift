//
//  DebugCacheView.swift
//  StudyPulse
//
//  Debug → State & Cache：手动触发诊断 / 维护操作。
//  All destructive operations go through confirmation dialogs.
//

import SwiftUI
import SwiftData
import WidgetKit
import UserNotifications
import os

struct DebugCacheView: View {
    @Environment(RepositoryContainer.self) private var container
    @EnvironmentObject private var envManager: AppEnvironmentManager
    @EnvironmentObject private var hrvManager: HealthKitManager

    // Diagnostics snapshot
    @State private var entityCounts: [(name: String, count: Int)] = []
    @State private var isLoadingCounts: Bool = false
    @State private var lastRefresh: Date? = nil

    // Pending action feedback
    @State private var statusMessage: String? = nil
    @State private var statusIsError: Bool = false

    // Confirmation dialogs
    @State private var pendingAction: PendingAction? = nil

    enum PendingAction: Identifiable {
        case clearLogs
        case clearImageCache
        case rerunMigration
        case resetPreferences
        case recomputeAchievements

        var id: String {
            switch self {
            case .clearLogs: return "clearLogs"
            case .clearImageCache: return "clearImageCache"
            case .rerunMigration: return "rerunMigration"
            case .resetPreferences: return "resetPreferences"
            case .recomputeAchievements: return "recomputeAchievements"
            }
        }
    }

    var body: some View {
        List {
            diagnosticsSection
            stateSection
            maintenanceSection
            dangerousSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("debug.stateAndCache".localized())
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await refreshEntityCounts()
        }
        .refreshable {
            await refreshEntityCounts()
        }
        .confirmationDialog(
            dialogTitle(for: pendingAction),
            isPresented: Binding(
                get: { pendingAction != nil },
                set: { if !$0 { pendingAction = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Cancel".localized(), role: .cancel) { pendingAction = nil }
            Button("Confirm".localized(), role: .destructive) {
                if let action = pendingAction {
                    perform(action)
                }
                pendingAction = nil
            }
        } message: {
            Text(dialogMessage(for: pendingAction))
        }
        .alert(
            statusIsError ? "Error".localized() : "Done".localized(),
            isPresented: Binding(
                get: { statusMessage != nil },
                set: { if !$0 { statusMessage = nil } }
            )
        ) {
            Button("OK".localized()) { statusMessage = nil }
        } message: {
            if let msg = statusMessage {
                Text(msg)
            }
        }
    }

    // MARK: - Sections

    private var diagnosticsSection: some View {
        Section {
            if isLoadingCounts {
                HStack {
                    ProgressView()
                    Text("Loading…".localized())
                        .foregroundStyle(.secondary)
                }
            } else if entityCounts.isEmpty {
                Text("No data".localized())
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entityCounts, id: \.name) { item in
                    HStack {
                        Text(item.name)
                            .font(.system(size: 13, design: .monospaced))
                        Spacer()
                        Text("\(item.count)")
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundStyle(item.count == -1 ? .red : .primary)
                    }
                }
            }

            HStack {
                Text("Active Phase".localized())
                Spacer()
                Text(envManager.activePhaseId?.uuidString.prefix(8).description ?? "all")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Glass Effect".localized())
                Spacer()
                Text(envManager.glassEffectEnabled ? "ON" : "OFF")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(envManager.glassEffectEnabled ? .green : .secondary)
            }
            HStack {
                Text("Accent".localized())
                Spacer()
                Text(envManager.effectiveAccent.rawValue)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        } header: {
            HStack {
                Text("debug.entityCounts".localized())
                Spacer()
                Button {
                    Task { await refreshEntityCounts() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
            }
        } footer: {
            if let last = lastRefresh {
                Text("Updated \(last.formatted(date: .omitted, time: .standard))")
                    .font(.caption2)
            }
        }
    }

    private var stateSection: some View {
        Section {
            Button {
                runAction(.recomputeAchievements)
            } label: {
                Label("debug.recomputeAchievements".localized(), systemImage: "arrow.triangle.2.circlepath")
            }
            .foregroundStyle(.blue)

            Button {
                Task { await forceWidgetReload() }
            } label: {
                Label("debug.forceWidgetReload".localized(), systemImage: "rectangle.3.group")
            }
            .foregroundStyle(.blue)

            Button {
                Task { await rescheduleNotifications() }
            } label: {
                Label("debug.rescheduleNotifications".localized(), systemImage: "bell.badge")
            }
            .foregroundStyle(.blue)

            Button {
                Task { await resetHealthKitBootstrap() }
            } label: {
                Label("Reset HealthKit Bootstrap".localized(), systemImage: "heart.text.square")
            }
            .foregroundStyle(.blue)
        } header: {
            Text("Quick Actions".localized())
        } footer: {
            Text("These actions are non-destructive and can be undone by app behavior.".localized())
                .font(.caption2)
        }
    }

    private var maintenanceSection: some View {
        Section {
            Button {
                pendingAction = .clearLogs
            } label: {
                Label("debug.clearLogs".localized(), systemImage: "trash")
            }
            .foregroundStyle(.orange)

            Button {
                pendingAction = .clearImageCache
            } label: {
                Label("Clear Image Cache".localized(), systemImage: "photo.on.rectangle.angled")
            }
            .foregroundStyle(.orange)

            Button {
                pendingAction = .rerunMigration
            } label: {
                Label("Re-run JSON Migration".localized(), systemImage: "arrow.triangle.merge")
            }
            .foregroundStyle(.orange)
        } header: {
            Text("Cache Maintenance".localized())
        } footer: {
            Text("These actions clear cached data. The app will rebuild the cache on next use.".localized())
                .font(.caption2)
        }
    }

    private var dangerousSection: some View {
        Section {
            Button {
                pendingAction = .resetPreferences
            } label: {
                Label("Reset AppPreferences".localized(), systemImage: "exclamationmark.triangle")
            }
            .foregroundStyle(.red)
        } header: {
            Text("Danger Zone".localized())
        } footer: {
            Text("Resetting preferences will clear all your settings: language, theme, accent, glass effect, active phase, etc.".localized())
                .font(.caption2)
        }
    }

    // MARK: - Actions

    private enum DebugAction {
        case recomputeAchievements
        case forceWidgetReload
        case rescheduleNotifications
        case resetHealthKitBootstrap
        case clearLogs
        case clearImageCache
        case rerunMigration
        case resetPreferences
    }

    private func runAction(_ action: DebugAction) {
        switch action {
        case .recomputeAchievements:
            pendingAction = .recomputeAchievements
        case .forceWidgetReload:
            Task { await forceWidgetReload() }
        case .rescheduleNotifications:
            Task { await rescheduleNotifications() }
        case .resetHealthKitBootstrap:
            Task { await resetHealthKitBootstrap() }
        case .clearLogs:
            pendingAction = .clearLogs
        case .clearImageCache:
            pendingAction = .clearImageCache
        case .rerunMigration:
            pendingAction = .rerunMigration
        case .resetPreferences:
            pendingAction = .resetPreferences
        }
    }

    private func perform(_ action: PendingAction) {
        switch action {
        case .clearLogs:
            LogStore.shared.clear()
            statusMessage = "In-memory logs cleared.".localized()
            statusIsError = false
        case .clearImageCache:
            ImageCache.shared.clear()
            statusMessage = "Image cache cleared.".localized()
            statusIsError = false
        case .rerunMigration:
            // Force-rerun migration by clearing flag, then re-running
            UserDefaults.standard.set(false, forKey: ModelContainerFactory.migrationDoneKey)
            if let container = container.modelContainer {
                ModelContainerFactory.migrateFromJSONIfNeeded(context: container.mainContext)
                statusMessage = "Migration re-run complete. Restart the app if needed.".localized()
            } else {
                statusMessage = "ModelContainer not ready.".localized()
                statusIsError = true
            }
            statusIsError = !((statusIsError == false))
        case .resetPreferences:
            envManager.preferences = AppPreferences()
            statusMessage = "App preferences have been reset.".localized()
            statusIsError = false
        case .recomputeAchievements:
            AchievementManager.shared.handleDayRolloverIfNeeded()
            statusMessage = "Achievement recompute triggered.".localized()
            statusIsError = false
        }
    }

    // MARK: - Async Actions

    @MainActor
    private func refreshEntityCounts() async {
        isLoadingCounts = true
        defer {
            isLoadingCounts = false
            lastRefresh = Date()
        }
        guard let mc = container.modelContainer else {
            entityCounts = []
            return
        }
        entityCounts = ModelContainerFactory.entityCounts(context: mc.mainContext)
    }

    @MainActor
    private func forceWidgetReload() async {
        WidgetCenter.shared.reloadAllTimelines()
        WidgetDataSyncManager.syncUpcomingExams(
            examSets: container.examRepo.examSets,
            comprehensiveExamSets: container.examRepo.comprehensiveExamSets
        )
        TrendWidgetSyncManager.syncTrend(
            grades: container.gradeRepo.grades,
            subjects: container.subjectRepo.subjects
        )
        HRVWidgetSyncManager.syncHRV(from: hrvManager)
        statusMessage = "Widgets reloaded.".localized()
        statusIsError = false
    }

    @MainActor
    private func rescheduleNotifications() async {
        SRSReviewNotifications.shared.rescheduleAll(mistakes: container.mistakeRepo.mistakeSets)
        DailyGoalReminder.shared.reschedule(
            for: Date(),
            config: AchievementManager.shared.snapshot.config
        )
        for exam in container.examRepo.examSets {
            ExamPrepareNotifications.shared.scheduleNotifications(
                for: exam.examName,
                date: exam.examDate,
                days: exam.countdownNotifyDays
            )
        }
        statusMessage = "All notifications rescheduled.".localized()
        statusIsError = false
    }

    @MainActor
    private func resetHealthKitBootstrap() async {
        await hrvManager.bootstrap()
        statusMessage = "HealthKit bootstrap re-run.".localized()
        statusIsError = false
    }

    // MARK: - Dialog Strings

    private func dialogTitle(for action: PendingAction?) -> String {
        guard let action else { return "" }
        switch action {
        case .clearLogs: return "debug.clearLogs".localized()
        case .clearImageCache: return "Clear Image Cache".localized()
        case .rerunMigration: return "Re-run JSON Migration".localized()
        case .resetPreferences: return "Reset AppPreferences".localized()
        case .recomputeAchievements: return "Recompute Achievements".localized()
        }
    }

    private func dialogMessage(for action: PendingAction?) -> String {
        guard let action else { return "" }
        switch action {
        case .clearLogs:
            return "debug.clearLogsConfirm".localized()
        case .clearImageCache:
            return "This drops all in-memory cached images. They will be re-decoded from disk on next use.".localized()
        case .rerunMigration:
            return "This will re-read any legacy JSON files in Documents and insert their content into SwiftData. Already-migrated records will be duplicated.".localized()
        case .resetPreferences:
            return "All your settings (language, theme, accent, glass effect, active phase) will be reset to defaults. This cannot be undone.".localized()
        case .recomputeAchievements:
            return "Force re-derive the streak and achievement snapshot from stored activity logs.".localized()
        }
    }
}
