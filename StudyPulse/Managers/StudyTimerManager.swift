
@preconcurrency import ActivityKit
import Combine
import Foundation
import os

// MARK: - Study Timer Palette

/// Centralised colour & icon palette used by the StudyTimer Live Activity
/// (Lock Screen + Dynamic Island). The widget extension shares these
/// values via `StudyTimerActivityAttributes`; the main app also uses them
/// to keep in-app UI and the Live Activity in lockstep.
enum StudyTimerPalette {
    static let peakHex        = "34C759"   // green
    static let deepFocusHex   = "0A84FF"   // blue
    static let steadyHex      = "5856D6"   // indigo
    static let lightHex       = "FF9500"   // orange
    static let recoveryHex    = "FF3B30"   // red

    static let pausedHex      = "FF9500"   // orange (matches pause UI)
    static let completeHex    = "34C759"   // green
    static let endedHex       = "FF3B30"   // red

    /// Brand gradient used for the StudyPulse mark on the Lock Screen.
    static let brandGradient: [String] = [
        "0A84FF", // blue
        "5856D6"  // indigo
    ]
}

// MARK: - Timer State

enum TimerState: Equatable {
    case idle
    case running
    case paused
    case completed
}

// MARK: - Study Timer Manager

/// Manages the Pomodoro-style countdown timer, the Live Activity on
/// Dynamic Island / Lock Screen, and persistence of completed
/// sessions to `StudySessionStore`.
///
/// Session durations are adapted from the current
/// `StudyReadinessAlgorithm` intensity:
///   peak → 50 min, deepFocus → 45 min, steady → 35 min,
///   light → 25 min, recovery → 20 min.
@MainActor
final class StudyTimerManager: ObservableObject {
    static let shared = StudyTimerManager()

    // MARK: - Published state

    @Published var timerState: TimerState = .idle
    @Published var remainingSeconds: Int = 0
    @Published var totalSeconds: Int = 0
    @Published var currentIntensity: StudySession.SessionIntensity?
    @Published var sessions: [StudySession] = []

    /// The current algorithm recommendation — read by the View layer
    /// to show the suggested intensity before the user starts.
    @Published var recommendedIntensity: StudyIntensity = .steady

    // MARK: - Live Activity handle

    private var currentActivity: Activity<StudyTimerActivityAttributes>?

    // MARK: - Internal timer

    private var internalTimer: Timer?
    private var targetEndDate: Date?

    private init() {
        sessions = StudySessionStore.load()
    }

    // MARK: - Duration calculation

    /// Recommended duration in seconds for the current algorithm intensity.
    var recommendedDurationSeconds: Int {
        let sessionIntensity = StudySession.fromAlgorithmIntensity(recommendedIntensity)
        return sessionIntensity.recommendedDurationSeconds
    }

    /// Recommended duration as a human-readable string.
    var recommendedDurationLabel: String {
        let mins = recommendedDurationSeconds / 60
        return "\(mins) min"
    }

    // MARK: - Timer controls

    /// Start a countdown timer for the given number of seconds.
    /// If `seconds` is nil, the recommended duration is used.
    func start(seconds: Int? = nil) {
        let duration = seconds ?? recommendedDurationSeconds
        guard duration > 0 else { return }

        let intensity = StudySession.fromAlgorithmIntensity(recommendedIntensity)
        currentIntensity = intensity
        totalSeconds = duration
        remainingSeconds = duration
        targetEndDate = Date().addingTimeInterval(TimeInterval(duration))
        timerState = .running

        startLiveActivity(intensity: intensity, totalSeconds: duration)
        startInternalTimer()

        Log.app.info("StudyTimer started: intensity=\(intensity.rawValue) duration=\(duration)s")
    }

    /// Pause the timer; keeps the Live Activity but shows "Paused".
    func pause() {
        guard timerState == .running else { return }
        internalTimer?.invalidate()
        internalTimer = nil
        timerState = .paused
        updateLiveActivity()
        Log.app.info("StudyTimer paused at remaining=\(self.remainingSeconds)s")
    }

    /// Resume from paused state.
    func resume() {
        guard timerState == .paused else { return }
        targetEndDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        timerState = .running
        startInternalTimer()
        updateLiveActivity()
        Log.app.info("StudyTimer resumed at remaining=\(self.remainingSeconds)s")
    }

    /// Cancel the timer and discard the session.
    func cancel() {
        internalTimer?.invalidate()
        internalTimer = nil
        let wasRunning = timerState == .running || timerState == .paused
        timerState = .idle
        remainingSeconds = 0
        totalSeconds = 0
        targetEndDate = nil

        if wasRunning, let intensity = currentIntensity {
            let session = StudySession(
                id: UUID(),
                startDate: Date(),
                durationSeconds: 0,
                intensity: intensity,
                completed: false
            )
            sessions = StudySessionStore.append(session)
            Log.app.info("StudyTimer cancelled (recorded as incomplete)")
        }
        endLiveActivity()
        currentIntensity = nil
    }

    /// Called when the timer reaches 0 naturally.
    private func complete() {
        internalTimer?.invalidate()
        internalTimer = nil
        timerState = .completed
        remainingSeconds = 0

        if let intensity = currentIntensity {
            let session = StudySession(
                id: UUID(),
                startDate: Date().addingTimeInterval(-TimeInterval(totalSeconds)),
                durationSeconds: totalSeconds,
                intensity: intensity,
                completed: true
            )
            sessions = StudySessionStore.append(session)
            Log.app.info("StudyTimer completed: intensity=\(intensity.rawValue) duration=\(self.totalSeconds)s")
        }
        endLiveActivity()
    }

