import Foundation
import BackgroundTasks

enum CoachBackgroundRefresh {
    static let identifier = "Gao.Chenkai.StudyPulse.coach.refresh"
    @MainActor private static var currentContainer: RepositoryContainer?

    @MainActor
    static func register(container: RepositoryContainer) {
        currentContainer = container
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            task.expirationHandler = { task.setTaskCompleted(success: false) }
            Task { @MainActor in
                guard let container = currentContainer else { task.setTaskCompleted(success: false); return }
                guard container.isReady else { task.setTaskCompleted(success: false); return }
                await HealthKitManager.shared.refreshBodyStatus()
                await HealthKitManager.shared.refreshReadiness()
                let coordinator = CoachCoordinator(container: container)
                coordinator.evaluateCoachTasks()
                let activeGoal = container.coachRepo.goals.first(where: { $0.status == .active })
                if let goal = activeGoal {
                    _ = coordinator.analyze(goal: goal)
                }
                CoachNotifications.shared.reschedule(
                    enabled: container.envManager.preferences.coachEnabled && container.envManager.preferences.coachNotificationEnabled,
                    hour: container.envManager.preferences.coachNotificationHour,
                    goalID: activeGoal?.id
                )
                task.setTaskCompleted(success: true)
                schedule()
            }
        }
    }

    @MainActor
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Calendar.current.date(byAdding: .hour, value: 24, to: Date())
        try? BGTaskScheduler.shared.submit(request)
    }
}
