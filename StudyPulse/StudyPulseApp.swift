//
//  StudyPulseApp.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import SwiftUI
import SwiftData
import UserNotifications
import WidgetKit
import os

// 1. 新增：专门处理通知代理的类
class NotificationCoordinator: NSObject, UNUserNotificationCenterDelegate {

    // 处理前台收到通知的情况
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // 即使在前台，也显示横幅、播放声音、更新角标
        completionHandler([[.banner, .sound, .badge]])
    }

    // 处理用户点击通知的情况
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // 核心代码：点击通知后强制清除角标
        // Core: clear badge after user taps the notification
        center.setBadgeCount(0)
        Log.notification.info("用户点击了通知，已强制清除角标 / User tapped notification, badge cleared")

        // 这里可以添加跳转逻辑 / Navigation logic could be added here
        // ...

        completionHandler()
    }
}

@main
struct StudyPulseApp: App {
    @State private var container: RepositoryContainer = RepositoryContainer()
    @StateObject private var envManager = AppEnvironmentManager.shared
    @StateObject private var hrvManager = HealthKitManager.shared
    @StateObject private var timerManager = StudyTimerManager.shared
    @Environment(\.scenePhase) private var scenePhase

    // 2. 声明协调器实例
    private let notificationCoordinator = NotificationCoordinator()

    init() {
        // 3. 将代理设置为我们的协调器实例 / Set our coordinator as the delegate
        UNUserNotificationCenter.current().delegate = notificationCoordinator
        Log.notification.info("通知代理已注册 / Notification delegate registered")
        Log.record(.info, category: "Notification", message: "通知代理已注册 / Notification delegate registered")

        // 请求通知权限 / Request notification authorization
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                Log.notification.error("通知授权请求失败 / Notification authorization request failed: \(error.localizedDescription)")
                return
            }
            if granted {
                Log.notification.info("用户允许了通知 / User granted notification permission")
            } else {
                Log.notification.info("用户拒绝了通知 / User denied notification permission")
            }
        }

        // 启动时清除角标 / Clear badge on launch
        UNUserNotificationCenter.current().setBadgeCount(0)
        Log.app.info("启动时已清除角标 / Badge cleared on launch")
        Log.record(.info, category: "App", message: "启动时已清除角标 / Badge cleared on launch")

        // 应用已保存的语言偏好 / Apply saved language preference
        AppEnvironmentManager.shared.applyLanguageOnLaunch()
        Log.app.info("已应用语言偏好 / Language preference applied")
        Log.record(.info, category: "App", message: "已应用语言偏好 / Language preference applied")

        // 启动主线程卡顿监测 / Start main thread lag monitoring
        LagMonitor.shared.start()
        Log.record(.info, category: "App", message: "主线程卡顿监测已启动 / Lag monitor started")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(container)
                .environmentObject(envManager)
                .environmentObject(hrvManager)
                .environmentObject(timerManager)
                .preferredColorScheme(envManager.effectiveColorScheme)
                .task {
                    // 初始化 RepositoryContainer:JSON 迁移 + 7 个 repo 并行 loadAll
                    await container.asyncInit()
                    Log.app.info("异步数据加载完成 / Async data load complete; isReady=\(container.isReady, privacy: .public)")
                    Log.record(.info, category: "App", message: "异步数据加载完成 / Async data load complete; isReady=\(container.isReady)")
                    // 主数据加载就绪后再去问 HealthKit，避免启动期 I/O 竞争
                    // Ask HealthKit only after the main data is ready to avoid I/O contention at launch
                    await hrvManager.bootstrap()
                    await MainActor.run {
                        AchievementManager.shared.bootstrap(container: container)
                    }
                    Log.app.info("HealthKit bootstrap 完成 / HealthKit bootstrap complete")
                    Log.record(.info, category: "App", message: "HealthKit bootstrap 完成 / HealthKit bootstrap complete")

                    // 例程物化 + Live Activity 恢复(2026-07-09 新增)
                    let spawner = RoutineSpawner(container: container)
                    spawner.runOnce()
                    // 若当前有进行中的 routine,恢复 Live Activity
                    RoutineLiveActivityController.shared.restoreIfNeeded(container: container)
                    // 检查今天/明天 30 分钟内是否有 routine 即将开始,尝试启动
                    if let inst = container.routineInstanceRepo.activeInstances.first,
                       let routine = container.routineRepo.routines.first(where: { $0.id == inst.routineId }) {
                        RoutineLiveActivityController.shared.startIfNeeded(routine: routine, instance: inst)
                    }
                }
                .onChange(of: scenePhase) {
                    let phase = scenePhase
                    Log.app.debug("场景阶段变化 / Scene phase changed: -> \(String(describing: phase), privacy: .public)")
                    if phase == .active {
                        // 数据未就绪时跳过 widget 同步，避免写入空数据
                        // Skip widget sync if data is not ready to avoid writing empty data
                        guard container.isReady else {
                            Log.app.debug("数据未就绪，跳过 widget 同步 / Data not ready, skipping widget sync")
                            return
                        }
                        Log.widget.info("应用进入前台，开始同步 widget / App became active, syncing widgets")
                        Log.record(.info, category: "Widget", message: "应用进入前台，开始同步 widget / App became active, syncing widgets")
                        WidgetDataSyncManager.syncUpcomingExams(
                            examSets: container.examRepo.examSets,
                            comprehensiveExamSets: container.examRepo.comprehensiveExamSets
                        )
                        TrendWidgetSyncManager.syncTrend(grades: container.gradeRepo.grades, subjects: container.subjectRepo.subjects)
                        HRVWidgetSyncManager.syncHRV(from: hrvManager)
                        // 同步 SRS 复习通知（错题已 opt-in 但尚未到期的）
                        timerManager.cleanupStaleActivities()
                        SRSReviewNotifications.shared.rescheduleAll(mistakes: container.mistakeRepo.mistakeSets)
                        // 从系统 Reminders 拉取任务完成态（幂等，重复调用安全）
                        // Pull task completion flags from the system Reminders app (idempotent)
                        container.taskRepo.refreshCompletionStatesFromReminders()
                        Task { await hrvManager.refreshBodyStatus() }
                        AchievementManager.shared.handleDayRolloverIfNeeded()
                        DailyGoalReminder.shared.reschedule(for: Date(), config: AchievementManager.shared.snapshot.config)
                    }
                    // 离开前台时收尾 routine Live Activity
                    if phase == .background {
                        RoutineLiveActivityController.shared.end()
                    }
                }
        }
        // 注入 SwiftData 容器,与 RepositoryContainer.asyncInit 通过 ModelContainerFactory
        // 的进程内单例缓存共享同一 ModelContainer。
        .modelContainer(ModelContainerFactory.makeContainer())
        // Markdown 编辑器的场景级菜单(iPadOS 26 窗口化模式顶部菜单栏
        // + 外接键盘快捷键)。菜单项仅在 MarkdownEditorView 在屏时显示。
        // Scene-level menu commands that surface the markdown editor's
        // 13 formatting actions + 2 view toggles in the iPadOS 26
        // windowed-mode menu bar and as keyboard shortcuts. The menus
        // hide themselves when no `MarkdownEditorView` is on screen.
        .commands {
            MarkdownCommands()
        }
    }
}
