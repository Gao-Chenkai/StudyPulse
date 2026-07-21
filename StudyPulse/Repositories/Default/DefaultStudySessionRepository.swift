import Foundation
import SwiftData

@Observable @MainActor
final class DefaultStudySessionRepository: StudySessionRepository {
    private(set) var sessions: [StudySession] = []
    private var context: ModelContext?

    func loadAll(context: ModelContext) async {
        self.context = context
        let records = (try? context.fetch(FetchDescriptor<StudySessionRecord>(sortBy: [SortDescriptor(\.startDate, order: .reverse)]))) ?? []
        sessions = records.compactMap { $0.toSnapshot() }
        if sessions.isEmpty {
            let legacy = StudySessionStore.load()
            for session in legacy { context.insert(StudySessionRecord(from: session)) }
            try? context.save()
            sessions = legacy.sorted { $0.startDate > $1.startDate }
        }
    }

    func upsert(_ session: StudySession) {
        guard let context else { return }
        if let record = (try? context.fetch(FetchDescriptor<StudySessionRecord>()))?.first(where: { $0.id == session.id }) {
            record.startDate = session.startDate
            record.payload = (try? JSONEncoder().encode(session)) ?? Data()
        } else { context.insert(StudySessionRecord(from: session)) }
        try? context.save()
        if let i = sessions.firstIndex(where: { $0.id == session.id }) { sessions[i] = session }
        else { sessions.append(session) }
        sessions.sort { $0.startDate > $1.startDate }
    }

    func refreshFromLegacyJSON() {
        let legacy = StudySessionStore.load()
        for session in legacy { upsert(session) }
    }
}
