import Foundation
import SwiftData

enum TimeInvestmentRepositoryError: LocalizedError {
    case subjectNotFound
    case parentNotFound
    case invalidHierarchy
    case hasDependencies
    case invalidRewardTarget

    var errorDescription: String? {
        switch self {
        case .subjectNotFound: return "time.investment.error.subjectMissing".localized()
        case .parentNotFound: return "time.investment.error.parentMissing".localized()
        case .invalidHierarchy: return "time.investment.error.hierarchy".localized()
        case .hasDependencies: return "time.investment.error.dependencies".localized()
        case .invalidRewardTarget: return "time.investment.error.rewardTarget".localized()
        }
    }
}

@MainActor
protocol TimeInvestmentRepository: AnyObject, Sendable {
    var subjects: [TimeInvestmentSubject] { get }
    var subTasks: [SubTask] { get }
    var rewards: [GoalReward] { get }

    func loadAll(context: ModelContext) async
    func upsertSubject(_ subject: TimeInvestmentSubject) throws
    func upsertSubTask(_ subTask: SubTask) throws
    func upsertReward(_ reward: GoalReward) throws
    func archiveSubject(_ id: UUID, archived: Bool)
    func archiveSubTask(_ id: UUID, archived: Bool)
    func deleteSubject(_ id: UUID) throws
    func deleteSubTask(_ id: UUID) throws
    func deleteReward(_ id: UUID)
    @discardableResult
    func evaluateRewards(sessions: [StudySession], now: Date) -> [GoalReward]
}
