//
//  RepositoryContainer.swift
//  StudyPulse
//
//  聚合 7 个 Repository + 跨域编排(批量清空 / Todo 聚合 / 阶段过滤刷新)。
//  Aggregates 7 domain Repositories + cross-domain orchestration
//  (bulk clear / todo aggregation / phase filter refresh).
//
//  注入方式:`@Environment(RepositoryContainer.self) var container`
//

import Foundation
import SwiftData
import os

/// Repository 容器:7 域 + 跨域 + ModelContainer 持有 + ready 状态。
@Observable @MainActor
final class RepositoryContainer {
    // 7 个 Repository(由外部注入,默认是 Default 实现)
    let gradeRepo: any GradeRepository
    let mistakeRepo: any MistakeRepository
    let examRepo: any ExamRepository
    let taskRepo: any TaskRepository
    let phaseRepo: any PhaseRepository
    let profileRepo: any ProfileRepository
    let subjectRepo: any SubjectRepository

    /// SwiftData ModelContainer(由 StudyPulseApp 在 .modelContainer modifier 之后注入)
    @ObservationIgnored
    private(set) var modelContainer: ModelContainer?

    /// 是否完成 asyncInit 全部加载。View 用这个 gating loader。
    private(set) var isReady: Bool = false

    /// 跨域桥接(给 Intents 跨进程用):镜像 IntentActionStore.shared.pendingIntentAction。
    /// View 直接观察 IntentActionStore(ContentView 已用 @ObservedObject 桥)。
    var pendingIntentAction: IntentAction? {
        get { IntentActionStore.shared.pendingIntentAction }
        set { IntentActionStore.shared.pendingIntentAction = newValue }
    }

    init(
        gradeRepo: any GradeRepository = DefaultGradeRepository(),
        mistakeRepo: any MistakeRepository = DefaultMistakeRepository(),
        examRepo: any ExamRepository = DefaultExamRepository(),
        taskRepo: any TaskRepository = DefaultTaskRepository(),
        phaseRepo: any PhaseRepository = DefaultPhaseRepository(),
        profileRepo: any ProfileRepository = DefaultProfileRepository(),
        subjectRepo: any SubjectRepository = DefaultSubjectRepository()
    ) {
        self.gradeRepo = gradeRepo
        self.mistakeRepo = mistakeRepo
        self.examRepo = examRepo
        self.taskRepo = taskRepo
        self.phaseRepo = phaseRepo
        self.profileRepo = profileRepo
        self.subjectRepo = subjectRepo

        // 注入跨域 weak 引用
        if let phaseImpl = phaseRepo as? DefaultPhaseRepository {
            phaseImpl.setCrossRefs(
                grade: gradeRepo,
                mistake: mistakeRepo,
                exam: examRepo,
                task: taskRepo
            )
        }
        if let profileImpl = profileRepo as? DefaultProfileRepository,
           let subjectImpl = subjectRepo as? DefaultSubjectRepository {
            profileImpl.setSubjectRef(subjectRepo)
            subjectImpl.setProfileRef(profileRepo)
        }
    }

    // MARK: - ModelContainer wiring

