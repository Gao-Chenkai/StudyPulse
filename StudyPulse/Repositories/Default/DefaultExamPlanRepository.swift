import Foundation
import SwiftData

@Observable @MainActor
final class DefaultExamPlanRepository: ExamPlanRepository {
    private(set) var goals: [ExamGoal] = []
    private(set) var plans: [ExamPlan] = []
    private var context: ModelContext?

    func loadAll(context: ModelContext) async {
        self.context = context
        let goalDescriptor = FetchDescriptor<ExamGoalRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let planDescriptor = FetchDescriptor<ExamPlanRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        goals = (try? context.fetch(goalDescriptor))?.compactMap { $0.toSnapshot() } ?? []
        plans = (try? context.fetch(planDescriptor))?.compactMap { $0.toSnapshot() } ?? []
    }

    func upsertGoal(_ goal: ExamGoal) {
        guard let context else { return }
        if let record = (try? context.fetch(FetchDescriptor<ExamGoalRecord>()))?
            .first(where: { $0.id == goal.id }) {
            record.createdAt = goal.createdAt
            record.payload = (try? JSONEncoder().encode(goal)) ?? Data()
        } else {
            context.insert(ExamGoalRecord(from: goal))
        }
        try? context.save()

        if let index = goals.firstIndex(where: { $0.id == goal.id }) {
            goals[index] = goal
        } else {
            goals.append(goal)
        }
        goals.sort { $0.createdAt > $1.createdAt }
    }

    func deleteGoal(_ goal: ExamGoal) {
        plans.removeAll { $0.examGoalID == goal.id }
        goals.removeAll { $0.id == goal.id }
        guard let context else { return }

        let goalRecords = (try? context.fetch(FetchDescriptor<ExamGoalRecord>())) ?? []
        for record in goalRecords where record.id == goal.id {
            context.delete(record)
        }
        let planRecords = (try? context.fetch(FetchDescriptor<ExamPlanRecord>())) ?? []
        for record in planRecords where record.examGoalID == goal.id {
            context.delete(record)
        }
        try? context.save()
    }

    func upsertPlan(_ plan: ExamPlan) {
        guard let context else { return }
        if let record = (try? context.fetch(FetchDescriptor<ExamPlanRecord>()))?
            .first(where: { $0.id == plan.id }) {
            record.examGoalID = plan.examGoalID
            record.createdAt = plan.createdAt
            record.payload = (try? JSONEncoder().encode(plan)) ?? Data()
        } else {
            context.insert(ExamPlanRecord(from: plan))
        }
        try? context.save()

        if let index = plans.firstIndex(where: { $0.id == plan.id }) {
            plans[index] = plan
        } else {
            plans.append(plan)
        }
        plans.sort { $0.createdAt > $1.createdAt }
    }

    func deletePlan(_ plan: ExamPlan) {
        plans.removeAll { $0.id == plan.id }
        guard let context,
              let record = (try? context.fetch(FetchDescriptor<ExamPlanRecord>()))?
                .first(where: { $0.id == plan.id }) else { return }
        context.delete(record)
        try? context.save()
    }
}
