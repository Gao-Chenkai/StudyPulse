//
//  TodoRootView.swift
//  StudyPulse
//
//  Todo Tab 的根视图。原 Tasks/Routines 双 segment 已合并:
//  例程现在作为待办列表的第 5 种类型(与考试/作业/阅读并列)在 TodoView 内展示。
//  保留本文件作为 ContentView 的入口薄包装(TodoView 自带 NavigationStack)。
//

import SwiftUI

struct TodoRootView: View {
    let container: RepositoryContainer

    var body: some View {
        TodoView(container: container)
    }
}

#if DEBUG
#Preview {
    let container = RepositoryContainer()
    TodoRootView(container: container)
        .environment(container)
}
#endif
