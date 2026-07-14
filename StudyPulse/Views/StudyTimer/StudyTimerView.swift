//
//  StudyTimerView.swift
//  StudyPulse
//
//  Full-screen immersive Pomodoro timer view — coordinator that wires
//  the timer card, the setup / theme settings, and the session history.
//
//  Sub-modules (kept under Views/StudyTimer/):
//    - StudyTimerActiveCard.swift     → active ring + controls + ambient FX
//    - StudyTimerSettingsSheet.swift  → setup body + color theme picker
//    - StudyTimerHistoryList.swift    → today's totals + recent sessions
//    - StudyTimerShared.swift         → shared types / helpers
//

import SwiftUI
import os

struct StudyTimerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(RepositoryContainer.self) private var container
    @ObservedObject private var timer = StudyTimerManager.shared
    @ObservedObject private var hrv = HealthKitManager.shared

    // Shared view state
    @State private var customMinutes: Double = 25
    @State private var selectedPreset: Int? = nil
    @State private var immersiveLandscapeMode = false
    @State private var showThemePicker: Bool = false

    private var isActive: Bool {
        timer.timerState == .running || timer.timerState == .paused
    }

    private var activeAnimation: TimerAnimation {
        container.envManager.effectiveTimerAnimation
    }

    var body: some View {
        NavigationStack {
            Group {
                if isActive {
                    StudyTimerActiveCard(
                        timer: timer,
                        immersiveLandscapeMode: $immersiveLandscapeMode,
                        animation: activeAnimation,
                        onImmersiveToggle: toggleImmersiveLandscape,
                        onUserInteraction: {}
                    )
                } else {
                    StudyTimerSetupSheet(
                        timer: timer,
                        hrv: hrv,
                        animation: activeAnimation,
                        customMinutes: $customMinutes,
                        selectedPreset: $selectedPreset,
                        onStart: startSession
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                            } label: {
                                Image(systemName: "paintpalette.fill")
                                    .font(.subheadline)
                                    .foregroundColor(activeAnimation.primaryColor)
                            }
                        }
                    }
                }
            }
            .toolbar(immersiveLandscapeMode ? .hidden : .visible, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showThemePicker) {
                StudyTimerQuickThemeSheet()
            }
        }
        .statusBarHidden(immersiveLandscapeMode)
        .persistentSystemOverlays(immersiveLandscapeMode ? .hidden : .visible)
        .onAppear {
            refreshRecommendation()
        }
        .onDisappear {
            exitImmersiveLandscapeMode()
        }
    }

    // MARK: - Actions

    private func startSession() {
        timer.start(seconds: Int(customMinutes) * 60)
    }

    private func toggleImmersiveLandscape() {
        if immersiveLandscapeMode {
            exitImmersiveLandscapeMode()
        } else {
            enterImmersiveLandscapeMode()
        }
    }

    private func enterImmersiveLandscapeMode() {
        // Note: we intentionally do NOT call `requestGeometryUpdate(.landscape)`
        // here. On iOS 16+ that API only declares a *supported* orientation —
        // it cannot force a rotation. When the device is still in portrait the
        // system briefly re-lays out the view in landscape and then snaps back,
        // and that transient layout change can dismiss the surrounding
        // `fullScreenCover`. The "immersive" experience is therefore scoped
        // to UI chrome (toolbar / status bar / larger ring) and respects the
        // device's physical orientation. The user can rotate the device by
        // hand if they want true landscape.
        guard !immersiveLandscapeMode else { return }
        immersiveLandscapeMode = true
    }

    private func exitImmersiveLandscapeMode() {
        guard immersiveLandscapeMode else { return }
        immersiveLandscapeMode = false
    }

    // MARK: - Recommendation

    private func refreshRecommendation() {
        StudyTimerRecommendation.refresh(
            timer: timer,
            hrv: hrv,
            selectedPreset: selectedPreset,
            customMinutes: &customMinutes
        )
    }
}
