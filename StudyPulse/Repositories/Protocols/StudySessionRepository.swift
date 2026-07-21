import Foundation
import SwiftData

@MainActor
protocol StudySessionRepository: AnyObject, Sendable {
    var sessions: [StudySession] { get }
    func loadAll(context: ModelContext) async
    func upsert(_ session: StudySession)
    func refreshFromLegacyJSON()
}
