//
//  ContentView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import SwiftUI
import UIKit

// MARK: - 应用标签枚举（用于侧边栏 / 底部 Tab 栏共享）
enum AppTab: Int, CaseIterable, Identifiable, Hashable {
    case home = 0
    case trends = 1
    case mistake = 2
    case todo = 3
    case settings = 4

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .home: return "Home".localized()
        case .trends: return "Trends".localized()
        case .mistake: return "Mistakes".localized()
        case .todo: return "Todo".localized()
        case .settings: return "Settings".localized()
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .trends: return "chart.bar.fill"
        case .mistake: return "exclamationmark.triangle.fill"
        case .todo: return "checklist"
        case .settings: return "gearshape.fill"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var selectedTab: AppTab = .home
    @State private var showingAddGradeFromIntent = false
    @State private var showingNewMistakeFromIntent = false
    @State private var currentIntentAction: IntentAction? = nil
   private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        Group {
            if sizeClass == .regular {
                iPadSidebarLayout(selectedTab: $selectedTab)
            } else {
                iPhoneTabLayout(selectedTab: $selectedTab)
            }
        }
        .tint(.cyan)
        .overlay(alignment: .top) {
            AchievementUnlockToast()
        }
        // 首次启动 welcome 流程结束后，把用户填写的基础资料写入 DataManager
        .versionedWelcomeView { draft, selectedSubjects in
            dataManager.commitOnboardingProfile(
                draft: draft,
                selectedSubjectNames: selectedSubjects
            )
        }
        .focusable()
        .onKeyPress(.tab) {
            selectedTab = nextTab()
            return .handled
        }
        .onKeyPress(keys: Set(["1", "2", "3", "4", "5"].map { KeyEquivalent($0) })) { key in
            let idx: Int? = switch key.key.character {
            case "1": 0
            case "2": 1
            case "3": 2
            case "4": 3
            case "5": 4
            default: nil
            }
            if let i = idx, let tab = AppTab(rawValue: i) {
                selectedTab = tab
                return .handled
            }
            return .ignored
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            if oldValue != newValue {
                triggerHaptic()
            }
        }
        // ===== App Intent Navigation Bridge =====
        .onChange(of: dataManager.pendingIntentAction) { _, action in
           guard let action = action else { return }
            currentIntentAction = action
           selectedTab = .home
            switch action {
            case .addGrade:
                showingAddGradeFromIntent = true
            case .recordMistake:
                showingNewMistakeFromIntent = true
            }
            dataManager.pendingIntentAction = nil
        }
       .sheet(isPresented: $showingAddGradeFromIntent) {
            if case let .addGrade(subject, score, examName) = currentIntentAction {
                AddGradeView(presetSubject: subject, presetScore: score, presetExamName: examName)
                    .environmentObject(dataManager)
            } else {
                AddGradeView()
                    .environmentObject(dataManager)
            }
       }
       .sheet(isPresented: $showingNewMistakeFromIntent) {
            if case let .recordMistake(subject, title) = currentIntentAction {
                NewMistakeSetView(presetSubject: subject, presetTitle: title)
                    .environmentObject(dataManager)
            } else {
                NewMistakeSetView()
                    .environmentObject(dataManager)
            }
       }
    }

    private func nextTab() -> AppTab {
        let all = AppTab.allCases
        let idx = all.firstIndex(of: selectedTab) ?? 0
        return all[(idx + 1) % all.count]
    }

    private func triggerHaptic() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            impactFeedback.prepare()
            impactFeedback.impactOccurred()
        }
    }
}

// MARK: - iPad 传统侧边栏布局
struct iPadSidebarLayout: View {
    @Binding var selectedTab: AppTab
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var selection: AppTab?

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $selection) {
                ForEach(AppTab.allCases) { tab in
                    NavigationLink(value: tab) {
                        Label {
                            Text(tab.title)
                                .font(.body)
                        } icon: {
                            Image(systemName: tab.icon)
                        }
                        .padding(.vertical, 4)
                    }
                    .tag(tab)
                }
            }
            .navigationTitle("StudyPulse")
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
            .onChange(of: selection) { _, newValue in
                if let newValue = newValue {
                    selectedTab = newValue
                }
            }
            .onAppear {
                selection = selectedTab
            }
        } detail: {
            detailView(for: selectedTab)
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func detailView(for tab: AppTab) -> some View {
        switch tab {
        case .home:
            HomeView(selectedTab: intBinding)
        case .trends:
            TrendsView()
        case .mistake:
            MistakeView()
        case .todo:
            TodoView()
        case .settings:
            SettingsView()
        }
    }

    private var intBinding: Binding<Int> {
        Binding<Int>(
            get: { selectedTab.rawValue },
            set: { newValue in
                if let tab = AppTab(rawValue: newValue) {
                    selectedTab = tab
                }
            }
        )
    }
}

// MARK: - iPhone 底部 Tab 栏布局
struct iPhoneTabLayout: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: intBinding)
                .tabItem { Label(AppTab.home.title, systemImage: AppTab.home.icon) }
                .tag(AppTab.home)

            TrendsView()
                .tabItem { Label(AppTab.trends.title, systemImage: AppTab.trends.icon) }
                .tag(AppTab.trends)

            MistakeView()
                .tabItem { Label(AppTab.mistake.title, systemImage: AppTab.mistake.icon) }
                .tag(AppTab.mistake)

            TodoView()
                .tabItem { Label(AppTab.todo.title, systemImage: AppTab.todo.icon) }
                .tag(AppTab.todo)

            SettingsView()
                .tabItem { Label(AppTab.settings.title, systemImage: AppTab.settings.icon) }
                .tag(AppTab.settings)
        }
    }

    private var intBinding: Binding<Int> {
        Binding<Int>(
            get: { selectedTab.rawValue },
            set: { newValue in
                if let tab = AppTab(rawValue: newValue) {
                    selectedTab = tab
                }
            }
        )
    }
}

#Preview {
    ContentView()
        .environmentObject(DataManager())
}
