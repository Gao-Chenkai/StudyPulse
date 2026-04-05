//
//  StudyPulseApp.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import SwiftUI
import WSOnBoarding
import UserNotifications

// 👇 1. 新增：专门处理通知代理的类
class NotificationCoordinator: NSObject, UNUserNotificationCenterDelegate {
    
    // 处理前台收到通知的情况
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // 即使在前台，也显示横幅、播放声音、更新角标
        completionHandler([[.banner, .sound, .badge]])
    }
    
    // 处理用户点击通知的情况
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // 核心代码：点击通知后强制清除角标
        center.setBadgeCount(0)
        print("👆 用户点击了通知，已强制清除角标！")
        
        // 这里可以添加跳转逻辑
        // ...
        
        completionHandler()
    }
}

@main
struct StudyPulseApp: App {
    @StateObject private var dataManager = DataManager()
    
    // 👇 2. 声明协调器实例
    private let notificationCoordinator = NotificationCoordinator()
    
    init() {
        // 👇 3. 将代理设置为我们的协调器实例
        UNUserNotificationCenter.current().delegate = notificationCoordinator

        // 请求通知权限
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ 用户允许了通知")
            }
        }
        
        // 启动时清除角标
        UNUserNotificationCenter.current().setBadgeCount(0)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataManager)
                .wsWelcomeView(
                    config: WSWelcomeConfig.welcomeInfo,
                    style: .standard
                )
                .preferredColorScheme(.light)
        }
    }
}
