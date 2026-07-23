import Foundation
import SwiftData

@Observable @MainActor
final class DefaultExamSimulationRepository: ExamSimulationRepository {
    private(set) var simulations: [ExamSimulation] = []
    private var context: ModelContext?

    func loadAll(context: ModelContext) async {
        self.context = context
        let descriptor = FetchDescriptor<ExamSimulationRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let records = (try? context.fetch(descriptor)) ?? []
        simulations = records.compactMap { $0.toSnapshot() }
    }

    func upsert(_ simulation: ExamSimulation) {
        guard let context else { return }
        if let record = (try? context.fetch(FetchDescriptor<ExamSimulationRecord>()))?
            .first(where: { $0.id == simulation.id }) {
            record.createdAt = simulation.createdAt
            record.payload = (try? JSONEncoder().encode(simulation)) ?? Data()
        } else {
            context.insert(ExamSimulationRecord(from: simulation))
        }
        try? context.save()

        if let index = simulations.firstIndex(where: { $0.id == simulation.id }) {
            simulations[index] = simulation
        } else {
            simulations.append(simulation)
        }
        simulations.sort { $0.createdAt > $1.createdAt }
    }

    func delete(_ simulation: ExamSimulation) {
        simulations.removeAll { $0.id == simulation.id }
        guard let context,
              let record = (try? context.fetch(FetchDescriptor<ExamSimulationRecord>()))?
                .first(where: { $0.id == simulation.id }) else { return }
        context.delete(record)
        try? context.save()
    }
}
