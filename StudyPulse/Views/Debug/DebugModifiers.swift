//
//  DebugModifiers.swift
//  StudyPulse
//
//  Debug 模式专用 View 修饰符：
//  - .debugLayoutBounds()   打开时画 1px 随机色边框 + 5% 底色
//  - .debugInspect(value:)  长按弹 alert 显示原始值与类型
//

import SwiftUI
import os

// MARK: - Layout Bounds

struct DebugLayoutBoundsModifier: ViewModifier {
    let enabled: Bool
    private let seed: UInt64

    init(enabled: Bool) {
        self.enabled = enabled
        // 用 view identity 的 hash 作随机种子,使同一个 view 总是同一颜色
        self.seed = UInt64.random(in: 0...UInt64.max)
    }

    func body(content: Content) -> some View {
        if enabled {
            content
                .overlay(
                    Rectangle()
                        .strokeBorder(borderColor, lineWidth: 0.5)
                )
                .background(borderColor.opacity(0.05))
        } else {
            content
        }
    }

    private var borderColor: Color {
        // 用 seed 生成稳定的 hue
        let hue = Double(seed % 360) / 360.0
        return Color(hue: hue, saturation: 0.8, brightness: 0.9)
    }
}

extension View {
    /// 当 AppEnvironmentManager.debugLayoutBounds 开启时,显示 1px 随机色边框 + 5% 底色。
    /// Marks the view with a 1px debug border + 5% tinted background when Debug → Layout Bounds is on.
    func debugLayoutBounds(_ enabled: Bool) -> some View {
        modifier(DebugLayoutBoundsModifier(enabled: enabled))
    }
}

// MARK: - Long-press Inspect

struct DebugInspectModifier<T>: ViewModifier {
    let value: T
    let label: String
    @State private var showingAlert: Bool = false

    func body(content: Content) -> some View {
        content
            .onLongPressGesture(minimumDuration: 0.5) {
                showingAlert = true
            }
            .alert("debug.inspect.title".localized(), isPresented: $showingAlert) {
                Button("Copy".localized()) {
                    UIPasteboard.general.string = String(describing: value)
                }
                Button("OK".localized(), role: .cancel) {}
            } message: {
                Text(inspectMessage)
            }
    }

    private var inspectMessage: String {
        let typeName = String(describing: type(of: value))
        return """
        \(label)
        Type: \(typeName)
        Value: \(String(describing: value))
        """
    }
}

extension View {
    /// 当 AppEnvironmentManager.debugLongPressInspect 开启时,长按该 view 弹 alert 显示原始值与类型。
    /// Long-press to inspect the raw value when Debug → Long-press Inspect is on.
    func debugInspect<T>(_ value: T, label: String) -> some View {
        modifier(DebugInspectModifier(value: value, label: label))
    }
}

// MARK: - Container 修饰符（顶 banner + 右上角浮窗）

struct DebugModeContainerModifier: ViewModifier {
    @EnvironmentObject private var envManager: AppEnvironmentManager
    @State private var showDebugConsole: Bool = false

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) {
                if envManager.isDebugModeActive {
                    DebugBannerView {
                        showDebugConsole = true
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .overlay(alignment: .topTrailing) {
                if envManager.debugModeEnabled && envManager.debugFPSOverlay {
                    DebugFPSOverlayView()
                        .padding(.top, envManager.isDebugModeActive ? 36 : 8)
                        .padding(.trailing, 12)
                        .allowsHitTesting(true)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: envManager.isDebugModeActive)
            .navigationDestination(isPresented: $showDebugConsole) {
                DebugView()
                    .environmentObject(envManager)
            }
    }
}

extension View {
    /// 把 Debug 模式的黄色顶部 banner 和右上角 FPS 浮窗挂到当前 view。
    /// Attaches the yellow Debug Mode banner and the FPS overlay to this view.
    /// 应在每个主页面 NavigationStack 内的根 view 上调用一次。
    func debugModeContainer() -> some View {
        modifier(DebugModeContainerModifier())
    }
}

// MARK: - 便捷修饰符

extension View {
    /// 当 Debug 模式开启时,显示 1px 随机色边框 + 5% 底色。
    /// 自动从 EnvironmentObject 读取 `AppEnvironmentManager.debugLayoutBounds`。
    /// Use this on any view to opt in to the layout-bounds overlay.
    /// Reads the toggle automatically from `AppEnvironmentManager`.
    func debugLayoutBoundsAuto() -> some View {
        modifier(DebugLayoutBoundsAutoModifier())
    }

    /// 当 Debug 模式开启时,长按该 view 弹 alert 显示原始值与类型。
    /// 自动从 EnvironmentObject 读取 `AppEnvironmentManager.debugLongPressInspect`。
    /// Use this on any view to opt in to the long-press inspector.
    /// Reads the toggle automatically from `AppEnvironmentManager`.
    func debugInspectAuto<T>(_ value: T, label: String) -> some View {
        modifier(DebugInspectAutoModifier(value: value, label: label))
    }
}

private struct DebugLayoutBoundsAutoModifier: ViewModifier {
    @EnvironmentObject private var envManager: AppEnvironmentManager
    func body(content: Content) -> some View {
        content.debugLayoutBounds(envManager.debugLayoutBounds)
    }
}

private struct DebugInspectAutoModifier<T>: ViewModifier {
    @EnvironmentObject private var envManager: AppEnvironmentManager
    let value: T
    let label: String
    func body(content: Content) -> some View {
        if envManager.debugLongPressInspect {
            content.debugInspect(value, label: label)
        } else {
            content
        }
    }
}

#if DEBUG
#Preview {
    VStack {
        Text("Tap me long-press")
            .padding()
            .debugLayoutBounds(true)
            .debugInspect("Hello, World!", label: "Greeting")

        Text("Plain text")
            .padding()
            .debugLayoutBounds(true)
    }
}
#endif
