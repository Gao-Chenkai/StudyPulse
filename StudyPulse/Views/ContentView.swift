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
            
            MistakeView()
                .tabItem {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("Mistakes")
                }
                .tag(2)
            
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
        
        .onChange(of: selectedTab) { oldValue, newValue in
            print("Tab 切换检测: 从 \(oldValue) 变到 \(newValue)") // 1. 确认这里打印了没
            
            if oldValue != newValue {
                print("准备触发震动...") // 2. 确认这里打印了没
                triggerHaptic()
            }
        }
    }
    
    private func triggerHaptic() {
        print("震动引擎准备 (Prepare)")
        impactFeedback.prepare()
        
        print("震动发生 (Impact Occurred)")
        impactFeedback.impactOccurred()
        
        // 强制延迟一点打印，确保你看得到顺序
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("震动指令已发送")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DataManager())
}


