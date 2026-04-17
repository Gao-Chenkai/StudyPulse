//
//  ContentView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedTab = 0
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    var body: some View {
        TabView (selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)
            
            TrendsView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Trends")
                }
                .tag(1)
            
//            MistakeView()
//                .tabItem {
//                    Image(systemName: "exclamationmark.triangle.fill")
//                    Text("Mistakes")
//                }
//                .tag(2)
            
            ExamView()
                .tabItem {
                    Image(systemName: "list.bullet.clipboard")
                    Text("Exams")
                }
                .tag(3)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
                .tag(4)
            
        }
        .tint(.cyan)
        
        
        .onChange(of: selectedTab) { oldValue, newValue in
            print("Tab 切换检测: 从 \(oldValue) 变到 \(newValue)")            
            if oldValue != newValue {
                print("准备触发震动...")
                triggerHaptic()
            }
        }
    }
    
    private func triggerHaptic() {
        // 将震动逻辑放入后台队列，或者稍微延迟一点点，让UI先渲染出来
        // 这样用户看到的是界面先切过去，然后手震一下，感觉会流畅很多
        // 上面两行是AI写的，本来想解决更新完打开APP时首次点击Tab栏的卡顿，但现在看起来并无什么卵用
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            impactFeedback.prepare()
            impactFeedback.impactOccurred()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DataManager())
}


