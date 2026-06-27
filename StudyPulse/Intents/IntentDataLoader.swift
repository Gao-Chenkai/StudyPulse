import Foundation

/// Nonisolated data access helper for App Intents running in background.
/// Reads JSON files from ~/Documents/ directly via DataFileIO,
/// avoiding any dependency on the @MainActor DataManager singleton.
nonisolated enum IntentDataLoader {

    static func getDocsDir() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    // MARK: - Subjects

    static func loadSubjects() -> [Subject] {
        let url = getDocsDir().appendingPathComponent("subjects.json")
        return DataFileIO.load(url: url) ?? []
    }

    // MARK: - Exams

    static func loadExams() -> [Exam] {
        let url = getDocsDir().appendingPathComponent("exams.json")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return DataFileIO.load(url: url, decoder: decoder) ?? []
    }

    static func loadComprehensiveExams() -> [comprehensiveExam] {
        let url = getDocsDir().appendingPathComponent("comprehensiveExams.json")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return DataFileIO.load(url: url, decoder: decoder) ?? []
    }

    // MARK: - Grades

    static func loadGrades() -> [Grade] {
        let url = getDocsDir().appendingPathComponent("grades.json")
        return DataFileIO.load(url: url) ?? []
    }

    // MARK: - Health Cache

    static func loadHealthCache() -> IntentHealthCache? {
        let url = getDocsDir().appendingPathComponent("readiness_cache.json")
        return DataFileIO.load(url: url)
    }
}

// MARK: - Health Cache Model

/// Lightweight snapshot written by HealthKitManager after each refresh
/// so background App Intents can return readiness / body-status dialogs.
nonisolated struct IntentHealthCache: Codable {
    var readinessCategory: String?
    var readinessSuggestion: String?
    var sleepHours: Double?
    var sleepQuality: String?
    var restingHeartRate: Double?
    var exerciseMinutes: Double?
    var lastUpdated: Date
}
