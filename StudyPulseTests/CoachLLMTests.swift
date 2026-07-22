import XCTest
@testable import StudyPulse

final class CoachLLMTests: XCTestCase {
    func testPromptRequestsTheSelectedLanguageForHumanReadableFields() {
        let goal = CoachGoal(title: "Exam", subjects: [], targetDate: Date().addingTimeInterval(86400))
        let analysis = CoachAnalysisEngine.analyze(goal: goal, snapshot: CoachDataSnapshot(grades: [], mistakes: [], tasks: [], exams: []))

        let prompt = CoachLLM.makePrompt(goal: goal, analysis: analysis, languageCode: "zh-Hant")

        XCTAssertTrue(prompt.system.contains("Traditional Chinese"))
        XCTAssertTrue(prompt.system.contains("JSON keys, enum values, and ISO-8601 dates unchanged"))
    }

    func testPlanningPromptIncludesStructuredHealthContext() {
        let goal = CoachGoal(title: "Exam", subjects: [], targetDate: Date().addingTimeInterval(86400))
        let signals = CoachHealthSignals(sleepHours: 5.5, restingHeartRate: 70, respiratoryRate: 15,
                                         exerciseMinutes: 20, readinessCategory: "low", hrvZScore: -1.2,
                                         todayHRV: 42, latestHeartRate: 78, restorativeSleepHours: 1.8,
                                         psychologicalStability: 0.7, moodScore: 3, energyScore: 2)
        let analysis = CoachAnalysisEngine.analyze(
            goal: goal,
            snapshot: CoachDataSnapshot(grades: [], mistakes: [], tasks: [], exams: [], healthDataAvailable: true, healthSignals: signals)
        )
        let context = CoachLLMHealthContext(signals: signals, dataAvailable: true)
        let prompt = CoachLLM.makePrompt(goal: goal, analysis: analysis, healthContext: context)

        XCTAssertTrue(prompt.messages.contains { $0.content.contains("healthContext") })
        XCTAssertTrue(prompt.messages.contains { $0.content.contains("restorativeSleepHours") })
        XCTAssertTrue(prompt.messages.contains { $0.content.contains("readinessCategory") && $0.content.contains("low") })
    }

    func testStructuredResponseCreatesProposalWithoutChangingLocalAnalysis() throws {
        let goal = CoachGoal(title: "Exam", subjects: [CoachGoalSubject(subject: "Math", targetScore: 100)], targetDate: Date().addingTimeInterval(86400))
        let analysis = CoachAnalysisEngine.analyze(goal: goal, snapshot: CoachDataSnapshot(grades: [], mistakes: [], tasks: [], exams: []))
        let start = ISO8601DateFormatter().string(from: Date())
        let json = """
        {"conclusion":"Adjust","rationale":"Focus on fundamentals","shouldContinue":true,"items":[{"title":"Math review","subject":"Math","startDate":"\(start)","objective":"Review algebra","stopCondition":{"id":"\(UUID().uuidString)","kind":"mistakeReviewCount","value":2,"label":"Review two","targetIDs":[]},"importance":4}],"alternative":null}
        """
        let proposal = try CoachLLM.parse(output: json, goal: goal, analysis: analysis)
        XCTAssertEqual(proposal.goalID, goal.id)
        XCTAssertEqual(proposal.items.count, 1)
        XCTAssertEqual(proposal.items.first?.importance, 4)
        XCTAssertEqual(analysis.weightedPredicted, 0)
    }

    func testMalformedResponseIsRejected() {
        let goal = CoachGoal(title: "Exam", subjects: [], targetDate: Date().addingTimeInterval(86400))
        let analysis = CoachAnalysisEngine.analyze(goal: goal, snapshot: CoachDataSnapshot(grades: [], mistakes: [], tasks: [], exams: []))
        XCTAssertThrowsError(try CoachLLM.parse(output: "not-json", goal: goal, analysis: analysis))
    }

    func testConversationResponseParsesMessageAndTodoSuggestion() throws {
        let start = ISO8601DateFormatter().string(from: Date())
        let due = ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600))
        let json = """
        {"message":"Let's review this tonight.","todoSuggestions":[{"title":"Review algebra","subject":"Math","startDate":"\(start)","dueDate":"\(due)","importance":4,"notes":"Chapter 3","objective":"Strengthen fundamentals","stopCondition":{"id":"\(UUID().uuidString)","kind":"questionCount","value":10,"label":"Complete 10 questions","targetIDs":[]}}]}
        """
        let result = try CoachLLM.parseConversation(output: json, goalID: UUID())
        XCTAssertEqual(result.0, "Let's review this tonight.")
        XCTAssertEqual(result.1.count, 1)
        XCTAssertEqual(result.1.first?.status, .pending)
        XCTAssertEqual(result.1.first?.importance, 4)
    }

    func testConversationResponseAllowsMissingTodoSuggestions() throws {
        let result = try CoachLLM.parseConversation(output: "{\"message\":\"Keep going.\"}", goalID: UUID())
        XCTAssertEqual(result.0, "Keep going.")
        XCTAssertTrue(result.1.isEmpty)
    }

    func testConversationResponseExtractsJSONFromReasoningAndAllowsPromptSchema() throws {
        let start = ISO8601DateFormatter().string(from: Date())
        let output = "<think>Plan the next step.</think>```json\n{\"message\":\"开始复习。\",\"todoSuggestions\":[{\"title\":\"阅读课文\",\"startDate\":\"\(start)\",\"dueDate\":\"\(start)\",\"stopCondition\":{\"kind\":\"knowledgePoint\",\"value\":1}}]}\n```"
        let result = try CoachLLM.parseConversation(output: output, goalID: UUID())
        XCTAssertEqual(result.0, "开始复习。")
        XCTAssertEqual(result.1.first?.stopCondition.kind, .knowledgePoint)
        XCTAssertEqual(result.1.first?.subject, "")
    }
}
