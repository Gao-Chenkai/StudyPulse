import Foundation

@MainActor
final class MistakeCorrectionPlanStore {
    static let shared = MistakeCorrectionPlanStore()

    private let defaults: UserDefaults
    private let key = "mistakeCorrectionPlan.v1"
    private(set) var plan: MistakeCorrectionPlan?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key) {
            plan = try? JSONDecoder().decode(MistakeCorrectionPlan.self, from: data)
        }
    }

    func start(summary: MistakePatternSummary, now: Date = Date()) -> MistakeCorrectionPlan {
        let newPlan = MistakeCorrectionPlanEngine.makePlan(for: summary, now: now)
        plan = newPlan
        save()
        return newPlan
    }

    func toggle(mistakeID: UUID, on dayIndex: Int) {
        guard var plan, let index = plan.days.firstIndex(where: { $0.dayIndex == dayIndex }) else { return }
        if plan.days[index].completedMistakeIDs.contains(mistakeID) {
            plan.days[index].completedMistakeIDs.remove(mistakeID)
        } else {
            plan.days[index].completedMistakeIDs.insert(mistakeID)
        }
        self.plan = plan
        save()
    }

    func setReflection(_ value: Bool?, on dayIndex: Int) {
        guard var plan, let index = plan.days.firstIndex(where: { $0.dayIndex == dayIndex }) else { return }
        plan.days[index].foundIssueInReading = value
        self.plan = plan
        save()
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(plan), forKey: key)
    }
}