    /// 顶层初始化:JSON 迁移 + 7 个 repo 并行 loadAll + 内嵌图片迁移 + 通知 / widget 调度。
    ///
    /// 容器来自 `ModelContainerFactory.makeContainer()`(同进程单例缓存),
    /// 与 Scene 的 `.modelContainer(...)` modifier 共享同一 ModelContainer。
    func asyncInit() async {
        let container = ModelContainerFactory.makeContainer()
        self.modelContainer = container
        let context = container.mainContext

        // 一次性 SwiftData migration from JSON(老用户数据回填)
        ModelContainerFactory.migrateFromJSONIfNeeded(context: context)

        // 7 个 repo 串行 loadAll(均为 @MainActor,ModelContext 跨 async let 边界
        // 会被 Sendable 规则拒绝;走 TaskGroup 也同理,所以最稳妥是直接 await。
        // 性能上每个 repo 内部已用 Task.detached 做 toSnapshot,主线程只做赋值,
        // 7 个 repo 串行 await 总时长仍在 < 50ms 量级,用户感知不到。)
        await gradeRepo.loadAll(context: context)
        await mistakeRepo.loadAll(context: context)
        await examRepo.loadAll(context: context)
        await taskRepo.loadAll(context: context)
        await phaseRepo.loadAll(context: context)
        await profileRepo.loadAll(context: context)
        await subjectRepo.loadAll(context: context)

        // 内嵌图片迁移
        let migrated = gradeRepo.migrateInlineImagesIfNeeded()
        if migrated > 0 {
            await gradeRepo.reloadFromSwiftData()
        }

        // SubjectRepo 默认科目(空库时)
        if subjectRepo.subjects.isEmpty {
            subjectRepo.initializeDefaultSubjects()
        }

        // PlantManager 首次播种 + 注入上下文 + 订阅 AchievementManager
        ModelContainerFactory.migratePlantStateIfNeeded(context: context)
        PlantManager.shared.attach(container: self)

        // 观察 active phase 变化:每次变化触发 5 个 filtered 缓存重算
        observeActivePhaseChanges()

        isReady = true

        // 调度通知 / widget
        SRSReviewNotifications.shared.rescheduleAll(mistakes: mistakeRepo.mistakeSets)
        ExamReviewNotifications.shared.rescheduleAll(exams: examRepo.examSets)
        WidgetDataSyncManager.syncUpcomingExams(
            examSets: examRepo.examSets,
            comprehensiveExamSets: examRepo.comprehensiveExamSets
        )
        TrendWidgetSyncManager.syncTrend(grades: gradeRepo.grades, subjects: subjectRepo.subjects)

        Log.data.info("RepositoryContainer asyncInit done: g=\(self.gradeRepo.grades.count, privacy: .public) m=\(self.mistakeRepo.mistakeSets.count, privacy: .public) e=\(self.examRepo.examSets.count, privacy: .public) t=\(self.taskRepo.taskItems.count, privacy: .public)")
    }

