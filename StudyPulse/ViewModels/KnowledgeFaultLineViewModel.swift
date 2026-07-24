//
//  KnowledgeFaultLineViewModel.swift
//  StudyPulse
//

import Foundation

@MainActor
@Observable
final class KnowledgeFaultLineViewModel {
    private let container: RepositoryContainer
    private let aiProvider: any KnowledgeFaultLineAIProviding
    private let configurationOverride: LLMConfig?
    private let requestGate: KnowledgeFaultLineRequestGate
    private var inputFingerprint: String?
    private var aiTask: Task<Void, Never>?
    private var activeRequestID: UUID?

    private(set) var scan: KnowledgeFaultScan = .empty
    private(set) var isLoadingAI = false
    private(set) var aiErrorMessage: String?
    var repairFaultLine: KnowledgeFaultLine?

    init(
        container: RepositoryContainer,
        aiProvider: (any KnowledgeFaultLineAIProviding)? = nil,
        configuration: LLMConfig? = nil,
        requestGate: KnowledgeFaultLineRequestGate? = nil
    ) {
        self.container = container
        self.aiProvider = aiProvider ?? DefaultKnowledgeFaultLineAIProvider()
        self.configurationOverride = configuration
        self.requestGate = requestGate ?? KnowledgeFaultLineRequestGate()
    }

    static func makeDefault(container: RepositoryContainer) -> KnowledgeFaultLineViewModel {
        KnowledgeFaultLineViewModel(container: container)
    }

    var repeatedFaultLines: [KnowledgeFaultLine] { scan.repeatedFaultLines }

    func recompute(autoEnhance: Bool = true) {
        let mistakes = container.mistakeRepo.filteredMistakeSets
        let fingerprint = Self.fingerprint(for: mistakes)
        scan = KnowledgeFaultLineEngine.scan(mistakes: mistakes)
        guard autoEnhance else { return }
        guard fingerprint != inputFingerprint else { return }
        guard requestGate.shouldAutomaticallyRequest(for: mistakes) else { return }
        inputFingerprint = fingerprint
        beginAIEnhancement(for: mistakes, fingerprint: fingerprint, updatesRequestGate: true)
    }

    func retryAI() {
        let mistakes = container.mistakeRepo.filteredMistakeSets
        let fingerprint = Self.fingerprint(for: mistakes)
        inputFingerprint = fingerprint
        beginAIEnhancement(for: mistakes, fingerprint: fingerprint, updatesRequestGate: true)
    }

    func manuallyRequestAI() {
        let mistakes = container.mistakeRepo.filteredMistakeSets
        let fingerprint = Self.fingerprint(for: mistakes)
        inputFingerprint = fingerprint
        beginAIEnhancement(for: mistakes, fingerprint: fingerprint, updatesRequestGate: true)
    }

    func node(for mistakeID: UUID) -> MistakeKnowledgeNode? {
        scan.node(for: mistakeID)
    }

    func faultLine(for mistakeID: UUID) -> KnowledgeFaultLine? {
        if let line = scan.faultLines.first(where: { $0.relatedMistakeIDs.contains(mistakeID) }) {
            return line
        }
        guard let node = scan.node(for: mistakeID) else { return nil }
        return KnowledgeFaultLineEngine.provisionalLine(
            for: node,
            mistakes: container.mistakeRepo.filteredMistakeSets
        )
    }

    private func beginAIEnhancement(
        for mistakes: [MistakeNote],
        fingerprint: String,
        updatesRequestGate: Bool
    ) {
        aiTask?.cancel()
        aiErrorMessage = nil
        let config = configurationOverride ?? container.envManager.llmConfig
        guard !mistakes.isEmpty else {
            isLoadingAI = false
            return
        }
        guard config.isConfigured else {
            aiErrorMessage = LLMError.notConfigured.localizedDescription
            isLoadingAI = false
            return
        }

        isLoadingAI = true
        let requestID = UUID()
        activeRequestID = requestID
        aiTask = Task { [weak self] in
            guard let self else { return }
            do {
                let extractions = try await aiProvider.extract(from: mistakes, config: config)
                guard !Task.isCancelled else { return }
                guard activeRequestID == requestID else { return }
                guard Self.fingerprint(for: container.mistakeRepo.filteredMistakeSets) == fingerprint else { return }
                scan = KnowledgeFaultLineEngine.scan(mistakes: mistakes, extractions: extractions)
                if updatesRequestGate {
                    requestGate.markRequestCompleted(for: mistakes)
                }
                isLoadingAI = false
            } catch is CancellationError {
                if activeRequestID == requestID { isLoadingAI = false }
            } catch let error as LLMError {
                guard !Task.isCancelled else { return }
                guard activeRequestID == requestID else { return }
                aiErrorMessage = error.localizedDescription
                isLoadingAI = false
            } catch {
                guard !Task.isCancelled else { return }
                guard activeRequestID == requestID else { return }
                aiErrorMessage = error.localizedDescription
                isLoadingAI = false
            }
        }
    }

    private static func fingerprint(for mistakes: [MistakeNote]) -> String {
        mistakes
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map {
                [
                    $0.id.uuidString,
                    $0.date.timeIntervalSince1970.description,
                    $0.title,
                    $0.subject,
                    $0.errorReason,
                    $0.wrongSolution,
                    $0.correctSolution,
                    $0.tags.joined(separator: ","),
                    String($0.masteryScore),
                    String($0.reviewState?.lapses ?? 0),
                    String($0.masteryHistory.count)
                ].joined(separator: "|")
            }
            .joined(separator: "\n")
    }
}
