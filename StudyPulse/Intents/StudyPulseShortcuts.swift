import AppIntents

/// Registers all StudyPulse shortcuts with the system so they appear in
/// the Shortcuts app, Spotlight, and are invocable via Siri.
/// 把 StudyPulse 的所有 Shortcut 注册到系统,使其出现在 Shortcuts App、
/// Spotlight 搜索中,并可通过 Siri 调用。
struct StudyPulseShortcuts: AppShortcutsProvider {

    /// Siri 唤起短语集合 —— 每条都映射到对应的 AppIntent
    /// Siri invocation phrases — each maps to the corresponding `AppIntent`.
    static var appShortcuts: [AppShortcut] {
        // MARK: - Log Score
        // MARK: - 记录成绩 / Log Score
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

        // MARK: - Record Mistake
        // MARK: - 记录错题 / Record Mistake
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

        // MARK: - Upcoming Exams
        // MARK: - 即将到来的考试 / Upcoming Exams
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

        // MARK: - Subject Average
        // MARK: - 学科平均分 / Subject Average
        AppShortcut(
            intent: CheckSubjectAverageIntent(),
            phrases: [
                "Check my average in \(.applicationName)",
                "What's my \(\.$subject) average in \(.applicationName)",
            ],
            shortTitle: "Subject Average",
            systemImageName: "chart.bar.fill"
        )

        // MARK: - Study Readiness
        // MARK: - 学习就绪度 / Study Readiness
        AppShortcut(
            intent: CheckReadinessIntent(),
            phrases: [
                "Check my study readiness in \(.applicationName)",
                "How ready am I to study in \(.applicationName)",
            ],
            shortTitle: "Study Readiness",
            systemImageName: "heart.fill"
        )

        // MARK: - Body Status
        // MARK: - 身体状态 / Body Status
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
