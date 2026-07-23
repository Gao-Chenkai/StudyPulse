import Foundation
import SwiftData

@MainActor
protocol ExamSimulationRepository: AnyObject, Sendable {
    var simulations: [ExamSimulation] { get }
    func loadAll(context: ModelContext) async
    func upsert(_ simulation: ExamSimulation)
    func delete(_ simulation: ExamSimulation)
}

extension ExamSimulationRepository {
    var latest: ExamSimulation? {
        simulations.max { $0.createdAt < $1.createdAt }
    }

    var analyzedSimulations: [ExamSimulation] {
        simulations
            .filter { $0.analysis != nil && $0.isValidCompletedSession }
            .sorted { $0.createdAt > $1.createdAt }
    }
}

