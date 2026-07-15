//
//  AboutSettingsView.swift
//  StudyPulse
//

import SwiftUI
import AudioToolbox
@preconcurrency import CoreHaptics
import os

struct AboutSettingsView: View {
    @State private var showingCopyright = false
    @State private var showingUserAgreement = false
    @State private var isVibrating = false
    @State private var vibrationTimer: Timer?
    @State private var hapticEngine: CHHapticEngine?
    @State private var hapticPlayer: CHHapticAdvancedPatternPlayer?
    @State private var usingFallback = false
    @State private var vibrationMode: VibrationMode = .coarseImpact
    @Environment(RepositoryContainer.self) private var container

  var body: some View {
         List {
             Section {
                 SettingsDetailHeader(category: .about)
                     .listRowInsets(EdgeInsets())
                     .listRowBackground(Color.clear)
             }

                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About StudyPulse".localized(), systemImage: "info.circle")
                    }
                }

                Section {
                    Button {
                        showingCopyright = true
                    } label: {
                        Label("Copyright & License".localized(), systemImage: "checkmark.shield")
                    }
                }

                Section {
                    Button {
                        showingUserAgreement = true
                    } label: {
                        Label("User Agreement".localized(), systemImage: "doc.text")
                    }
                } footer: {
                    Text("Please read the terms carefully before using StudyPulse.".localized())
                }

                vibrationSection