    /// 订阅 AppEnvironmentManager 的 activePhaseId 变化。
    /// 用 polling(每 0.5s 检查)而非 Combine 桥接,避免引入 Combine 依赖。
    private func observeActivePhaseChanges() {
        Task { @MainActor [weak self] in
            var lastId: UUID? = AppEnvironmentManager.shared.activePhaseId
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                let currentId = AppEnvironmentManager.shared.activePhaseId
                if currentId != lastId {
                    lastId = currentId
                    self?.recomputeAllFiltered()
                }
            }
        }
    }

    /// 5 个数据域的 filtered 缓存重算(phase 切换时用)。
    func recomputeAllFiltered() {
        if let g = gradeRepo as? DefaultGradeRepository { g.recomputeFiltered() }
        if let m = mistakeRepo as? DefaultMistakeRepository { m.recomputeFiltered() }
        if let e = examRepo as? DefaultExamRepository { e.recomputeFiltered() }
        if let t = taskRepo as? DefaultTaskRepository { t.recomputeFiltered() }
        Log.data.debug("RepositoryContainer recomputeAllFiltered")
    }

    // MARK: - 跨域操作

    /// 合并考试 + 待办为统一 TodoEntry(供 TodoView 用)。
    /// - Parameters:
    ///   - includeCompleted:是否包含已完成条目
    ///   - phaseId:外部显式指定过滤 phase;nil=按 active phase 自动判定
    func todoEntries(includeCompleted: Bool = false, phaseId: UUID? = nil) -> [TodoEntry] {
        let active = phaseId ?? AppEnvironmentManager.shared.activePhaseId
        var entries: [TodoEntry] = []
        // 单科考试
        for e in examRepo.examSets {
            if active != nil && e.phaseId != active { continue }
            if !includeCompleted && e.examReview != nil { continue }
            entries.append(TodoEntry(
                id: e.id,
                kind: .exam,
                title: e.name,
                subject: e.subject,
                date: e.examDate,
                endDate: e.examEndDate,
                importance: e.importance,
                isCompleted: e.examReview != nil,
                exam: e,
                comprehensiveExam: nil,
                taskItem: nil
            ))
        }
        // 综合考试
        for c in examRepo.comprehensiveExamSets {
            if active != nil && c.phaseId != active { continue }
            entries.append(TodoEntry(
                id: c.id,
                kind: .comprehensiveExam,
                title: c.name,
                subject: "综合",
                date: c.examDate,
                endDate: nil,
                importance: c.importance,
                isCompleted: false,
                exam: nil,
                comprehensiveExam: c,
                taskItem: nil
            ))
        }
        // 待办
        for t in taskRepo.taskItems {
            if active != nil && t.phaseId != active { continue }
            if !includeCompleted && t.isCompleted { continue }
            let kind: TodoEntryKind = t.type == .reading ? .reading : .homework
            entries.append(TodoEntry(
                id: t.id,
                kind: kind,
                title: t.title,
                subject: t.subject,
                date: t.dueDate,
                endDate: nil,
                importance: t.importance,
                isCompleted: t.isCompleted,
                exam: nil,
                comprehensiveExam: nil,
                taskItem: t
            ))
        }
        return entries.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date < rhs.date }
            return lhs.importance > rhs.importance
        }
    }

    /// 批量清空数据(category → 删除条数)。
    @discardableResult
    func bulkClearData(categories: Set<BulkClearCategory>) -> [(category: BulkClearCategory, count: Int)] {
        var results: [(BulkClearCategory, Int)] = []
        for cat in categories {
            let count: Int
            switch cat {
            case .grades:       count = gradeRepo.clearAll()
            case .mistakes:     count = mistakeRepo.clearAll()
            case .exams:        count = examRepo.clearAll()
            case .tasks:        count = taskRepo.clearAll()
            case .profileReset:
                // 重置 profile 到默认 + 删头像
                if let filename = profileRepo.profile.avatarFileName {
                    profileRepo.deleteAvatar(filename: filename)
                }
                profileRepo.profile = UserProfile()
                profileRepo.saveProfile()
                count = 1
            }
            results.append((cat, count))
        }
        Log.data.info("RepositoryContainer bulkClear: \(results.map { "\($0.0)=\($0.1)" }.joined(separator: ","), privacy: .public)")
        return results
    }

    // MARK: - Passthroughs(原 DataManager 调用习惯的兼容)

    /// Subject fullScore(原来 DataManager.fullScore)
    func fullScore(for subjectName: String) -> Double {
        subjectRepo.fullScore(for: subjectName)
    }

    /// Subject displayName(原来 DataManager.displayName)
    func displayName(for subjectName: String) -> String {
        subjectRepo.displayName(for: subjectName)
    }

    /// 用户头像异步加载(原来 DataManager.loadAvatarAsync)
    func loadAvatarAsync() async -> Data? {
        await profileRepo.loadAvatarAsync()
    }

    /// 错题 exposure +1(原来 DataManager.recordMistakeExposure)
    func recordMistakeExposure(_ mistakeId: UUID) {
        mistakeRepo.recordExposure(mistakeId)
    }

    /// 切换任务完成态(原来 DataManager.setTaskCompletion)
    func setTaskCompletion(_ taskId: UUID, isCompleted: Bool) {
        taskRepo.setCompletion(taskId, isCompleted: isCompleted)
    }

    /// 刷新系统 Reminders 完成态(原来 DataManager.refreshTaskCompletionStatesFromReminders)
    func refreshTaskCompletionStatesFromReminders() {
        taskRepo.refreshCompletionStatesFromReminders()
    }

    /// 切换考试 checklist 状态(原来 DataManager.toggleExamChecklistItem)
    func toggleExamChecklistItem(_ examId: UUID, itemId: UUID) {
        examRepo.toggleChecklistItem(examId, itemId: itemId)
    }

    /// 启用智能科目推荐(原来 DataManager.applySmartSubjectRecommendation)
    func applySmartSubjectRecommendation(stage: EducationStage, regionCode: String) {
        subjectRepo.applySmartSubjectRecommendation(stage: stage, regionCode: regionCode)
    }

    /// 初始化默认科目(原来 DataManager.initializeDefaultSubjects)
    func initializeDefaultSubjects() {
        subjectRepo.initializeDefaultSubjects()
    }

    /// 保存头像并更新 profile(原来 DataManager.saveAvatar)
    @discardableResult
    func saveAvatar(_ data: Data) -> String? {
        profileRepo.saveAvatar(data)
    }

    /// 删除头像文件(原来 DataManager.deleteAvatar)
    func deleteAvatar(filename: String) {
        profileRepo.deleteAvatar(filename: filename)
    }

    /// 提交 onboarding 资料(原来 DataManager.commitOnboardingProfile)
    func commitOnboardingProfile(draft: OnboardingProfileDraft, selectedSubjectNames: [String]) {
        profileRepo.commitOnboardingProfile(draft: draft, selectedSubjectNames: selectedSubjectNames)
    }

    // MARK: - 高层 facade(常用 view 调用习惯)

    /// 添加单条 grade(带 widget sync / Achievement 副作用)
    func addGrade(_ grade: Grade) {
        gradeRepo.add(grade)
        AchievementManager.shared.recordGradeRecorded()
        // Plant subscriber: 主页植物钩子（不影响 derive 逻辑，仅记录活动 + 订阅 1.5s 内 recompute）
        PlantManager.shared.recordActivity(trigger: .grade)
        TrendWidgetSyncManager.syncTrend(grades: gradeRepo.grades, subjects: subjectRepo.subjects)
    }

    /// 批量添加 grade(带 widget sync / Achievement 副作用)
    func addGrades(_ newGrades: [Grade]) {
        let count = newGrades.count
        gradeRepo.add(newGrades)
        AchievementManager.shared.recordGradeRecorded(count: count)
        PlantManager.shared.recordActivity(trigger: .grade)
        TrendWidgetSyncManager.syncTrend(grades: gradeRepo.grades, subjects: subjectRepo.subjects)
    }

    /// 删除 grade(带 widget sync)
    func deleteGrade(_ grade: Grade) {
        gradeRepo.delete(grade)
        TrendWidgetSyncManager.syncTrend(grades: gradeRepo.grades, subjects: subjectRepo.subjects)
    }

    /// 添加错题(带 SRS 调度)
    func addMistake(_ mistake: MistakeNote) {
        mistakeRepo.add(mistake)
        SRSReviewNotifications.shared.rescheduleAll(mistakes: mistakeRepo.mistakeSets)
    }

    /// 批量添加错题
    func addMistakes(_ mistakes: [MistakeNote]) {
        mistakeRepo.add(mistakes)
        SRSReviewNotifications.shared.rescheduleAll(mistakes: mistakeRepo.mistakeSets)
    }

    /// 删除错题(带 SRS 取消)
    func deleteMistake(_ mistake: MistakeNote) {
        mistakeRepo.delete(mistake)
        SRSReviewNotifications.shared.rescheduleAll(mistakes: mistakeRepo.mistakeSets)
    }

    /// 添加考试(带 Review 通知调度)
    func addExams(single: [Exam], comprehensive: [comprehensiveExam]) {
        examRepo.add(single: single, comprehensive: comprehensive)
        ExamReviewNotifications.shared.rescheduleAll(exams: examRepo.examSets)
    }

    /// 删除单科考试
    func deleteExam(_ exam: Exam) {
        ExamReviewNotifications.shared.cancel(for: exam.id)
        examRepo.deleteExam(exam)
    }

    /// 删除综合考试
    func deleteComprehensiveExam(_ exam: comprehensiveExam) {
        examRepo.deleteComprehensiveExam(exam)
    }

    /// 添加待办
    func addTask(_ task: TaskItem, syncToReminders: Bool = false, reminderResult: (calendarItemId: String, calendarId: String)? = nil) {
        taskRepo.add(task, syncToReminders: syncToReminders, reminderResult: reminderResult)
    }

    /// 批量添加待办
    func addTasks(_ newTasks: [TaskItem]) {
        taskRepo.add(newTasks)
    }

    /// 删除待办(带 Reminder 清理)
    func deleteTask(_ task: TaskItem) {
        taskRepo.delete(task)
    }

    /// 激活 phase(更新 AppEnvironmentManager + 触发 filtered 重算)
    func activatePhase(_ phase: StudyPhase?) {
        phaseRepo.activate(phase)
        recomputeAllFiltered()
    }
}

// MARK: - BulkClearCategory

enum BulkClearCategory: String, CaseIterable, Identifiable, Hashable {
    case grades
    case mistakes
    case exams
    case tasks
    case profileReset

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .grades:       return "成绩"
        case .mistakes:     return "错题"
        case .exams:        return "考试"
        case .tasks:        return "待办"
        case .profileReset: return "重置个人资料"
        }
    }

    var systemImage: String {
        switch self {
        case .grades:       return "chart.bar.fill"
        case .mistakes:     return "book.fill"
        case .exams:        return "calendar"
        case .tasks:        return "checklist"
        case .profileReset: return "person.crop.circle.badge.exclamationmark"
        }
    }
}

// MARK: - TodoEntry(原 DataModels 中已有定义,这里仅做最小映射)

