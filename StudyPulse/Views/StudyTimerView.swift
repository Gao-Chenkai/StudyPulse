//
//  StudyTimerView.swift
//  StudyPulse
//
//  Full-screen immersive Pomodoro timer view.
//

import SwiftUI
import Combine
import UIKit
import os

// MARK: - Floating Orb (TimelineView-based)

private struct FloatingOrb: Identifiable {
    let id = UUID()
    var xRatio: CGFloat     // 0...1 horizontal position ratio
    var size: CGFloat
    var speed: Double        // seconds for one full cycle
    var phase: Double        // 0...1 starting phase
    var opacity: Double
}

// MARK: - Color Theme

private enum ColorTheme: String, CaseIterable, Identifiable {
    case aurora, sunset, ocean, forest, lavender, neon

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .aurora: return "Aurora".localized()
        case .sunset: return "Sunset".localized()
        case .ocean: return "Ocean".localized()
        case .forest: return "Forest".localized()
        case .lavender: return "Lavender".localized()
        case .neon: return "Neon".localized()
        }
    }

    var colors: [Color] {
        switch self {
        case .aurora:
            return [Color(red: 0.2, green: 0.8, blue: 0.5), Color(red: 0.1, green: 0.6, blue: 0.9), Color(red: 0.5, green: 0.3, blue: 0.9)]
        case .sunset:
            return [Color(red: 1.0, green: 0.4, blue: 0.2), Color(red: 1.0, green: 0.6, blue: 0.1), Color(red: 0.9, green: 0.2, blue: 0.5)]
        case .ocean:
            return [Color(red: 0.1, green: 0.5, blue: 0.9), Color(red: 0.0, green: 0.8, blue: 0.8), Color(red: 0.2, green: 0.3, blue: 0.9)]
        case .forest:
            return [Color(red: 0.2, green: 0.7, blue: 0.3), Color(red: 0.1, green: 0.5, blue: 0.2), Color(red: 0.6, green: 0.8, blue: 0.2)]
        case .lavender:
            return [Color(red: 0.6, green: 0.4, blue: 0.9), Color(red: 0.8, green: 0.3, blue: 0.7), Color(red: 0.4, green: 0.5, blue: 1.0)]
        case .neon:
            return [Color(red: 0.0, green: 1.0, blue: 0.5), Color(red: 1.0, green: 0.0, blue: 0.5), Color(red: 0.5, green: 0.0, blue: 1.0)]
        }
    }

    var primaryColor: Color { colors[0] }
    var icon: String {
        switch self {
        case .aurora: return "sparkles"
        case .sunset: return "sun.max.fill"
        case .ocean: return "water.waves"
        case .forest: return "leaf.fill"
        case .lavender: return "flower"
        case .neon: return "bolt.fill"
        }
    }
}

// MARK: - StudyTimerView