                debugModeSection
         }
         .listStyle(.insetGrouped)
         .background(Color(.systemGroupedBackground))
        .containerBackground(.clear, for: .navigation)
        .debugModeContainer()
        .debugLayoutBoundsAuto()
        .navigationTitle("About".localized())
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingCopyright) {
            CopyrightView()
                .adaptiveSheet()
        }
        .sheet(isPresented: $showingUserAgreement) {
            UserAgreementView()
                .adaptiveSheet()
        }
        .onDisappear {
            stopVibration()
        }
    }

    // MARK: - Vibration Section

    @ViewBuilder
    private var vibrationSection: some View {
        Section {
            Picker(selection: $vibrationMode) {
                ForEach(VibrationMode.allCases, id: \.self) { mode in
                    Label(mode.title, systemImage: mode.icon)
                        .tag(mode)
                }
            } label: {
                Label("震动模式".localized(), systemImage: "waveform.path")
            }
            .onChange(of: vibrationMode) { _, _ in
                // 切换模式时,若正在震动则重启为新模式
                if isVibrating {
                    stopVibration()
                    startVibration()
                }
            }

            Button {
                if isVibrating {
                    stopVibration()
                } else {
                    startVibration()
                }
            } label: {
                HStack {
                    Label {
                        Text(isVibrating ? "停止震动".localized() : "开始震动".localized())
                    } icon: {
                        Image(systemName: isVibrating ? "hand.raised.slash.fill" : vibrationMode.icon)
                            .foregroundStyle(isVibrating ? .red : .orange)
                    }
                    Spacer()
                    if isVibrating {
                        ProgressView()
                            .tint(.red)
                    }
                }
            }
            .tint(isVibrating ? .red : .orange)
        } header: {
            HStack {
                Image(systemName: "waveform")
                    .foregroundStyle(.orange)
                Text("震动测试".localized())
            }
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text(vibrationMode.description)
                    .font(.caption2)
                if isVibrating {
                    Text(usingFallback
                         ? "回退模式(AudioServices 高频),点击停止。".localized()
                         : "正在运行,点击停止。".localized())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func startVibration() {
        let mode = vibrationMode
        // CoreHaptics:按模式构造 pattern,持续循环播放
        if CHHapticEngine.capabilitiesForHardware().supportsHaptics,
           let engine = try? CHHapticEngine() {
            do {
                try engine.start()
                let engineRef = engine
                engine.resetHandler = {
                    try? engineRef.start()
                }
                engine.stoppedHandler = { _ in }
                hapticEngine = engine

                let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: mode.intensity)
                let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: mode.sharpness)

                var events: [CHHapticEvent] = []
                switch mode.kind {
                case .continuous:
                    // 持续型:单个 continuous event,30 秒(CoreHaptics 实际上限)
                    events.append(CHHapticEvent(
                        eventType: .hapticContinuous,
                        parameters: [intensity, sharpness],
                        relativeTime: 0,
                        duration: 30
                    ))
                case .transient:
                    // 冲击型:在 1 个循环周期内按 interval 堆叠 transient
                    let cycle = mode.cycleDuration
                    let count = max(1, Int(cycle / mode.interval))
                    for i in 0..<count {
                        events.append(CHHapticEvent(
                            eventType: .hapticTransient,
                            parameters: [intensity, sharpness],
                            relativeTime: Double(i) * mode.interval
                        ))
                    }
                }

                let pattern = try CHHapticPattern(events: events, parameters: [])
                let player = try engine.makeAdvancedPlayer(with: pattern)
                player.loopEnabled = true
                try player.start(atTime: 0)
                hapticPlayer = player

                isVibrating = true
                usingFallback = false
                return
            } catch {
                // 失败回退到 AudioServices 高频
            }
        }

        // 回退:AudioServicesPlaySystemSound 按模式间隔触发
        vibrationTimer = Timer.scheduledTimer(withTimeInterval: max(0.05, mode.interval), repeats: true) { _ in
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        isVibrating = true
        usingFallback = true
    }

    private func stopVibration() {
        vibrationTimer?.invalidate()
        vibrationTimer = nil
        try? hapticPlayer?.stop(atTime: 0)
        hapticPlayer = nil
        hapticEngine?.stop()
        hapticEngine = nil
        isVibrating = false
    }

    // MARK: - Debug Mode Section

    @ViewBuilder
    private var debugModeSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { container.envManager.preferences.debugModeEnabled },
                set: { container.envManager.preferences.debugModeEnabled = $0 }
            )) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("debug.masterToggle".localized())
                            .foregroundColor(.primary)
                        Text("debug.masterToggleDesc".localized())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "ladybug.fill")
                        .foregroundStyle(.yellow)
                }
            }
            .tint(.yellow)
            .onChange(of: container.envManager.preferences.debugModeEnabled) { _, newValue in
                Log.preferences.info("Debug 总开关 / master toggle: -> \(newValue, privacy: .public)")
            }

            if container.envManager.preferences.debugModeEnabled {
                Toggle(isOn: Binding(
                    get: { container.envManager.preferences.debugVerboseLogging },
                    set: { container.envManager.preferences.debugVerboseLogging = $0 }
                )) {
                    Label("debug.verboseLogging".localized(), systemImage: "text.alignleft")
                }
                .tint(.yellow)

                Toggle(isOn: Binding(
                    get: { container.envManager.preferences.debugFPSOverlay },
                    set: { container.envManager.preferences.debugFPSOverlay = $0 }
                )) {
                    Label("debug.fpsOverlay".localized(), systemImage: "speedometer")
                }
                .tint(.yellow)

                Toggle(isOn: Binding(
                    get: { container.envManager.preferences.debugLayoutBounds },
                    set: { container.envManager.preferences.debugLayoutBounds = $0 }
                )) {
                    Label("debug.layoutBounds".localized(), systemImage: "rectangle.dashed")
                }
                .tint(.yellow)

                Toggle(isOn: Binding(
                    get: { container.envManager.preferences.debugLongPressInspect },
                    set: { container.envManager.preferences.debugLongPressInspect = $0 }
                )) {
                    Label("debug.longPressInspect".localized(), systemImage: "hand.point.up.left.fill")
                }
                .tint(.yellow)

                NavigationLink {
                    DebugView()
                } label: {
                    Label("debug.openConsole".localized(), systemImage: "terminal")
                }
            }
        } header: {
            HStack {
                Image(systemName: "ladybug.fill")
                    .foregroundStyle(.yellow)
                Text("debug.sectionTitle".localized())
            }
        } footer: {
            Text("debug.sectionFooter".localized())
                .font(.caption2)
        }
    }
}

