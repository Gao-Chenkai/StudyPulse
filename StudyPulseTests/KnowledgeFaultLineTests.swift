import XCTest
@testable import StudyPulse

final class KnowledgeFaultLineTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_750_000_000)

    private func makeMistake(
        id: UUID = UUID(),
        title: String = "题目",
        subject: String = "Physics",
        date: Date? = nil,
        reason: String = "",
        tags: [String] = [],
        mastery: Double = 0.2,
        lapses: Int = 0,
        history: [MasteryHistoryEntry] = []
    ) -> MistakeNote {
        let reviewState = lapses > 0
            ? ReviewState(nextReviewDate: now, lastReviewDate: now, lapses: lapses)
            : nil
        return MistakeNote(
            id: id,
            title: title,
            subject: subject,
            originalQuestion: "question",
            source: "test",
            date: date ?? now,
            errorReason: reason,
            wrongSolution: "wrong",
            correctSolution: "correct",
            reviewState: reviewState,
            masteryScore: mastery,
            masteryHistory: history,
            tags: tags
        )
    }

    func testRuleClassificationCoversKnowledgeFaultCategories() {
        let cases: [(String, KnowledgeFaultCategory)] = [
            ("比例关系没有保持", .proportionalReasoning),
            ("单位换算错了", .unitConversion),
            ("不会列方程建模", .equationModeling),
            ("概念定义混淆", .conceptDefinition),
            ("遗漏条件和边界", .conditionBoundary),
            ("方法选择错误", .methodSelection),
            ("符号计算算错", .symbolicCalculation),
            ("审题读题漏信息", .readingTranslation),
            ("忘记定义", .foundationalMemory)
        ]

        for (reason, expected) in cases {
            let node = KnowledgeFaultLineEngine.localNodes(for: [makeMistake(reason: reason)]).first
            XCTAssertEqual(node?.category, expected, reason)
        }
    }

    func testTagsHavePriorityForTargetConcept() {
        let node = KnowledgeFaultLineEngine.localNodes(for: [
            makeMistake(title: "复杂题", reason: "单位换算", tags: ["动量"])
        ]).first

        XCTAssertEqual(node?.targetConcept, "动量")
        XCTAssertEqual(node?.category, .unitConversion)
        XCTAssertEqual(node?.source, .rules)
    }

    func testRepeatedPrerequisiteAggregatesAcrossSubjectsAndDeduplicates() {
        let a = makeMistake(subject: "Physics", reason: "单位换算", mastery: 0.4)
        let b = makeMistake(subject: "Chemistry", reason: "单位换算", mastery: 0.7)
        let scan = KnowledgeFaultLineEngine.scan(mistakes: [a, b], now: now)

        let line = try! XCTUnwrap(scan.repeatedFaultLines.first)
        XCTAssertEqual(line.impactMistakeCount, 2)
        XCTAssertEqual(line.subjects, ["Chemistry", "Physics"])
        XCTAssertEqual(Set(line.relatedMistakeIDs), Set([a.id, b.id]))
    }

    func testRecentFailuresRaiseRiskAndPrioritizeRelatedMistake() {
        let recentAgain = MasteryHistoryEntry(
            timestamp: now.addingTimeInterval(-86_400),
            score: 0.1,
            quality: 1
        )
        let highRisk = makeMistake(
            title: "高风险",
            date: now.addingTimeInterval(-86_400),
            reason: "单位换算",
            mastery: 0.05,
            lapses: 3,
            history: [recentAgain]
        )
        let lowerRisk = makeMistake(
            title: "低风险",
            date: now.addingTimeInterval(-86_400 * 5),
            reason: "单位换算",
            mastery: 0.9
        )
        let line = try! XCTUnwrap(KnowledgeFaultLineEngine.scan(mistakes: [highRisk, lowerRisk], now: now).repeatedFaultLines.first)

        XCTAssertGreaterThan(line.recentRecurrenceCount, 0)
        XCTAssertGreaterThan(line.riskScore, 0.4)
        XCTAssertEqual(line.relatedMistakes.first?.title, "高风险")
    }

    func testSingleOccurrenceIsAvailableForDetailButNotHomeRepeatedList() {
        let scan = KnowledgeFaultLineEngine.scan(mistakes: [makeMistake(reason: "方程建模")], now: now)

        XCTAssertEqual(scan.faultLines.count, 1)
        XCTAssertTrue(scan.repeatedFaultLines.isEmpty)
        XCTAssertNotNil(scan.node(for: scan.nodes[0].mistakeID))
    }

    func testEmptyInputIsSafe() {
        let scan = KnowledgeFaultLineEngine.scan(mistakes: [], now: now)
        XCTAssertEqual(scan, .empty)
    }

    func testUnknownAIIDsAreIgnoredAndTriggerFallback() {
        let mistake = makeMistake(reason: "单位换算")
        let unknownExtraction = KnowledgeFaultAIExtraction(
            mistakeID: UUID(),
            targetConcept: "不属于当前集合",
            prerequisiteConcepts: ["单位制与量纲"],
            foundationConcept: "数量与单位意识",
            category: .unitConversion,
            evidence: "unknown"
        )

        let scan = KnowledgeFaultLineEngine.scan(
            mistakes: [mistake],
            extractions: [unknownExtraction],
            now: now
        )

        XCTAssertEqual(scan.aiAppliedCount, 0)
        XCTAssertTrue(scan.usedFallback)
        XCTAssertEqual(scan.node(for: mistake.id)?.source, .rules)
    }

    @MainActor
    func testRequestGateAllowsBootstrapThenWaitsForFiveNewMistakesAcrossInstances() {
        let suiteName = "KnowledgeFaultLineTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let gate = KnowledgeFaultLineRequestGate(defaults: defaults, baselineKey: "baseline")
        let initial = makeMistake()
        let fourNew = [initial] + (0..<4).map { _ in makeMistake() }
        let fiveNew = fourNew + [makeMistake()]

        XCTAssertTrue(gate.shouldAutomaticallyRequest(for: [initial]))
        gate.markRequestCompleted(for: [initial])

        let recreatedGate = KnowledgeFaultLineRequestGate(defaults: defaults, baselineKey: "baseline")
        XCTAssertFalse(recreatedGate.shouldAutomaticallyRequest(for: fourNew))
        XCTAssertTrue(recreatedGate.shouldAutomaticallyRequest(for: fiveNew))
    }

    func testAIParserAcceptsValidItemsAndDropsInvalidOnes() {
        let validID = UUID()
        let text = """
        ```json
        {"items":[
          {"mistake_id":"\(validID.uuidString)","target_concept":"动量","prerequisites":["比例关系"],"foundation":"数量与单位意识","category":"unit_conversion","evidence":"单位未统一","confidence":0.9},
          {"mistake_id":"not-a-uuid","target_concept":"坏数据","prerequisites":[],"foundation":"x","category":"unknown"}
        ]}
        ```
        """

        let parsed = KnowledgeFaultLineLLM.parse(text)
        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed.first?.mistakeID, validID)
        XCTAssertEqual(parsed.first?.category, .unitConversion)
    }

    @MainActor
    func testViewModelShowsLocalFallbackWhenAIIsUnavailable() {
        let mistake = makeMistake(reason: "单位换算")
        let repository = MockMistakeRepository(mistakes: [mistake])
        let container = RepositoryContainer(mistakeRepo: repository)
        let viewModel = KnowledgeFaultLineViewModel(container: container)

        viewModel.recompute()

        XCTAssertFalse(viewModel.scan.nodes.isEmpty)
        XCTAssertTrue(viewModel.scan.usedFallback)
        XCTAssertFalse(viewModel.isLoadingAI)
    }

    @MainActor
    func testViewModelAppliesPartialAIResultsAndKeepsRulesForMissingItems() async {
        let first = makeMistake(reason: "单位换算")
        let second = makeMistake(reason: "方程建模")
        let extraction = KnowledgeFaultAIExtraction(
            mistakeID: first.id,
            targetConcept: "动量",
            prerequisiteConcepts: ["单位制与量纲"],
            foundationConcept: "数量与单位意识",
            category: .unitConversion,
            evidence: "AI evidence"
        )
        let provider = StubKnowledgeFaultAIProvider(result: [extraction])
        let container = RepositoryContainer(mistakeRepo: MockMistakeRepository(mistakes: [first, second]))
        let viewModel = KnowledgeFaultLineViewModel(
            container: container,
            aiProvider: provider,
            configuration: configuredLLMConfig,
            requestGate: makeTestRequestGate()
        )

        viewModel.recompute()
        for _ in 0..<3 { await Task.yield() }

        XCTAssertEqual(viewModel.scan.node(for: first.id)?.source, .ai)
        XCTAssertEqual(viewModel.scan.node(for: second.id)?.source, .rules)
        XCTAssertEqual(viewModel.scan.aiAppliedCount, 1)
        XCTAssertTrue(viewModel.scan.usedFallback)
        XCTAssertFalse(viewModel.isLoadingAI)
        XCTAssertEqual(provider.callCount, 1)
    }

    @MainActor
    func testViewModelAIErrorKeepsLocalScanAndExposesError() async {
        let mistake = makeMistake(reason: "单位换算")
        let provider = StubKnowledgeFaultAIProvider(error: LLMError.network("offline"))
        let container = RepositoryContainer(mistakeRepo: MockMistakeRepository(mistakes: [mistake]))
        let viewModel = KnowledgeFaultLineViewModel(
            container: container,
            aiProvider: provider,
            configuration: configuredLLMConfig,
            requestGate: makeTestRequestGate()
        )

        viewModel.recompute()
        for _ in 0..<3 { await Task.yield() }

        XCTAssertNotNil(viewModel.aiErrorMessage)
        XCTAssertEqual(viewModel.scan.node(for: mistake.id)?.source, .rules)
        XCTAssertTrue(viewModel.scan.usedFallback)
        XCTAssertFalse(viewModel.isLoadingAI)
    }

    @MainActor
    func testViewModelDoesNotCallAIAgainForSameFingerprint() async {
        let mistake = makeMistake(reason: "单位换算")
        let provider = StubKnowledgeFaultAIProvider(result: [])
        let container = RepositoryContainer(mistakeRepo: MockMistakeRepository(mistakes: [mistake]))
        let viewModel = KnowledgeFaultLineViewModel(
            container: container,
            aiProvider: provider,
            configuration: configuredLLMConfig,
            requestGate: makeTestRequestGate()
        )

        viewModel.recompute()
        viewModel.recompute()
        for _ in 0..<3 { await Task.yield() }

        XCTAssertEqual(provider.callCount, 1)
    }

    @MainActor
    func testRepairTaskFactoryDefaultsAndEditedDraft() {
        let line = makeFaultLine()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let fixedNow = Date(timeIntervalSince1970: 1_750_000_000)
        let draft = KnowledgeRepairTaskFactory.defaultDraft(for: line, now: fixedNow, calendar: calendar)

        XCTAssertEqual(draft.subject, "Physics")
        XCTAssertEqual(draft.importance, 3)
        XCTAssertEqual(draft.dueDate.timeIntervalSince(draft.reminderDate), 15 * 60, accuracy: 1)
        XCTAssertTrue(draft.notes.contains(line.foundationConcept))

        var edited = draft
        edited.title = "重建单位换算"
        edited.importance = 5
        edited.notes = "重新检查量纲"
        let task = edited.makeTask()

        XCTAssertEqual(task?.title, "重建单位换算")
        XCTAssertEqual(task?.importance, 5)
        XCTAssertEqual(task?.notes, "重新检查量纲")
    }

    @MainActor
    func testRepairTaskSaverPersistsLocallyWhenReminderSyncFails() async {
        let (container, mocks) = TestRepositoryContainerFactory.makeMockContainer()
        let provider = StubKnowledgeRepairReminderProvider(error: LLMError.network("denied"))
        let draft = KnowledgeRepairTaskDraft(
            title: "修复单位换算",
            subject: "Physics",
            notes: "检查量纲",
            dueDate: now,
            reminderDate: now,
            importance: 4
        )

        let outcome = await KnowledgeRepairTaskSaver.save(
            draft: draft,
            syncToReminders: true,
            container: container,
            reminderProvider: provider
        )

        XCTAssertEqual(mocks.task.addCalledCount, 1)
        XCTAssertEqual(mocks.task.taskItems.first?.title, "修复单位换算")
        XCTAssertEqual(outcome?.reminderWasSynced, false)
        XCTAssertNotNil(outcome?.reminderErrorMessage)
    }

    @MainActor
    func testRepairTaskSaverStoresReminderIdentifiersOnSuccess() async {
        let (container, mocks) = TestRepositoryContainerFactory.makeMockContainer()
        let provider = StubKnowledgeRepairReminderProvider(result: ("reminder-id", "calendar-id"))
        let draft = KnowledgeRepairTaskDraft(
            title: "修复方程建模",
            subject: "Math",
            notes: "重新列式",
            dueDate: now,
            reminderDate: now,
            importance: 3
        )

        let outcome = await KnowledgeRepairTaskSaver.save(
            draft: draft,
            syncToReminders: true,
            container: container,
            reminderProvider: provider
        )

        XCTAssertEqual(mocks.task.addCalledCount, 1)
        XCTAssertEqual(mocks.task.taskItems.first?.reminderEventId, "reminder-id")
        XCTAssertEqual(mocks.task.taskItems.first?.reminderCalendarId, "calendar-id")
        XCTAssertEqual(outcome?.reminderWasSynced, true)
        XCTAssertNil(outcome?.reminderErrorMessage)
    }

    private var configuredLLMConfig: LLMConfig {
        LLMConfig(
            enabled: true,
            baseURL: "https://example.com",
            apiKey: "test-key",
            model: "test-model",
            multimodalEnabled: false,
            thinkingEnabled: false,
            systemPromptAppendix: nil,
            temperature: 0.2,
            overrideSystemPrompt: nil
        )
    }

    @MainActor
    private func makeTestRequestGate() -> KnowledgeFaultLineRequestGate {
        let suiteName = "KnowledgeFaultLineTests.\(UUID().uuidString)"
        return KnowledgeFaultLineRequestGate(
            defaults: UserDefaults(suiteName: suiteName)!,
            baselineKey: "baseline"
        )
    }

    private func makeFaultLine() -> KnowledgeFaultLine {
        KnowledgeFaultLine(
            id: "unit_conversion|unit|quantity",
            category: .unitConversion,
            prerequisiteConcept: "单位制与量纲",
            foundationConcept: "数量与单位意识",
            impactMistakeCount: 2,
            subjects: ["Physics"],
            recentRecurrenceCount: 2,
            riskScore: 0.7,
            relatedMistakeIDs: [],
            relatedMistakes: []
        )
    }
}

@MainActor
private final class StubKnowledgeFaultAIProvider: KnowledgeFaultLineAIProviding {
    let result: [KnowledgeFaultAIExtraction]
    let error: Error?
    private(set) var callCount = 0

    init(result: [KnowledgeFaultAIExtraction] = [], error: Error? = nil) {
        self.result = result
        self.error = error
    }

    func extract(from mistakes: [MistakeNote], config: LLMConfig) async throws -> [KnowledgeFaultAIExtraction] {
        callCount += 1
        if let error { throw error }
        return result
    }
}

@MainActor
private final class StubKnowledgeRepairReminderProvider: KnowledgeRepairReminderProviding {
    let result: (calendarItemId: String, calendarId: String)?
    let error: Error?

    init(
        result: (calendarItemId: String, calendarId: String)? = nil,
        error: Error? = nil
    ) {
        self.result = result
        self.error = error
    }

    func addTaskToReminders(
        title: String,
        dueDate: Date,
        alarmDate: Date,
        notes: String,
        subject: String?
    ) async throws -> (calendarItemId: String, calendarId: String) {
        if let error { throw error }
        return result ?? ("", "")
    }
}