struct StudyTimerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var timer = StudyTimerManager.shared
    @ObservedObject private var hrv = HealthKitManager.shared
    @State private var customMinutes: Double = 25
    @State private var selectedPreset: Int? = nil
    @State private var animatedProgress: Double = 1.0

    // Dynamic animation states
    @State private var breatheScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.3
    @State private var ringRotation: Double = 0
    @State private var orbs: [FloatingOrb] = []
    @State private var showPausedPulse = false
    @State private var controlButtonScale: [Bool] = [false, false, false]
    @State private var immersiveLandscapeMode = false

    // Idle detection
    @State private var isIdle: Bool = false
    @State private var idleTimer: Timer?
    @State private var idleCount: Int = 0
    private let idleThreshold: TimeInterval = 15.0

    // Color theme
    @State private var selectedTheme: ColorTheme = .aurora
    @State private var showThemePicker: Bool = false
    @State private var flowPhase: Double = 0

    private var todaySessions: Int {
        StudySessionStore.todayTotalMinutes()
    }

    private var isActive: Bool {
        timer.timerState == .running || timer.timerState == .paused
    }

    private var isRunning: Bool {
        timer.timerState == .running
    }

    /// The current theme's primary color, used for rings / orbs / accents.
    private var themeColor: Color {
        selectedTheme.primaryColor
    }

    /// Flowing gradient colors for the progress ring.
    private var flowColors: [Color] {
        selectedTheme.colors
    }

    private var activePrimaryTextColor: Color {
        immersiveLandscapeMode ? .white : .primary
    }

    private var activeSecondaryTextColor: Color {
        immersiveLandscapeMode ? Color.white.opacity(0.72) : .secondary
    }

    private var activeSurfaceFillColor: Color {
        immersiveLandscapeMode ? Color.white.opacity(0.08) : Color(.tertiarySystemFill)
    }

    private var activeSurfaceStrokeColor: Color {
        immersiveLandscapeMode ? Color.white.opacity(0.14) : Color(.secondarySystemFill)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack(alignment: .top) {
                    // Dynamic background
                    backgroundLayer
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            revealControls()
                        }
                        .onHover { hovering in
                            if hovering {
                                revealControls()
                            }
                        }

                    VStack(spacing: 0) {
                        if isActive {
                            activeTimerBody(in: proxy.size)
                        } else {
                            setupBody
                        }
                    }

                    if immersiveLandscapeMode {
                        immersiveTopBar
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .toolbar {
                if !immersiveLandscapeMode {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.subheadline.weight(.semibold))
                        }
                        .accessibilityLabel("Close".localized())
                    }
                    ToolbarItem(placement: .principal) {
                        Text("Study Timer".localized())
                            .font(.headline)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if isActive {
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    showThemePicker.toggle()
                                }
                                wakeFromIdle()
                            } label: {
                                Image(systemName: "paintpalette.fill")
                                    .font(.subheadline)
                                    .foregroundColor(themeColor)
                            }
                        }
                    }
                }
            }
            .toolbar(immersiveLandscapeMode ? .hidden : .visible, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showThemePicker) {
                themePickerSheet
            }
        }
        .statusBarHidden(immersiveLandscapeMode)
        .persistentSystemOverlays(immersiveLandscapeMode ? .hidden : .visible)
        .onAppear {
            refreshRecommendation()
            startAmbientAnimations()
            generateOrbs()
            startIdleTimer()
        }
        .onDisappear {
            stopAmbientAnimations()
            stopIdleTimer()
            exitImmersiveLandscapeMode()
        }
        .onChange(of: timer.remainingSeconds) { _, newValue in
            guard timer.totalSeconds > 0 else { return }
            withAnimation(.easeInOut(duration: 0.5)) {
                animatedProgress = Double(newValue) / Double(timer.totalSeconds)
            }
        }
        .onChange(of: timer.timerState) { _, newState in
            if newState == .running {
                startAmbientAnimations()
            } else {
                stopAmbientAnimations()
            }
        }
    }

    // MARK: - Immersive Top Bar

    private var immersiveTopBar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(activePrimaryTextColor)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Close".localized())

            Spacer()
        }
    }

    // MARK: - Theme Picker Sheet

    private var themePickerSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Preview
                ZStack {
                    LinearGradient(
                        colors: flowColors.map { $0.opacity(0.15) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()

                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: flowColors + [flowColors[0]],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .shadow(color: themeColor.opacity(0.5), radius: 12)
                }
                .frame(height: 200)

                // Theme grid
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(ColorTheme.allCases) { theme in
                            Button {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                    selectedTheme = theme
                                }
                            } label: {
                                VStack(spacing: 10) {
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: theme.colors,
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 56, height: 56)
                                            .shadow(color: theme.primaryColor.opacity(0.4), radius: 8)

                                        if selectedTheme == theme {
                                            Circle()
                                                .stroke(Color.white, lineWidth: 3)
                                                .frame(width: 56, height: 56)
                                        }
                                    }

                                    Text(theme.displayName)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.primary)
                                }
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(selectedTheme == theme ? theme.primaryColor.opacity(0.12) : Color(.tertiarySystemFill))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Color Theme".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done".localized()) {
                        showThemePicker = false
                    }
                }
            }
        }
    }

    // MARK: - Background Layer

    private var backgroundLayer: some View {
        ZStack {
            if immersiveLandscapeMode {
                Color.black

                GeometryReader { geo in
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        landscapeFlowLayer(in: geo.size, time: t)
                    }
                }
            } else {
                // Flowing gradient background
                TimelineView(.animation(minimumInterval: 1.0/30.0)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    LinearGradient(
                        colors: [
                            flowColors[0].opacity(0.08 + 0.02 * sin(t * 0.3)),
                            Color(.systemBackground),
                            flowColors[1].opacity(0.04 + 0.02 * cos(t * 0.2))
                        ],
                        startPoint: UnitPoint(
                            x: 0.5 + 0.3 * sin(t * 0.15),
                            y: 0.5 + 0.3 * cos(t * 0.15)
                        ),
                        endPoint: UnitPoint(
                            x: 0.5 - 0.3 * sin(t * 0.15),
                            y: 0.5 - 0.3 * cos(t * 0.15)
                        )
                    )
                }
            }

            // Radial glow behind timer
            RadialGradient(
                colors: [themeColor.opacity(glowOpacity), .clear],
                center: .center,
                startRadius: 20,
                endRadius: 280
            )
            .blendMode(.plusLighter)

            // Floating orbs with TimelineView
            if isRunning {
                GeometryReader { geo in
                    TimelineView(.animation) { timeline in
                        let time = timeline.date.timeIntervalSinceReferenceDate
                        ZStack {
                            ForEach(orbs) { orb in
                                let cycle = time.truncatingRemainder(dividingBy: orb.speed) / orb.speed
                                let progress = (cycle + orb.phase).truncatingRemainder(dividingBy: 1.0)
                                let y = geo.size.height * (1.0 - progress)
                                let x = orb.xRatio * geo.size.width + sin(time * 0.5 + orb.phase * 10) * 20
                                let colorIndex = Int((time * 0.1 + orb.phase * 3).truncatingRemainder(dividingBy: Double(flowColors.count)))
                                let orbColor = flowColors[colorIndex]
                                Circle()
                                    .fill(orbColor.opacity(orb.opacity * (1.0 - progress)))
                                    .frame(width: orb.size, height: orb.size)
                                    .position(x: x, y: y)
                                    .blur(radius: 1.5)
                            }
                        }
                    }
                }
            }
        }
    }

    private func landscapeFlowLayer(in size: CGSize, time: TimeInterval) -> some View {
        ZStack {
            ForEach(Array(flowColors.enumerated()), id: \.offset) { index, color in
                let phase = Double(index) * 1.7
                let x = size.width * (0.15 + 0.7 * (0.5 + 0.5 * sin(time * (0.10 + Double(index) * 0.015) + phase)))
                let y = size.height * (0.18 + 0.64 * (0.5 + 0.5 * cos(time * (0.13 + Double(index) * 0.02) + phase * 0.8)))
                let width = min(size.width, size.height) * (0.22 + CGFloat(index) * 0.04)
                let height = width * (1.2 + CGFloat(index) * 0.12)

                Ellipse()
                    .fill(color.opacity(0.16))
                    .frame(width: width, height: height)
                    .blur(radius: 48)
                    .position(x: x, y: y)
                    .blendMode(.screen)
            }
        }
        .compositingGroup()
    }

    // MARK: - Setup body

    private var setupBody: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer().frame(height: 20)

                if timer.timerState == .completed {
                    completedBadge
                }

                recommendationHeader
                presetsGrid
                customDurationSection
                startButton

                Spacer().frame(height: 20)
                todayStats
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Active timer body

    @ViewBuilder
    private func activeTimerBody(in size: CGSize) -> some View {
        if immersiveLandscapeMode && size.width > size.height {
            immersiveLandscapeBody(in: size)
        } else {
            standardActiveTimerBody
        }
    }

    private var standardActiveTimerBody: some View {
        VStack(spacing: 0) {
            Spacer()

            timerRingView(outerGlowSize: 310, outerRingSize: 290, trackSize: 240, innerSize: 220, timeFontSize: 52)

            Spacer()

            // Control buttons (collapses when idle)
            controlButtons

            Spacer().frame(height: isIdle ? 20 : 40)
        }
    }

    private func immersiveLandscapeBody(in size: CGSize) -> some View {
        let ringWidth = min(size.height * 0.76, size.width * 0.42, 470)

        return ZStack {
            timerRingView(
                outerGlowSize: ringWidth,
                outerRingSize: ringWidth - 16,
                trackSize: ringWidth - 58,
                innerSize: ringWidth - 118,
                timeFontSize: ringWidth * 0.22
            )
            .frame(width: ringWidth, height: ringWidth)

            HStack {
                Spacer()

                controlButtons
                    .frame(width: 120)
                    .padding(.trailing, 56)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, 32)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Control Buttons

    private var controlButtons: some View {
        Group {
            if !isIdle {
                // Full controls
                let controlsLayout = immersiveLandscapeMode
                    ? AnyLayout(VStackLayout(spacing: 28))
                    : AnyLayout(HStackLayout(spacing: 48))

                controlsLayout {
                    // End button
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            controlButtonScale[0] = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                controlButtonScale[0] = false
                            }
                        }
                        timer.cancel()
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color.red.opacity(0.1))
                                    .frame(width: 60, height: 60)
                                Circle()
                                    .stroke(Color.red.opacity(0.2), lineWidth: 1)
                                    .frame(width: 60, height: 60)
                                Image(systemName: "xmark")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.red)
                            }
                            .scaleEffect(controlButtonScale[0] ? 0.9 : 1.0)

                            Text("End".localized())
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.red.opacity(0.8))
                        }
                    }
                    .buttonStyle(.plain)

                    // Play/Pause button (primary)
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                            controlButtonScale[1] = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                controlButtonScale[1] = false
                            }
                        }
                        if timer.timerState == .running {
                            timer.pause()
                        } else if timer.timerState == .paused {
                            timer.resume()
                        }
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                // Outer glow
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                timer.timerState == .paused ? Color.green : themeColor,
                                                timer.timerState == .paused ? Color.green.opacity(0.7) : themeColor.opacity(0.7)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 76, height: 76)
                                    .shadow(
                                        color: (timer.timerState == .paused ? Color.green : themeColor).opacity(0.4),
                                        radius: 12, x: 0, y: 4
                                    )

                                // Inner highlight
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.white.opacity(0.2), .clear],
                                            startPoint: .top,
                                            endPoint: .center
                                        )
                                    )
                                    .frame(width: 76, height: 76)

                                Image(systemName: timer.timerState == .paused ? "play.fill" : "pause.fill")
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .scaleEffect(controlButtonScale[1] ? 0.92 : 1.0)

                            Text(timer.timerState == .paused ? "Resume".localized() : "Pause".localized())
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(activeSecondaryTextColor)
                        }
                    }
                    .buttonStyle(.plain)

                    // Full-screen button
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            controlButtonScale[2] = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                controlButtonScale[2] = false
                            }
                        }
                        if immersiveLandscapeMode {
                            exitImmersiveLandscapeMode()
                        } else {
                            enterImmersiveLandscapeMode()
                        }
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(activeSurfaceFillColor)
                                    .frame(width: 60, height: 60)
                                Circle()
                                    .stroke(immersiveLandscapeMode ? activeSurfaceStrokeColor : themeColor.opacity(0.2), lineWidth: 1)
                                    .frame(width: 60, height: 60)
                                Image(systemName: immersiveLandscapeMode ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(themeColor)
                            }
                            .scaleEffect(controlButtonScale[2] ? 0.9 : 1.0)

                            Text(immersiveLandscapeMode ? "Exit Full Screen".localized() : "Full Screen".localized())
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(activeSecondaryTextColor)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: immersiveLandscapeMode ? 120 : .infinity)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isIdle)
    }

    // MARK: - Idle Detection

    private func startIdleTimer() {
        stopIdleTimer()
        idleCount = 0
        idleTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                idleCount += 1
                if !isIdle && isRunning && idleCount >= Int(idleThreshold) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        isIdle = true
                    }
                }
            }
        }
    }

    private func stopIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = nil
    }

    private func wakeFromIdle() {
        guard isIdle else { return }
        isIdle = false
        // Reset idle timer
        stopIdleTimer()
        startIdleTimer()
    }

    private func revealControls() {
        if isIdle {
            withAnimation(.easeOut(duration: 0.22)) {
                isIdle = false
            }
        }
        stopIdleTimer()
        startIdleTimer()
    }

    private func resetIdleTimer() {
        if isIdle {
            wakeFromIdle()
        } else {
            stopIdleTimer()
            startIdleTimer()
        }
    }

    // MARK: - Subviews

    private var completedBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 28))
                .foregroundColor(.green)
            Text("Session Complete!".localized())
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 8)
    }

    private var recommendationHeader: some View {
        VStack(spacing: 6) {
            Image(systemName: intensityIcon)
                .font(.system(size: 36))
                .foregroundColor(themeColor)

            Text(intensityTitle)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)

            Text(String(format: "Recommended: %d min".localized(),
                       timer.recommendedDurationSeconds / 60))
                .font(.system(size: 15))
                .foregroundColor(.secondary)
        }
    }

    private var presetsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(presetOptions, id: \.minutes) { preset in
                Button {
                    selectedPreset = preset.minutes
                    customMinutes = Double(preset.minutes)
                } label: {
                    VStack(spacing: 6) {
                        Text("\(preset.minutes)")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(selectedPreset == preset.minutes ? .white : .primary)
                        Text("min")
                            .font(.system(size: 12))
                            .foregroundColor(selectedPreset == preset.minutes ? .white.opacity(0.8) : .secondary)
                        if preset.isRecommended {
                            Text("Recommended".localized())
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(selectedPreset == preset.minutes ? .white.opacity(0.7) : themeColor)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(selectedPreset == preset.minutes ? themeColor : Color(.tertiarySystemFill))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                preset.isRecommended && selectedPreset != preset.minutes ? themeColor : .clear,
                                lineWidth: 2
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var customDurationSection: some View {
        VStack(spacing: 8) {
            Text("Custom Duration".localized())
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)

            HStack {
                Button {
                    customMinutes = max(5, customMinutes - 5)
                    selectedPreset = nil
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Text("\(Int(customMinutes)) min")
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .foregroundColor(.primary)
                    .frame(minWidth: 80)

                Button {
                    customMinutes = min(120, customMinutes + 5)
                    selectedPreset = nil
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }

    private var startButton: some View {
        Button {
            timer.start(seconds: Int(customMinutes) * 60)
            animatedProgress = 1.0
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                    .font(.system(size: 18, weight: .semibold))
                Text("Start Focus".localized())
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(themeColor)
            )
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }

    private var todayStats: some View {
        VStack(spacing: 8) {
            Divider()
            HStack {
                Label(
                    "\(todaySessions) min focused today".localized(),
                    systemImage: "clock.badge.checkmark"
                )
                .font(.system(size: 13))
                .foregroundColor(.secondary)

                Spacer()

                Label(
                    "\(timer.sessions.filter(\.completed).count) sessions total".localized(),
                    systemImage: "list.clipboard"
                )
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Ambient Animations

    private func generateOrbs() {
        orbs = (0..<12).map { _ in
            FloatingOrb(
                xRatio: CGFloat.random(in: 0.05...0.95),
                size: CGFloat.random(in: 3...7),
                speed: Double.random(in: 4.0...8.0),
                phase: Double.random(in: 0...1),
                opacity: Double.random(in: 0.2...0.5)
            )
        }
    }

    private func startAmbientAnimations() {
        // Breathing animation
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            breatheScale = 1.04
        }

        // Glow pulsing
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
            glowOpacity = 0.45
        }

        // Ring rotation
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
            ringRotation = 360
        }

        // Paused pulse
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            showPausedPulse = true
        }
    }

    private func stopAmbientAnimations() {
        withAnimation(.easeOut(duration: 0.5)) {
            breatheScale = 1.0
            glowOpacity = 0.15
        }
    }

    private func enterImmersiveLandscapeMode() {
        guard !immersiveLandscapeMode else { return }
        immersiveLandscapeMode = true
        requestOrientation(.landscape)
        resetIdleTimer()
    }

    private func exitImmersiveLandscapeMode() {
        guard immersiveLandscapeMode else { return }
        immersiveLandscapeMode = false
        requestOrientation(defaultOrientationMask)
        resetIdleTimer()
    }

    private var defaultOrientationMask: UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
    }

    private func requestOrientation(_ orientations: UIInterfaceOrientationMask) {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            return
        }

        let preferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: orientations)
        windowScene.requestGeometryUpdate(preferences) { error in
            Log.view.error("StudyTimer orientation update failed: \(error.localizedDescription)")
        }
        windowScene.windows
            .first(where: \.isKeyWindow)?
            .rootViewController?
            .setNeedsUpdateOfSupportedInterfaceOrientations()
    }

    // MARK: - Helpers

    private func timerRingView(
        outerGlowSize: CGFloat,
        outerRingSize: CGFloat,
        trackSize: CGFloat,
        innerSize: CGFloat,
        timeFontSize: CGFloat
    ) -> some View {
        let safeTimeFontSize = immersiveLandscapeMode ? min(timeFontSize, innerSize * 0.32) : timeFontSize
        let timeTextWidth = immersiveLandscapeMode ? innerSize * 0.74 : innerSize * 0.82

        return ZStack {
            Circle()
                .stroke(
                    AngularGradient(
                        colors: flowColors.flatMap { [$0.opacity(0.0), $0.opacity(0.4), $0.opacity(0.0)] } + [flowColors[0].opacity(0.0)],
                        center: .center,
                        startAngle: .degrees(ringRotation - 60),
                        endAngle: .degrees(ringRotation + 60)
                    ),
                    style: StrokeStyle(lineWidth: immersiveLandscapeMode ? 12 : 24, lineCap: .round)
                )
                .frame(width: outerGlowSize, height: outerGlowSize)
                .blur(radius: 12)
                .opacity(immersiveLandscapeMode ? (isRunning ? 0.26 : 0.10) : (isRunning ? 0.6 : 0.2))

            if immersiveLandscapeMode {
                Circle()
                    .stroke(Color.white.opacity(isRunning ? 0.18 : 0.10), lineWidth: 2)
                    .frame(width: outerRingSize, height: outerRingSize)
                    .scaleEffect(breatheScale)
                    .blur(radius: 0.4)
            } else {
                Circle()
                    .stroke(themeColor.opacity(0.15), lineWidth: 2)
                    .frame(width: outerRingSize, height: outerRingSize)
                    .scaleEffect(breatheScale)
                    .opacity(isRunning ? 0.5 : 0.15)
            }

            if immersiveLandscapeMode {
                Circle()
                    .stroke(Color.white.opacity(0.14), lineWidth: 8)
                    .frame(width: trackSize, height: trackSize)
            } else {
                Circle()
                    .stroke(Color(.tertiarySystemFill), lineWidth: 10)
                    .frame(width: trackSize, height: trackSize)
            }

            Circle()
                .trim(from: 0, to: 1.0 - animatedProgress)
                .stroke(
                    AngularGradient(
                        colors: flowColors + [flowColors[0]],
                        center: .center,
                        startAngle: .degrees(ringRotation - 90),
                        endAngle: .degrees(ringRotation + 270)
                    ),
                    style: StrokeStyle(lineWidth: immersiveLandscapeMode ? 8 : 10, lineCap: .round)
                )
                .frame(width: trackSize, height: trackSize)
                .rotationEffect(.degrees(-90))
                .shadow(color: themeColor.opacity(0.5), radius: 8, x: 0, y: 0)
                .animation(.easeInOut(duration: 0.5), value: animatedProgress)

            if immersiveLandscapeMode {
                nativeGlassCircle(diameter: innerSize, opacity: 0.56)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.10), lineWidth: 0.8)
                    )
            } else {
                Circle()
                    .stroke(themeColor.opacity(0.08), lineWidth: 1)
                    .frame(width: innerSize, height: innerSize)
            }

            VStack(spacing: 8) {
                Text(formatTime(timer.remainingSeconds))
                    .font(.system(size: safeTimeFontSize, weight: .bold, design: .monospaced))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [immersiveLandscapeMode ? .white : .primary, themeColor.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: timer.remainingSeconds)
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)
                    .frame(maxWidth: timeTextWidth)

                Text(timer.currentIntensity?.displayName ?? "")
                    .font(.system(size: max(15, safeTimeFontSize * 0.28), weight: .medium))
                    .foregroundColor(themeColor)
                    .opacity(0.9)

                if timer.timerState == .paused {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 6, height: 6)
                            .scaleEffect(showPausedPulse ? 1.4 : 1.0)
                            .opacity(showPausedPulse ? 0.5 : 1.0)
                        Text("Paused".localized())
                            .font(.system(size: max(13, timeFontSize * 0.22), weight: .semibold))
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.orange.opacity(0.12)))
                    .overlay(
                        Capsule().stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
                }
            }
            .frame(maxWidth: innerSize * 0.82)
        }
    }

    @ViewBuilder
    private func nativeGlassCircle(diameter: CGFloat, opacity: Double = 1.0) -> some View {
        if #available(iOS 26.0, *) {
            Color.clear
                .frame(width: diameter, height: diameter)
                .glassEffect(.regular, in: Circle())
                .opacity(opacity)
        } else {
            Circle()
                .fill(.regularMaterial)
                .frame(width: diameter, height: diameter)
                .opacity(opacity)
        }
    }

    private var presetOptions: [(minutes: Int, isRecommended: Bool)] {
        let recommended = timer.recommendedDurationSeconds / 60
        let all = [20, 25, 35, 45, 50]
        return all.sorted { abs($0 - recommended) < abs($1 - recommended) }
                  .map { ($0, $0 == recommended) }
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func refreshRecommendation() {
        let suggestion = StudyReadinessAlgorithm.recommend(
            hrvEnabled: hrv.hrvEnabled,
            hrvOnboardingCompleted: hrv.hrvOnboardingCompleted,
            isAuthorized: hrv.isAuthorized,
            hrv: hrv.readiness,
            bodyStatus: hrv.bodyStatus,
            baselines: hrv.personalBaselines,
            age: nil
        )
        if let sug = suggestion {
            timer.recommendedIntensity = intensityFromSuggestion(sug)
        }
        if selectedPreset == nil {
            customMinutes = Double(timer.recommendedDurationSeconds / 60)
        }
    }

    private func intensityFromSuggestion(_ suggestion: StudySuggestion) -> StudyIntensity {
        let t = suggestion.title
        if t == "Peak Performance".localized() || t == "\u{5DC5}\u{5CF0}\u{53D1}\u{6325}\u{65E5}" { return .peak }
        if t.hasPrefix("Deep Focus") || t.hasPrefix("\u{6DF1}\u{5EA6}\u{5B66}\u{4E60}") || t == "\u{9002}\u{5408}\u{6DF1}\u{5EA6}\u{5B66}\u{4E60}".localized() { return .deepFocus }
        if t.hasPrefix("Steady") || t.hasPrefix("\u{7A33}\u{6001}") { return .steady }
        if t.hasPrefix("Light") || t.hasPrefix("\u{8F7B}\u{91CF}") || t.contains("Mistakes") || t.contains("\u{9519}\u{9898}") { return .light }
        if t.hasPrefix("Recovery") || t.hasPrefix("Rest") || t.contains("\u{6062}\u{590D}") || t.contains("\u{4F11}\u{606F}") { return .recovery }
        return .steady
    }

    private var intensityIcon: String {
        switch timer.recommendedIntensity {
        case .peak: return "bolt.heart.fill"
        case .deepFocus: return "brain.head.profile"
        case .steady: return "chart.bar.fill"
        case .light: return "book.closed.fill"
        case .recovery: return "bed.double.fill"
        }
    }

    private var intensityTitle: String {
        switch timer.recommendedIntensity {
        case .peak: return "Peak Performance".localized()
        case .deepFocus: return "Deep Focus".localized()
        case .steady: return "Steady Rhythm".localized()
        case .light: return "Light Review".localized()
        case .recovery: return "Recovery".localized()
        }
    }
}