// MARK: - VibrationMode

private enum VibrationMode: String, CaseIterable, Identifiable {
    /// 细腻酥麻:低强度 + 低尖锐度持续震动,轻柔嗡嗡感
    case subtleTingle
    /// 柔和持续:中等强度持续震动
    case softContinuous
    /// 强力持续:满强度持续震动,强力嗡嗡
    case strongContinuous
    /// 心跳节奏:约 1.6 次/秒的钝击,模拟心跳
    case heartbeat
    /// 急促连击:每秒 10 次中高尖锐度冲击
    case rapidTap
    /// 粗犷冲击:每秒 20 次满值 transient,运动幅度感官最强
    case coarseImpact

    var id: String { rawValue }

    var title: String {
        switch self {
        case .subtleTingle:      return "细腻酥麻".localized()
        case .softContinuous:    return "柔和持续".localized()
        case .strongContinuous:  return "强力持续".localized()
        case .heartbeat:         return "心跳节奏".localized()
        case .rapidTap:          return "急促连击".localized()
        case .coarseImpact:      return "粗犷冲击".localized()
        }
    }

    var icon: String {
        switch self {
        case .subtleTingle:      return "dot.radiowaves.left.and.right"
        case .softContinuous:    return "wave.3.right"
        case .strongContinuous:  return "wave.3.forward"
        case .heartbeat:         return "heart.fill"
        case .rapidTap:          return "hammer.fill"
        case .coarseImpact:      return "bolt.fill"
        }
    }

    var description: String {
        switch self {
        case .subtleTingle:
            return "低强度 + 低尖锐度持续波形,轻柔嗡嗡的酥麻感。".localized()
        case .softContinuous:
            return "中强度持续震动,均匀柔和。".localized()
        case .strongContinuous:
            return "满强度持续震动,强力嗡嗡感。".localized()
        case .heartbeat:
            return "约 1.6 次/秒的钝击节奏,模拟心跳。".localized()
        case .rapidTap:
            return "每秒 10 次中高尖锐度冲击,急促连击感。".localized()
        case .coarseImpact:
            return "每秒 20 次满值 transient 冲击,运动幅度感官最强。".localized()
        }
    }

    /// 事件类型:continuous = 持续波形,transient = 冲击式
    var kind: Kind {
        switch self {
        case .subtleTingle, .softContinuous, .strongContinuous:
            return .continuous
        case .heartbeat, .rapidTap, .coarseImpact:
            return .transient
        }
    }

    enum Kind { case continuous, transient }

    /// CoreHaptics 参数(0~1)
    var intensity: Float {
        switch self {
        case .subtleTingle:      return 0.3
        case .softContinuous:    return 0.6
        case .strongContinuous:  return 1.0
        case .heartbeat:         return 0.9
        case .rapidTap:          return 0.9
        case .coarseImpact:      return 1.0
        }
    }

    var sharpness: Float {
        switch self {
        case .subtleTingle:      return 0.2
        case .softContinuous:    return 0.4
        case .strongContinuous:  return 0.7
        case .heartbeat:         return 0.3
        case .rapidTap:          return 0.8
        case .coarseImpact:      return 1.0
        }
    }

    /// transient 模式下两次冲击之间的间隔(秒)
    var interval: Double {
        switch self {
        case .subtleTingle, .softContinuous, .strongContinuous:
            return 0.05  // continuous 模式不使用
        case .heartbeat:    return 0.6
        case .rapidTap:     return 0.1
        case .coarseImpact: return 0.05
        }
    }

    /// transient 模式下 pattern 的循环周期(秒)
    /// 用于计算一个循环内堆叠多少个 transient
    var cycleDuration: Double {
        switch self {
        case .heartbeat:   return 1.2   // 2 次冲击/循环
        case .rapidTap:    return 1.0   // 10 次/循环
        case .coarseImpact: return 1.0  // 20 次/循环
        default:           return 1.0
        }
    }
}
