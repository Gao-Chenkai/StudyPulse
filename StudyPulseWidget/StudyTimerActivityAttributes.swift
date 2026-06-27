
import ActivityKit
import Foundation

/// Live Activity attributes for the StudyPulse Pomodoro timer.
/// Shared between the main app (which starts/updates/ends the activity)
/// and the widget extension (which renders the Lock Screen & Dynamic Island UI).
struct StudyTimerActivityAttributes: ActivityAttributes {
    /// Static: set once when the activity starts.
    public struct ContentState: Codable, Hashable {
        /// Remaining seconds in the countdown.
        var remainingSeconds: Int
        /// Total session duration in seconds.
        var totalSeconds: Int
        /// Label for the intensity tier (e.g. "Deep Focus", "Light Review").
        var intensityLabel: String
        /// SF Symbol name for the intensity icon.
        var intensityIcon: String
        /// 6-digit hex (RRGGBB) for the tier accent color — the widget
        /// extension uses this so it can render the correct theme without
        /// re-deriving the tier from the SF Symbol.
        var colorHex: String
        /// Raw tier key (e.g. "peak", "deepFocus", "steady", "light",
        /// "recovery", "paused", "completed", "ended") — the widget
        /// extension uses this to choose copy & decorative ornaments.
        var tier: String
        /// Target time as an ISO 8601 string — the activity uses this
        /// so the Lock Screen countdown stays accurate without pushes.
        var targetEndISO: String
    }

    /// Stored once at activity start: the displayed label / icon for the
    /// tier, so the widget does not have to re-derive them.
    var intensityLabel: String
    /// Stored once at activity start: the SF Symbol name for the tier.
    var intensityIcon: String
    /// 6-digit hex (RRGGBB) for the tier accent color.
    var colorHex: String
    /// Raw tier key (see ContentState.tier).
    var tier: String
    /// Total session duration in minutes (used for the widget subtitle).
    var totalMinutes: Int
}
