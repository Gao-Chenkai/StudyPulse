import Foundation

/// Bridge between App Intents and DataManager for navigation to pre-filled forms.
///
/// When an open-app intent fires, it sets the corresponding case on
/// `DataManager.pendingIntentAction`.  ContentView observes that
/// property and presents the matching sheet with pre-populated fields.
enum IntentAction: Equatable, Sendable {
    case addGrade(subject: String, score: Double, examName: String?)
    case recordMistake(subject: String, title: String)
}
