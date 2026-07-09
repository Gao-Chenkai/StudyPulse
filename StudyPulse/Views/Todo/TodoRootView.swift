//
//  TodoRootView.swift
//  StudyPulse
//
//  Todo Tab 的根视图,包含两个子页签:
//  - Tasks: 原 TodoView
//  - Routines: 新增的 RoutinesView
//
//  Picker 不再固定在顶部,而是作为子视图滚动内容的一部分。
//
//  Created for Plans & Routines spec (2026-07-09).
//

import SwiftUI

struct TodoRootView: View {
    let container: RepositoryContainer
    @State private var segment: Segment = .tasks

    enum Segment: String, CaseIterable, Identifiable {
        case tasks
        case routines
        var id: String { rawValue }
        var title: String {
            switch self {
            case .tasks:    return "Tasks".localized()
            case .routines: return "Routines".localized()
            }
        }
        var icon: String {
            switch self {
            case .tasks:    return "checklist"
            case .routines: return "repeat.circle"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch segment {
                case .tasks:
                    TodoView(container: container, segment: $segment)
                case .routines:
                    RoutinesView(segment: $segment)
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    TodoRootView(container: RepositoryContainer())
        .environmentObject(AppEnvironmentManager.shared)
}
#endif
