import Foundation

enum ExamReversePlannerLLM {
    static let caller = "ExamReversePlanner"

    private static let system = """
    你是一名专业学习规划专家。你的任务是根据学生当前学习状态，从目标考试成绩反推需要完成的提升路径。
    你必须优先利用真实的成绩、错题标签、SRS 复习队列和未完成待办，给出具体、可执行、不过度理想化的计划。
    improvementTarget 是目标分数减当前分数；mastery 必须是 0 到 1 之间的小数；priority 为 1 到 5，1 表示最高优先级。
    dailyTasks 的 dayOffset 从 1 开始，表示从今天起第几天；durationMinutes 使用整数分钟。

    【输出格式强制规则】
    只返回合法 JSON，不要 markdown 代码块、不要解释文字。
    JSON schema: {"summary":"...","weakPoints":[{"topic":"...","mastery":0.0,"possibleScoreGain":0.0,"priority":1}],"phases":[{"name":"...","dayRange":"1-5","goal":"..."}],"dailyTasks":[{"dayOffset":1,"subject":"...","durationMinutes":30,"taskTitle":"...","reason":"..."}]}
    """

    @MainActor
    static func generate(goal: ExamGoal, container: RepositoryContainer) async throws -> ExamPlan {
        let config = container.envManager.llmConfig
        guard config.isConfigured else { throw LLMError.notConfigured }

        let context = ContextBuilder.build(goal: goal, container: container)
        let prompt = LLMPrompt(system: system, messages: [.user(context)])
        let raw = try await LLMClient.shared.complete(
            prompt: prompt,
            config: config,
            caller: caller
        )
        return try parse(raw, goal: goal, modelInfo: config.model)
    }

