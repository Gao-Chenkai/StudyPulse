//
//  ContentView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataManager: DataManager
    
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
            
            TrendsView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Trends")
                }
            
//            MistakeView()
//                .tabItem {
//                    Image(systemName: "exclamationmark.triangle.fill")
//                    Text("Mistakes")
//                }
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
        }
    }
}


