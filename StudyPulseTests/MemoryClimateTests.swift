import XCTest
@testable import StudyPulse

final class MemoryClimateTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_780_000_000)

    private func entry(daysAgo: Double, score: Double, quality: ReviewQuality) -> MasteryHistoryEntry {
        MasteryHistoryEntry(
            timestamp: now.addingTimeInterval(-daysAgo * 86_400),
            score: score,
            quality: quality.rawValue
        )
    }

    private func mistake(
        id: UUID = UUID(),
        subject: String = "Math",
        tags: [String],
        mastery: Double,
        daysOld: Double = 1,
        history: [MasteryHistoryEntry],
        repetitions: Int = 0,
        nextReviewDays: Double? = nil,
        lapses: Int = 0,
        phaseId: UUID? = nil
    ) -> MistakeNote {
        let state = nextReviewDays.map {
            ReviewState(
                repetitions: repetitions,
                nextReviewDate: now.addingTimeInterval($0 * 86_400),
                lastReviewDate: history.first?.timestamp,
                lapses: lapses
            )
        }
        return MistakeNote(
            id: id,
            title: tags.first ?? "Question",
            subject: subject,
            originalQuestion: "Q",
            source: "Test",
            date: now.addingTimeInterval(-daysOld * 86_400),
            errorReason: "",
            wrongSolution: "",
            correctSolution: "",
            reviewState: state,
            phaseId: phaseId,
            masteryScore: mastery,
            masteryHistory: history,
            tags: tags
        )
    }

    func testClassifiesClearFogFrozenAndSouthHumid() throws {
        let clear = mistake(
            tags: ["Geometry"],
            mastery: 0.86,
            history: [entry(daysAgo: 1, score: 0.86, quality: .good), entry(daysAgo: 3, score: 0.8, quality: .easy)],
            repetitions: 3,
            nextReviewDays: 5
        )
        XCTAssertEqual(
            MemoryClimateEngine.generate(mistakes: [clear], phaseId: nil, now: now).subjects.first?.weather,
            .clear
        )

        let fog = mistake(
            tags: ["Algebra"],
            mastery: 0.5,
            history: [entry(daysAgo: 1, score: 0.5, quality: .hard), entry(daysAgo: 4, score: 0.55, quality: .good)],
            repetitions: 2,
            nextReviewDays: 2
        )
        XCTAssertEqual(
            MemoryClimateEngine.generate(mistakes: [fog], phaseId: nil, now: now).subjects.first?.weather,
            .fog
        )

        let humid = mistake(
            tags: ["Calculus"],
            mastery: 0.5,
            history: [entry(daysAgo: 0.5, score: 0.5, quality: .good), entry(daysAgo: 5, score: 0.3, quality: .again)],
            repetitions: 1,
            nextReviewDays: 4,
            lapses: 1
        )
        XCTAssertEqual(
            MemoryClimateEngine.generate(mistakes: [humid], phaseId: nil, now: now).subjects.first?.weather,
            .southHumid
        )

        let frozen = mistake(
            tags: ["Trigonometry"],
            mastery: 0,
            daysOld: 30,
            history: []
        )
        XCTAssertEqual(
            MemoryClimateEngine.generate(mistakes: [frozen], phaseId: nil, now: now).subjects.first?.weather,
            .frozen
        )
    }

    func testThunderstormRequiresRelatedConceptsAndNegativeEvidenceOnBothSides() throws {
        let bridge = mistake(
            tags: ["Functions", "Sequences"],
            mastery: 0.3,
            history: [entry(daysAgo: 2, score: 0.3, quality: .again)]
        )
        let functions = mistake(
            tags: ["Functions"],
            mastery: 0.4,
            history: [entry(daysAgo: 3, score: 0.4, quality: .hard)]
        )
        let sequences = mistake(
            tags: ["Sequences"],
            mastery: 0.35,
            history: [entry(daysAgo: 4, score: 0.35, quality: .again)]
        )

        let climate = try XCTUnwrap(
            MemoryClimateEngine.generate(
                mistakes: [bridge, functions, sequences],
                phaseId: nil,
                now: now
            ).subjects.first
        )
        XCTAssertEqual(climate.weather, .thunderstorm)
        XCTAssertEqual(climate.interferences.first?.displayName, "Functions ↔ Sequences")

        let insufficient = MemoryClimateEngine.generate(
            mistakes: [bridge],
            phaseId: nil,
            now: now
        )
        XCTAssertNotEqual(insufficient.subjects.first?.weather, .thunderstorm)
    }

    func testThunderstormTakesPriorityOverRecentSuccess() {
        let a = mistake(
            tags: ["Functions", "Sequences"],
            mastery: 0.4,
            history: [
                entry(daysAgo: 0.25, score: 0.4, quality: .good),
                entry(daysAgo: 2, score: 0.3, quality: .again)
            ]
        )
        let b = mistake(
            tags: ["Functions"],
            mastery: 0.3,
            history: [entry(daysAgo: 3, score: 0.3, quality: .hard)]
        )
        let c = mistake(
            tags: ["Sequences"],
            mastery: 0.3,
            history: [entry(daysAgo: 4, score: 0.3, quality: .again)]
        )
        XCTAssertEqual(
            MemoryClimateEngine.generate(mistakes: [a, b, c], phaseId: nil, now: now).subjects.first?.weather,
            .thunderstorm
        )
    }

    func testNewUnreviewedSubjectIsOmittedAndPhaseIsRecorded() {
        let phase = UUID()
        let newNote = mistake(tags: ["New"], mastery: 0, history: [], phaseId: phase)
        let snapshot = MemoryClimateEngine.generate(mistakes: [newNote], phaseId: phase, now: now)
        XCTAssertTrue(snapshot.subjects.isEmpty)
        XCTAssertEqual(snapshot.phaseId, phase)
    }

    func testHistoryUpsertSeparatesPhasesAndPrunesToNinetyDays() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("memory-climate-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let firstPhase = UUID()
        let secondPhase = UUID()
        let climate = SubjectMemoryClimate(
            subject: "Math",
            weather: .clear,
            confidence: 0.8,
            averageMastery: 0.8,
            overdueRatio: 0,
            primaryConcepts: ["Functions"],
            interferences: [],
            evidenceMistakeIDs: []
        )

        for offset in 0..<95 {
            let date = now.addingTimeInterval(-Double(offset) * 86_400)
            let snapshot = MemoryClimateSnapshot(date: date, phaseId: firstPhase, subjects: [climate])
            MemoryClimateHistoryStore.upsert(snapshot, at: url, now: now)
        }
        MemoryClimateHistoryStore.upsert(
            MemoryClimateSnapshot(date: now, phaseId: secondPhase, subjects: [climate]),
            at: url,
            now: now
        )
        MemoryClimateHistoryStore.upsert(
            MemoryClimateSnapshot(date: now, phaseId: firstPhase, subjects: [
                SubjectMemoryClimate(
                    subject: "Math", weather: .fog, confidence: 0.7,
                    averageMastery: 0.5, overdueRatio: 0,
                    primaryConcepts: ["Functions"], interferences: [], evidenceMistakeIDs: []
                )
            ]),
            at: url,
            now: now
        )

        let loaded = MemoryClimateHistoryStore.load(from: url)
        XCTAssertEqual(loaded.filter { $0.phaseId == firstPhase }.count, 90)
        XCTAssertEqual(loaded.filter { $0.phaseId == secondPhase }.count, 1)
        XCTAssertEqual(
            loaded.first {
                $0.phaseId == firstPhase && Calendar.current.isDate($0.date, inSameDayAs: now)
            }?.subjects.first?.weather,
            .fog
        )
    }

    func testCorruptHistorySafelyReturnsEmpty() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("memory-climate-corrupt-\(UUID().uuidString).json")
        try Data("not-json".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertTrue(MemoryClimateHistoryStore.load(from: url).isEmpty)
    }

    func testInterleavingAddsBoundedNonDueContrastWithoutDuplicates() throws {
        let dueFunction = mistake(
            tags: ["Functions"],
            mastery: 0.3,
            history: [entry(daysAgo: 1, score: 0.3, quality: .again)],
            repetitions: 1,
            nextReviewDays: -1
        )
        let dueGeometry = mistake(
            tags: ["Geometry"],
            mastery: 0.5,
            history: [entry(daysAgo: 2, score: 0.5, quality: .hard)],
            repetitions: 1,
            nextReviewDays: -0.5
        )
        let earlySequence = mistake(
            tags: ["Sequences"],
            mastery: 0.4,
            history: [entry(daysAgo: 3, score: 0.4, quality: .again)],
            repetitions: 1,
            nextReviewDays: 5
        )
        let pair = ConceptInterference(
            firstConcept: "Functions",
            secondConcept: "Sequences",
            negativeRetrievalCount: 3,
            relatedMistakeIDs: [dueFunction.id, earlySequence.id],
            confidence: 0.8
        )
        let climate = MemoryClimateSnapshot(
            date: now,
            phaseId: nil,
            subjects: [
                SubjectMemoryClimate(
                    subject: "Math", weather: .thunderstorm, confidence: 0.8,
                    averageMastery: 0.4, overdueRatio: 0.5,
                    primaryConcepts: ["Functions", "Sequences"],
                    interferences: [pair],
                    evidenceMistakeIDs: [dueFunction.id, earlySequence.id]
                )
            ]
        )

        let queue = ClimateInterleavingEngine.buildQueue(
            due: [dueFunction, dueGeometry],
            allMistakes: [dueFunction, dueGeometry, earlySequence],
            climate: climate,
            now: now
        )
        XCTAssertEqual(queue.filter(\.isEarlyContrast).count, 1)
        XCTAssertEqual(Set(queue.map(\.id)).count, queue.count)
        XCTAssertEqual(queue.first(where: \.isEarlyContrast)?.id, earlySequence.id)
    }
}

