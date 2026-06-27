//
//  StudyTimerView.swift
//  StudyPulse
//
//  Full-screen immersive Pomodoro timer view.
//

import SwiftUI
import Combine

struct StudyTimerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var timer = StudyTimerManager.shared
    @ObservedObject private var hrv = HealthKitManager.shared
    @State private var customMinutes: Double = 25
    @State private var selectedPreset: Int? = nil
    @State private var animatedProgress: Double = 1.0

    private var todaySessions: Int {
        StudySessionStore.todayTotalMinutes()
    }

    private var isActive: Bool {
        timer.timerState == .running || timer.timerState == .paused
    }

    var body: some View {
        NavigationStack {
            ZStack {
                intensityColor.opacity(0.06)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    if isActive {
                        activeTimerBody
                    } else {
                        setupBody
                    }
                }
            }
            .toolbar {
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
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            refreshRecommendation()
        }
        .onChange(of: timer.remainingSeconds) { _, newValue in
            guard timer.totalSeconds > 0 else { return }
            withAnimation(.linear(duration: 0.3)) {
                animatedProgress = Double(newValue) / Double(timer.totalSeconds)
            }
        }
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

    private var activeTimerBody: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(Color(.tertiarySystemFill), lineWidth: 12)
                    .frame(width: 240, height: 240)

                Circle()
                    .trim(from: 0, to: 1.0 - animatedProgress)
                    .stroke(
                        AngularGradient(
                            colors: [intensityColor, intensityColor.opacity(0.7)],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 240, height: 240)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.3), value: animatedProgress)

                VStack(spacing: 4) {
                    Text(formatTime(timer.remainingSeconds))
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)

                    Text(timer.currentIntensity?.displayName ?? "")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(intensityColor)

                    if timer.timerState == .paused {
                        Text("Paused".localized())
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.orange.opacity(0.15)))
                    }
                }
            }

            Spacer()

            HStack(spacing: 40) {
                Button {
                    timer.cancel()
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.red)
                            .frame(width: 56, height: 56)
                            .background(Circle().fill(Color.red.opacity(0.12)))
                        Text("End".localized())
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                    }
                }
                .buttonStyle(.plain)

                Button {
                    if timer.timerState == .running {
                        timer.pause()
                    } else if timer.timerState == .paused {
                        timer.resume()
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: timer.timerState == .paused ? "play.fill" : "pause.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                            .frame(width: 72, height: 72)
                            .background(
                                Circle().fill(
                                    timer.timerState == .paused ? Color.green : Color.orange
                                )
                            )
                        Text(timer.timerState == .paused ? "Resume".localized() : "Pause".localized())
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)

                Button {
                    dismiss()
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.secondary)
                            .frame(width: 56, height: 56)
                            .background(Circle().fill(Color(.tertiarySystemFill)))
                        Text("Minimize".localized())
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }

            Spacer().frame(height: 40)
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
                .foregroundColor(intensityColor)

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
                                .foregroundColor(selectedPreset == preset.minutes ? .white.opacity(0.7) : intensityColor)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(selectedPreset == preset.minutes ? intensityColor : Color(.tertiarySystemFill))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                preset.isRecommended && selectedPreset != preset.minutes ? intensityColor : .clear,
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
                    .fill(intensityColor)
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

    // MARK: - Helpers

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

    private var intensityColor: Color {
        switch timer.recommendedIntensity {
        case .peak: return .green
        case .deepFocus: return .blue
        case .steady: return .indigo
        case .light: return .orange
        case .recovery: return .red
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
