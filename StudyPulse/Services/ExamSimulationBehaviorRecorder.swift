import Foundation

/// Deterministic event recorder used by the simulator UI and unit tests.
/// Role classification is intentionally not performed here.
nonisolated struct ExamSimulationBehaviorRecorder: Sendable {
    private(set) var simulation: ExamSimulation

    init(simulation: ExamSimulation) {
        self.simulation = simulation
    }

    mutating func start(at now: Date, remainingSeconds: Int) {
        guard simulation.status == .preparing else { return }
        simulation.startedAt = now
        simulation.status = .running
        append(.started, at: now, remainingSeconds: remainingSeconds)
    }

    mutating func enterQuestion(index: Int, at now: Date, remainingSeconds: Int) {
        guard simulation.questionRecords.indices.contains(index) else { return }
        var record = simulation.questionRecords[index]
        record.firstViewedAt = record.firstViewedAt ?? now
        record.lastEnteredAt = now
        record.visitCount += 1
        simulation.questionRecords[index] = record
        append(
            .questionEntered,
            at: now,
            questionId: record.question.id,
            questionIndex: index,
            remainingSeconds: remainingSeconds
        )
    }

    mutating func commitAnswer(index: Int, answer: String, at now: Date, remainingSeconds: Int) {
        guard simulation.questionRecords.indices.contains(index) else { return }
        let normalized = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        var record = simulation.questionRecords[index]
        let previous = record.finalAnswer
        guard previous != normalized else { return }

        if record.firstAnswer == nil, !normalized.isEmpty {
            record.firstAnswer = normalized
        } else if let previous, !previous.isEmpty, previous != normalized {
            record.answerChangeCount += 1
        }
        record.finalAnswer = normalized
        simulation.questionRecords[index] = record
        append(
            .answerChanged,
            at: now,
            questionId: record.question.id,
            questionIndex: index,
            previousAnswer: previous,
            answer: normalized,
            remainingSeconds: remainingSeconds
        )
    }

    mutating func leaveQuestion(index: Int, at now: Date, remainingSeconds: Int) {
        guard simulation.questionRecords.indices.contains(index) else { return }
        var record = simulation.questionRecords[index]
        if let enteredAt = record.lastEnteredAt {
            record.totalViewSeconds += max(0, now.timeIntervalSince(enteredAt))
        }
        record.lastEnteredAt = nil
        record.lastLeftAt = now
        simulation.questionRecords[index] = record
        append(
            .questionLeft,
            at: now,
            questionId: record.question.id,
            questionIndex: index,
            remainingSeconds: remainingSeconds
        )
    }

    mutating func markSkipped(index: Int, at now: Date, remainingSeconds: Int) {
        guard simulation.questionRecords.indices.contains(index) else { return }
        var record = simulation.questionRecords[index]
        record.skipCount += 1
        simulation.questionRecords[index] = record
        append(
            .skipped,
            at: now,
            questionId: record.question.id,
            questionIndex: index,
            remainingSeconds: remainingSeconds
        )
    }

    mutating func beginSubmission(at now: Date, remainingSeconds: Int, timedOut: Bool) {
        guard simulation.status == .running else { return }
        simulation.endedAt = now
        simulation.status = .grading
        for index in simulation.questionRecords.indices {
            simulation.questionRecords[index].submittedAt = now
        }
        append(
            timedOut ? .timedOut : .submitted,
            at: now,
            remainingSeconds: remainingSeconds
        )
    }

    mutating func applyGrading(_ response: QuizGradingResponse) {
        simulation.totalScore = response.totalScore
        for result in response.results where simulation.questionRecords.indices.contains(result.index) {
            simulation.questionRecords[result.index].isCorrect = result.isCorrect
            simulation.questionRecords[result.index].score = result.score
        }
        simulation.status = .analyzing
    }

    mutating func finish(with analysis: ExamRoleAnalysis) {
        simulation.analysis = analysis
        simulation.lastError = nil
        simulation.status = .completed
    }

    mutating func fail(_ message: String) {
        simulation.lastError = message
        simulation.status = .analysisFailed
    }

    mutating func abandon(at now: Date, remainingSeconds: Int) {
        guard simulation.status == .running else { return }
        simulation.endedAt = now
        simulation.status = .abandoned
        append(.abandoned, at: now, remainingSeconds: remainingSeconds)
    }

    private mutating func append(
        _ kind: ExamSimulationEventKind,
        at timestamp: Date,
        questionId: UUID? = nil,
        questionIndex: Int? = nil,
        previousAnswer: String? = nil,
        answer: String? = nil,
        remainingSeconds: Int
    ) {
        simulation.events.append(
            ExamSimulationEvent(
                kind: kind,
                timestamp: timestamp,
                questionId: questionId,
                questionIndex: questionIndex,
                previousAnswer: previousAnswer,
                answer: answer,
                remainingSeconds: remainingSeconds
            )
        )
    }
}

