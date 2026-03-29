//
//  StudyPulseApp.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import SwiftUI
import WSOnBoarding

@main
struct StudyPulseApp: App {
    @StateObject private var dataManager = DataManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataManager)
                .wsWelcomeView(
                                    config: WSWelcomeConfig.welcomeInfo, // 要显示的应用信息
                                    style: .standard // 预设的外观风格（.standard 或 .immersive）
                                )
        }
    }
}
