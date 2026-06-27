import AppIntents

/// Registers all StudyPulse shortcuts with the system so they appear in
/// the Shortcuts app, Spotlight, and are invocable via Siri.
struct StudyPulseShortcuts: AppShortcutsProvider {

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddGradeIntent(),
            phrases: [
                "Log a score in \(.applicationName)",
                "Log my \(\.$subject) score in \(.applicationName)",
                "Record a grade in \(.applicationName)",
                "Add a grade in \(.applicationName)",
                "\(.applicationName) log score",
            ],
            shortTitle: "Log Score",
            systemImageName: "plus.circle.fill"
        )

        AppShortcut(
            intent: RecordMistakeIntent(),
            phrases: [
                "Record a mistake in \(.applicationName)",
                "Log a mistake in \(.applicationName)",
                "Add a mistake note in \(.applicationName)",
            ],
            shortTitle: "Record Mistake",
            systemImageName: "exclamationmark.triangle.fill"
        )

        AppShortcut(
            intent: CheckUpcomingExamsIntent(),
            phrases: [
                "Check upcoming exams in \(.applicationName)",
                "What exams do I have in \(.applicationName)",
                "Show my exams in \(.applicationName)",
            ],
            shortTitle: "Upcoming Exams",
            systemImageName: "list.clipboard.fill"
        )

        AppShortcut(
            intent: CheckSubjectAverageIntent(),
            phrases: [
                "Check my average in \(.applicationName)",
                "What's my \(\.$subject) average in \(.applicationName)",
            ],
            shortTitle: "Subject Average",
            systemImageName: "chart.bar.fill"
        )

        AppShortcut(
            intent: CheckReadinessIntent(),
            phrases: [
                "Check my study readiness in \(.applicationName)",
                "How ready am I to study in \(.applicationName)",
            ],
            shortTitle: "Study Readiness",
            systemImageName: "heart.fill"
        )

        AppShortcut(
            intent: CheckBodyStatusIntent(),
            phrases: [
                "Check my body status in \(.applicationName)",
                "How did I sleep in \(.applicationName)",
            ],
            shortTitle: "Body Status",
            systemImageName: "figure.walk"
        )
    }
}
