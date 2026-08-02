import Foundation
import SwiftData

@MainActor
protocol StudySessionRepository: AnyObject, Sendable {
    var sessions: [StudySession] { get }
    func loadAll(context: ModelContext) async
    func upsert(_ session: StudySession)
    func delete(_ id: UUID)
    func assign(_ ids: Set<UUID>, to target: InvestmentTarget?)
    func session(id: UUID) -> StudySession?
    func refreshFromLegacyJSON()
}