    /// Reset from completed state back to idle.
    func reset() {
        timerState = .idle
        remainingSeconds = 0
        totalSeconds = 0
        targetEndDate = nil
        currentIntensity = nil
    }

    // MARK: - Internal timer tick

    private func startInternalTimer() {
        internalTimer?.invalidate()
        internalTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    private func tick() {
        guard let target = targetEndDate else { return }
        let remaining = max(0, Int(target.timeIntervalSinceNow))
        remainingSeconds = remaining

        // Update the Live Activity every 5 ticks to reduce overhead.
        if remaining % 5 == 0 {
            updateLiveActivity()
        }

        if remaining <= 0 {
            complete()
        }
    }

    // MARK: - Live Activity lifecycle

    private func startLiveActivity(intensity: StudySession.SessionIntensity, totalSeconds: Int) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            Log.app.warning("StudyTimer: Live Activities not authorized, skipping activity start")
            return
        }

        let formatter = ISO8601DateFormatter()
        let attrs = StudyTimerActivityAttributes(
            intensityLabel: intensity.displayName,
            intensityIcon: intensity.icon,
            colorHex: intensity.colorHex,
            tier: intensity.rawValue,
            totalMinutes: totalSeconds / 60
        )
        let content = ActivityContent(
            state: StudyTimerActivityAttributes.ContentState(
                remainingSeconds: totalSeconds,
                totalSeconds: totalSeconds,
                intensityLabel: intensity.displayName,
                intensityIcon: intensity.icon,
                colorHex: intensity.colorHex,
                tier: intensity.rawValue,
                targetEndISO: formatter.string(from: Date().addingTimeInterval(TimeInterval(totalSeconds)))
            ),
            staleDate: Date().addingTimeInterval(TimeInterval(totalSeconds + 60))
        )

        do {
            let activity = try Activity.request(
                attributes: attrs,
                content: content,
                pushType: nil
            )
            currentActivity = activity
            Log.app.info("StudyTimer Live Activity started: id=\(activity.id)")
        } catch {
            Log.app.error("StudyTimer Live Activity failed to start: \(error.localizedDescription)")
        }
    }

    private func updateLiveActivity() {
        guard currentActivity != nil else { return }
        let formatter = ISO8601DateFormatter()
        let targetISO = timerState == .paused
            ? formatter.string(from: Date().addingTimeInterval(TimeInterval(remainingSeconds)))
            : formatter.string(from: targetEndDate ?? Date())
        let isPaused = timerState == .paused
        let label = isPaused ? "Paused".localized() : (currentIntensity?.displayName ?? "")
        let icon = isPaused ? "pause.circle.fill" : (currentIntensity?.icon ?? "timer")
        let hex = isPaused ? StudyTimerPalette.pausedHex : (currentIntensity?.colorHex ?? StudyTimerPalette.steadyHex)
        let tier = isPaused ? "paused" : (currentIntensity?.rawValue ?? "steady")

        let content = ActivityContent(
            state: StudyTimerActivityAttributes.ContentState(
                remainingSeconds: remainingSeconds,
                totalSeconds: totalSeconds,
                intensityLabel: label,
                intensityIcon: icon,
                colorHex: hex,
                tier: tier,
                targetEndISO: targetISO
            ),
            staleDate: Date().addingTimeInterval(TimeInterval(remainingSeconds + 120))
        )

        Task { @MainActor in
            if let activity = currentActivity {
                await activity.update(content)
            }
        }
    }

    private func endLiveActivity() {
        guard currentActivity != nil else { return }
        let formatter = ISO8601DateFormatter()
        let isCompleted = timerState == .completed
        let finalLabel = isCompleted
            ? "Session Complete".localized()
            : "Session Ended".localized()
        let finalIcon = isCompleted
            ? "checkmark.circle.fill"
            : "xmark.circle.fill"
        let finalHex = isCompleted
            ? StudyTimerPalette.completeHex
            : StudyTimerPalette.endedHex
        let finalTier = isCompleted ? "completed" : "ended"
        let finalContent = ActivityContent(
            state: StudyTimerActivityAttributes.ContentState(
                remainingSeconds: 0,
                totalSeconds: totalSeconds,
                intensityLabel: finalLabel,
                intensityIcon: finalIcon,
                colorHex: finalHex,
                tier: finalTier,
                targetEndISO: formatter.string(from: Date())
            ),
            staleDate: Date().addingTimeInterval(60)
        )

        Task { @MainActor in
            if let activity = currentActivity {
                await activity.end(finalContent, dismissalPolicy: .immediate)
                Log.app.info("StudyTimer Live Activity ended")
            }
            currentActivity = nil
        }
    }

    /// Clean up stale live activities on app foreground. We only end
    /// activities that are already in a terminal state (completed /
    /// ended). Activities for a still-running timer are left alone so
    /// the Dynamic Island keeps showing the countdown.
    func cleanupStaleActivities() {
        Task { @MainActor in
            for activity in Activity<StudyTimerActivityAttributes>.activities {
                let tier = activity.content.state.tier
                if tier == "completed" || tier == "ended" {
                    await activity.end(nil, dismissalPolicy: .immediate)
                    Log.app.info("StudyTimer: cleaned up stale terminal activity id=\(activity.id)")
                }
            }
        }
    }
}