    nonisolated static func parse(_ raw: String, goal: ExamGoal, modelInfo: String?) throws -> ExamPlan {
        guard let start = raw.firstIndex(of: "{"), let end = raw.lastIndex(of: "}") else {
            throw LLMError.malformedResponse
        }
        let json = String(raw[start...end])
        guard let data = json.data(using: .utf8) else { throw LLMError.malformedResponse }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let rawPlan = try? decoder.decode(RawPlan.self, from: data) else {
            throw LLMError.malformedResponse
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weakPoints = (rawPlan.weakPoints ?? []).prefix(8).map { $0.snapshot() }
        let phases = (rawPlan.phases ?? []).prefix(8).map { $0.snapshot() }
        let tasks = (rawPlan.dailyTasks ?? []).prefix(60).map { task in
            let offset = max(1, task.dayOffset ?? 1)
            let proposed = calendar.date(byAdding: .day, value: offset - 1, to: today) ?? today
            let date = min(proposed, calendar.startOfDay(for: goal.examDate))
            return task.snapshot(date: date, subject: goal.subject)
        }

        return ExamPlan(
            examGoalID: goal.id,
            improvementTarget: rawPlan.improvementTarget ?? max(0, goal.targetScore - goal.currentScore),
            summary: rawPlan.summary ?? "",
            weakPoints: weakPoints,
            phases: phases,
            dailyTasks: tasks,
            modelInfo: modelInfo,
            createdAt: Date()
        )
    }

    private enum ContextBuilder {
        private struct GradeContext: Codable {
            let date: Date
            let score: Double
            let fullScore: Double
            let examName: String
        }

        private struct MistakeContext: Codable {
            let title: String
            let tags: [String]
            let mastery: Double
            let reviewDate: Date?
        }

        private struct TaskContext: Codable {
            let title: String
            let dueDate: Date
            let importance: Int
        }

        private struct Payload: Codable {
            let goal: ExamGoal
            let recentGrades: [GradeContext]
            let recentAverage: Double
            let trend: String
            let topWeakTags: [String]
            let mistakes: [MistakeContext]
            let srsOverdueCount: Int
            let srsTotalCount: Int
            let unfinishedTodoCount: Int
            let unfinishedTodos: [TaskContext]
        }

        @MainActor
        static func build(goal: ExamGoal, container: RepositoryContainer) -> String {
            let grades = container.gradeRepo.grades
                .filter { $0.subject == goal.subject }
                .sorted { $0.date > $1.date }
            let recentGrades = Array(grades.prefix(15)).map {
                GradeContext(
                    date: $0.date,
                    score: $0.score,
                    fullScore: $0.fullScore ?? goal.fullScore,
                    examName: $0.examName
                )
            }

            let rates = recentGrades.map { $0.fullScore > 0 ? $0.score / $0.fullScore : 0 }
            let recentAverage = rates.isEmpty ? goal.currentScore / max(1, goal.fullScore) : rates.reduce(0, +) / Double(rates.count)
            let trend: String
            if rates.count < 2 {
                trend = "数据不足，无法判断趋势"
            } else {
                let recent = rates.prefix(max(1, rates.count / 2)).reduce(0, +) / Double(max(1, rates.count / 2))
                let older = rates.suffix(max(1, rates.count / 2)).reduce(0, +) / Double(max(1, rates.count / 2))
                trend = recent > older + 0.02 ? "上升" : recent < older - 0.02 ? "下降" : "平稳"
            }

            let mistakes = container.mistakeRepo.mistakeSets
                .filter { $0.subject == goal.subject }
                .sorted { $0.date > $1.date }
            var tagCounts: [String: Int] = [:]
            for mistake in mistakes.prefix(30) {
                for tag in mistake.tags where !tag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    tagCounts[tag, default: 0] += 1
                }
            }
            let topWeakTags = tagCounts
                .sorted { lhs, rhs in lhs.value == rhs.value ? lhs.key < rhs.key : lhs.value > rhs.value }
                .prefix(5)
                .map(\.key)

            let mistakeContext = mistakes.prefix(30).map {
                MistakeContext(
                    title: $0.title,
                    tags: $0.tags,
                    mastery: $0.masteryScore,
                    reviewDate: $0.reviewState?.nextReviewDate
                )
            }
            let enrolled = mistakes.filter { $0.reviewState != nil }
            let overdue = enrolled.filter { $0.reviewState?.nextReviewDate ?? .distantFuture < Date() }.count

            let todos = container.taskRepo.taskItems
                .filter { !$0.isCompleted && ($0.subject.isEmpty || $0.subject == goal.subject) }
                .sorted { $0.dueDate < $1.dueDate }
            let todoContext = todos.prefix(20).map {
                TaskContext(title: $0.title, dueDate: $0.dueDate, importance: $0.importance)
            }

            let payload = Payload(
                goal: goal,
                recentGrades: recentGrades,
                recentAverage: recentAverage,
                trend: trend,
                topWeakTags: topWeakTags,
                mistakes: mistakeContext,
                srsOverdueCount: overdue,
                srsTotalCount: enrolled.count,
                unfinishedTodoCount: todos.count,
                unfinishedTodos: todoContext
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = (try? encoder.encode(payload)) ?? Data()
            return "请根据以下 JSON 学习资料生成倒推计划：\n" + (String(data: data, encoding: .utf8) ?? "{}")
        }
    }

    private nonisolated struct RawPlan: Codable {
        var improvementTarget: Double?
        var summary: String?
        var weakPoints: [RawWeakPoint]?
        var phases: [RawPhase]?
        var dailyTasks: [RawDailyTask]?
    }

    private nonisolated struct RawWeakPoint: Codable {
        var id: UUID?
        var topic: String?
        var mastery: Double?
        var possibleScoreGain: Double?
        var priority: Int?

        nonisolated func snapshot() -> WeakPoint {
            WeakPoint(
                id: id ?? UUID(),
                topic: topic ?? "",
                mastery: mastery ?? 0,
                possibleScoreGain: possibleScoreGain ?? 0,
                priority: priority ?? 1
            )
        }
    }

    private nonisolated struct RawPhase: Codable {
        var id: UUID?
        var name: String?
        var dayRange: String?
        var goal: String?

        nonisolated func snapshot() -> PlanPhase {
            PlanPhase(id: id ?? UUID(), name: name ?? "", dayRange: dayRange ?? "", goal: goal ?? "")
        }
    }

    private nonisolated struct RawDailyTask: Codable {
        var id: UUID?
        var dayOffset: Int?
        var subject: String?
        var durationMinutes: Int?
        var taskTitle: String?
        var reason: String?

        nonisolated func snapshot(date: Date, subject fallbackSubject: String) -> DailyExamTask {
            DailyExamTask(
                id: id ?? UUID(),
                dayOffset: max(1, dayOffset ?? 1),
                date: date,
                subject: subject ?? fallbackSubject,
                durationMinutes: durationMinutes ?? 30,
                taskTitle: taskTitle ?? "",
                reason: reason ?? ""
            )
        }
    }
}
