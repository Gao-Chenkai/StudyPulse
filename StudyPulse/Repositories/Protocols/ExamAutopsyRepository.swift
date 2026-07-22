import Foundation
import SwiftData
@MainActor protocol ExamAutopsyRepository: AnyObject, Sendable {
    var records: [ExamAutopsy] { get }
    func loadAll(context: ModelContext) async
    func record(for examId: UUID) -> ExamAutopsy?
    func upsert(_ record: ExamAutopsy)
    func delete(_ record: ExamAutopsy)
}
