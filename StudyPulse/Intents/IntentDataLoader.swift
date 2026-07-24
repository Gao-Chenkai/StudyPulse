import Foundation

/// 非隔离的数据访问助手,供后台 App Intents 使用。
/// Nonisolated data access helper for background App Intents.
/// 通过 `DataFileIO` 直接读取 ~/Documents/ 下的 JSON 文件,避免对 `@MainActor` DataManager 的依赖。
/// Reads JSON files from ~/Documents/ via DataFileIO, avoiding the @MainActor DataManager singleton.
nonisolated enum IntentDataLoader {

    /// 获取 Documents 目录 / Get the app's Documents directory.
    static func getDocsDir() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    // MARK: - Subjects / 学科

    /// 加载学科列表 / Load the subject list.
    static func loadSubjects() -> [Subject] {
        guard let docs = getDocsDir() else { return [] }
        let url = docs.appendingPathComponent("subjects.json")
        return DataFileIO.load(url: url) ?? []
    }

    // MARK: - Exams / 考试

    /// 加载普通考试列表(日期 ISO 8601) / Load the regular exam list (ISO 8601 dates).
    static func loadExams() -> [Exam] {
        guard let docs = getDocsDir() else { return [] }
        let url = docs.appendingPathComponent("exams.json")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return DataFileIO.load(url: url, decoder: decoder) ?? []
    }

    /// 加载综合考试列表(日期 ISO 8601) / Load the comprehensive exam list (ISO 8601 dates).
    static func loadComprehensiveExams() -> [comprehensiveExam] {
        guard let docs = getDocsDir() else { return [] }
        let url = docs.appendingPathComponent("comprehensiveExams.json")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return DataFileIO.load(url: url, decoder: decoder) ?? []
    }

    // MARK: - Grades / 成绩

    /// 加载成绩列表 / Load the grade list.
    static func loadGrades() -> [Grade] {
        guard let docs = getDocsDir() else { return [] }
        let url = docs.appendingPathComponent("grades.json")
        return DataFileIO.load(url: url) ?? []
    }

    // MARK: - Health Cache / 健康缓存

    /// 加载 HealthKit 派生的就绪度 / 身体状态缓存 / Load the HealthKit-derived readiness / body-status cache.
    static func loadHealthCache() -> IntentHealthCache? {
        IntentHealthCacheStore.load()
    }
}

// MARK: - Health Cache Model / 健康缓存模型

/// 由 HealthKitManager 在每次刷新后写入的轻量快照,
/// 后台 App Intents 据此返回就绪度 / 身体状态话术。
/// Lightweight snapshot written by HealthKitManager; used by background
/// App Intents for readiness / body-status dialogs.
nonisolated struct IntentHealthCache: Codable {
    var readinessCategory: String?  // 就绪度分类标签(LLM 产出) / Readiness category label.
    var readinessSuggestion: String?  // 就绪度建议文案 / Readiness suggestion text.
    var sleepHours: Double?  // 昨晚睡眠时长(小时) / Last night's sleep duration (hours).
    var sleepQuality: String?  // 睡眠质量描述 / Sleep quality description.
    var restingHeartRate: Double?  // 静息心率(bpm) / Resting heart rate (bpm).
    var exerciseMinutes: Double?  // 今日运动时长(分钟) / Today's exercise minutes.
    var lastUpdated: Date  // 缓存写入时间 / Cache last-written timestamp.
}
