//
//  StudyPulseApp.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import SwiftUI
import WSOnBoarding
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
    @StateObject private var dataManager = DataManager()
    @StateObject private var envManager = AppEnvironmentManager.shared
    @StateObject private var hrvManager = HealthKitManager.shared
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
                .environmentObject(dataManager)
                .environmentObject(envManager)
                .environmentObject(hrvManager)
                .preferredColorScheme(envManager.effectiveColorScheme)
                .versionedWelcomeView()
                .task {
                    // 后台并行加载所有 JSON，避免阻塞主线程
                    // Load all JSON files in parallel to avoid blocking the main thread
                    Log.app.info("开始异步加载数据 / Starting async data load")
                    Log.record(.info, category: "App", message: "开始异步加载数据 / Starting async data load")
                    await dataManager.asyncInit()
                    Log.app.info("异步数据加载完成 / Async data load complete; isReady=\(dataManager.isReady, privacy: .public)")
                    Log.record(.info, category: "App", message: "异步数据加载完成 / Async data load complete; isReady=\(dataManager.isReady)")
                    // 主数据加载就绪后再去问 HealthKit，避免启动期 I/O 竞争
                    // Ask HealthKit only after the main data is ready to avoid I/O contention at launch
                    await hrvManager.bootstrap()
                    Log.app.info("HealthKit bootstrap 完成 / HealthKit bootstrap complete")
                    Log.record(.info, category: "App", message: "HealthKit bootstrap 完成 / HealthKit bootstrap complete")
                }
                .onChange(of: scenePhase) {
                    let phase = scenePhase
                    Log.app.debug("场景阶段变化 / Scene phase changed: -> \(String(describing: phase), privacy: .public)")
                    if phase == .active {
                        // 数据未就绪时跳过 widget 同步，避免写入空数据
                        // Skip widget sync if data is not ready to avoid writing empty data
                        guard dataManager.isReady else {
                            Log.app.debug("数据未就绪，跳过 widget 同步 / Data not ready, skipping widget sync")
                            return
                        }
                        Log.widget.info("应用进入前台，开始同步 widget / App became active, syncing widgets")
                        Log.record(.info, category: "Widget", message: "应用进入前台，开始同步 widget / App became active, syncing widgets")
                        WidgetDataSyncManager.syncUpcomingExams(
                            examSets: dataManager.examSets,
                            comprehensiveExamSets: dataManager.comprehensiveExamSets
                        )
                        TrendWidgetSyncManager.syncTrend(grades: dataManager.grades, subjects: dataManager.subjects)
                        HRVWidgetSyncManager.syncHRV(from: hrvManager)
                        Task { await hrvManager.refreshBodyStatus() }
                    }
                }
        }
    }
}