@MainActor
final class MemoryClimateFlashcardViewModelTests: XCTestCase {
    private var now: Date { Date() }

    func testEarlyContrastRatingRecordsMasteryButDoesNotMoveSRSDateOrReinsert() {
        let due = makeMistake(tag: "Functions", nextDays: -1, qualities: [.again, .hard])
        let bridge = makeMistake(tags: ["Functions", "Sequences"], nextDays: -2, qualities: [.again])
        let early = makeMistake(tag: "Sequences", nextDays: 5, qualities: [.again])
        let setup = TestRepositoryContainerFactory.makeMockContainer()
        setup.mocks.mistake.mistakeSets = [due, bridge, early]
        setup.mocks.mistake.filteredMistakeSets = [due, bridge, early]
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("memory-climate-vm-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let viewModel = FlashcardStudyViewModel(
            container: setup.container,
            filter: .dueQueue,
            climateHistoryURL: url
        )
        guard let earlyIndex = viewModel.queue.firstIndex(where: \.isEarlyContrast) else {
            return XCTFail("Expected an early contrast card")
        }
        viewModel.currentIndex = earlyIndex
        let originalDate = early.reviewState?.nextReviewDate
        viewModel.handleRating(.again)

        XCTAssertEqual(setup.mocks.mistake.recordReviewCalledCount, 1)
        XCTAssertEqual(setup.mocks.mistake.updateReviewStateCalledCount, 0)
        XCTAssertEqual(
            setup.mocks.mistake.mistakeSets.first(where: { $0.id == early.id })?.reviewState?.nextReviewDate,
            originalDate
        )
        XCTAssertTrue(viewModel.reinsertQueue.isEmpty)
        XCTAssertEqual(viewModel.stats.earlyContrastReviewed, 1)
    }

    private func makeMistake(
        tag: String,
        nextDays: Double,
        qualities: [ReviewQuality]
    ) -> MistakeNote {
        makeMistake(tags: [tag], nextDays: nextDays, qualities: qualities)
    }

    private func makeMistake(
        tags: [String],
        nextDays: Double,
        qualities: [ReviewQuality]
    ) -> MistakeNote {
        let history = qualities.enumerated().map { index, quality in
            MasteryHistoryEntry(
                timestamp: now.addingTimeInterval(-Double(index + 1) * 86_400),
                score: 0.3,
                quality: quality.rawValue
            )
        }
        return MistakeNote(
            title: tags.first ?? "Question",
            subject: "Math",
            originalQuestion: "Q",
            source: "Test",
            date: now.addingTimeInterval(-10 * 86_400),
            errorReason: "",
            wrongSolution: "",
            correctSolution: "",
            reviewState: ReviewState(
                repetitions: 1,
                nextReviewDate: now.addingTimeInterval(nextDays * 86_400),
                lastReviewDate: history.first?.timestamp
            ),
            masteryScore: 0.3,
            masteryHistory: history,
            tags: tags
        )
    }
}
