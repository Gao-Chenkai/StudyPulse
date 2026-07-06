//
//  StudyTimerSettingsSheet.swift
//  StudyPulse
//
//  Pomodoro setup body (recommendation / presets / custom duration) and
//  the color theme picker sheet.
//

import SwiftUI
import os

// MARK: - StudyTimerSetupSheet

/// Idle / setup body shown before a Pomodoro session starts. Owns the
/// preset selection and custom minute state.
struct StudyTimerSetupSheet: View {
    @ObservedObject var timer: StudyTimerManager
    @ObservedObject var hrv: HealthKitManager

    /// Currently selected color theme (drives the start button + presets).
    let selectedTheme: ColorTheme

    /// Bindings so that presets and the start button can write into the
    /// parent's state without re-deriving from the recommendation.
    @Binding var customMinutes: Double
    @Binding var selectedPreset: Int?

    /// Called when the user taps "Start Focus" — the parent starts the
    /// timer, animates the progress, and switches to the active body.
    let onStart: () -> Void

    private var themeColor: Color { selectedTheme.primaryColor }

    var body: some View {
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

                HistorySummaryInline()
            }
            .padding(.horizontal, 24)
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
            Image(systemName: StudyIntensityUI.icon)
                .font(.system(size: 36))
                .foregroundColor(themeColor)

            Text(StudyIntensityUI.title)
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
            onStart()
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

    // MARK: - Helpers

    private var presetOptions: [(minutes: Int, isRecommended: Bool)] {
        let recommended = timer.recommendedDurationSeconds / 60
        let all = [20, 25, 35, 45, 50]
        return all.sorted { abs($0 - recommended) < abs($1 - recommended) }
                  .map { ($0, $0 == recommended) }
    }
}

// MARK: - Recommendation Refresh

/// Pulls the algorithm suggestion and applies it to the timer manager.
/// Called by `StudyTimerView.onAppear` and whenever HRV signals change.
enum StudyTimerRecommendation {
    @MainActor
    static func refresh(timer: StudyTimerManager, hrv: HealthKitManager, selectedPreset: Int?, customMinutes: inout Double) {
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
}

// MARK: - Color Theme Picker

struct StudyTimerThemePickerSheet: View {
    @Binding var selectedTheme: ColorTheme

    private var themeColor: Color { selectedTheme.primaryColor }
    private var flowColors: [Color] { selectedTheme.colors }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                themePreview
                themeGrid
            }
            .navigationTitle("Color Theme".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done".localized()) {
                        // Dismissal is handled by the parent's `.sheet` binding.
                    }
                }
            }
        }
    }

    private var themePreview: some View {
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
    }

    private var themeGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(ColorTheme.allCases) { theme in
                    Button {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            selectedTheme = theme
                        }
                    } label: {
                        themeTile(theme)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
    }

    @ViewBuilder
    private func themeTile(_ theme: ColorTheme) -> some View {
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
}
