//
//  IntentActionStore.swift
//  StudyPulse
//
//  App Intent → ContentView 的导航桥接。
//  Bridge between App Intents and ContentView for "open app to pre-filled form".
//
//  Intents 在后台线程设置 pendingIntentAction;ContentView 在 MainActor 读取 + 弹 sheet。
//  拆成独立 singleton 是因为 Intents / Widgets 跨进程上下文访问时不能依赖 @MainActor 实例。
//

import Foundation
import Combine

/// 单例:持有当前待消费的 IntentAction。
/// App Intents (background) 写入,ContentView (MainActor) 读取并消费。
@MainActor
final class IntentActionStore: ObservableObject {
    static let shared = IntentActionStore()

    @Published var pendingIntentAction: IntentAction? = nil

    private init() {}

    /// 提供一个线程安全的写入入口(在 Intent 的 `perform` 闭包里 await 即可)。
    nonisolated static func setPending(_ action: IntentAction?) {
        Task { @MainActor in
            IntentActionStore.shared.pendingIntentAction = action
        }
    }
}
