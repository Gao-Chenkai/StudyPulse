//
//  HealthKitManager.swift
//  StudyPulse
//
//  HRV-based study readiness using HealthKit + personal baseline (Z-score)
//
import Foundation
import HealthKit
import Combine

// MARK: - HRV Readiness Result
/// The outcome of HRV-based readiness assessment
struct HRVReadiness {
    let zScore: Double?

    let todayHRV: Double?
    let baselineMean: Double?
    let baselineSampleCount: Int
    let category: Category
    let suggestion: String

    enum Category: String {
        case excellent = "excellent"
        case normal = "normal"
        case low = "low"
        case insufficient = "insufficient"
        case noAuthorization = "noAuthorization"
        case queryFailed = "queryFailed"

    }
}

// MARK: - HRV Detail Level Preference
enum HRVDetailLevel: String, CaseIterable {
    case suggestionOnly = "suggestionOnly"      // 仅建议
    case dataAndSuggestion = "dataAndSuggestion" // 数据及建议
    case chartAndData = "chartAndData"           // 折线图及数据及建议
}


// MARK: - HealthKit Manager
@MainActor
final class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()

    @Published var hrvEnabled: Bool {
        didSet { UserDefaults.standard.set(hrvEnabled, forKey: "hrv_enabled") }
    }
    @Published var hrvOnboardingCompleted: Bool {
        didSet { UserDefaults.standard.set(hrvOnboardingCompleted, forKey: "hrv_onboarding_completed") }
    }

    @Published var readiness: HRVReadiness = HRVReadiness(
        zScore: nil, todayHRV: nil, baselineMean: nil,
        baselineSampleCount: 0, category: .insufficient, suggestion: ""
    )

    /// Number of raw HealthKit samples found in the latest query (for diagnostics).
    @Published var lastSampleCount: Int = 0

    /// Daily HRV values for trend chart (most recent first).
    @Published var dailyHRVHistory: [DailyHRV] = []

    /// Controls how much detail the HRV card shows.
    @Published var hrvDetailLevel: HRVDetailLevel {
        didSet { UserDefaults.standard.set(hrvDetailLevel.rawValue, forKey: "hrv_detail_level") }
    }


    var isHealthKitAvailable: Bool { HKHealthStore.isHealthDataAvailable() }
    @Published var isAuthorized: Bool = false

    private init() {
        self.hrvEnabled = UserDefaults.standard.bool(forKey: "hrv_enabled")
        self.hrvOnboardingCompleted = UserDefaults.standard.bool(forKey: "hrv_onboarding_completed")
        self.hrvDetailLevel = HRVDetailLevel(rawValue: UserDefaults.standard.string(forKey: "hrv_detail_level") ?? "") ?? .dataAndSuggestion
        Task {
            await checkAuthorizationStatus()
            if hrvEnabled && hrvOnboardingCompleted {
                await refreshReadiness()
            }
        }
    }

    func requestAuthorization() async -> Bool {
        guard isHealthKitAvailable else { return false }
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return false }
        do {
            try await healthStore.requestAuthorization(toShare: [], read: [hrvType])
            await checkAuthorizationStatus()
            return isAuthorized
        } catch {
            print("[HealthKit] Auth error: \(error)")
            return false
        }
    }

    func checkAuthorizationStatus() async {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            isAuthorized = false; return
        }
        // Use async status check (iOS 15+) — synchronous authorizationStatus(for:)
        // can return stale results right after requestAuthorization completes.
        if let status = try? await healthStore.statusForAuthorizationRequest(toShare: [], read: [hrvType]) {
            isAuthorized = (status == .unnecessary)
        } else {
            isAuthorized = (healthStore.authorizationStatus(for: hrvType) == .sharingAuthorized)
        }
    }

    func enable() async {
        hrvEnabled = true
        let granted = await requestAuthorization()
        if granted { await refreshReadiness() }
    }

    func disable() {
        hrvEnabled = false
    }

    /// Fetch HRV (SDNN) samples from the past `days` calendar days.
    /// Returns empty array when no samples match; never returns nil.
    private func fetchHRVSamples(days: Int = 14) async -> [HKQuantitySample] {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            return []
        }
        let end = Date()
        guard let start = Calendar.current.date(byAdding: .day, value: -days, to: end) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        return await withCheckedContinuation { c in
            let q = HKSampleQuery(sampleType: hrvType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, results, error in
                if let error = error {
                    print("[HealthKit] Query error: \(error)")
                    c.resume(returning: [])
                    return
                }
                let samples = (results as? [HKQuantitySample]) ?? []
                print("[HealthKit] fetchHRVSamples: \(samples.count) raw samples found")
                c.resume(returning: samples)
            }
            healthStore.execute(q)
        }
    }

    func refreshReadiness() async {
        guard hrvEnabled, isAuthorized else {
            readiness = HRVReadiness(zScore: nil, todayHRV: nil, baselineMean: nil,
                baselineSampleCount: 0, category: .noAuthorization,
                suggestion: "Enable HealthKit access in Settings.".localized())
            return
        }
        let samples = await fetchHRVSamples(days: 14)
        lastSampleCount = samples.count

        guard !samples.isEmpty else {
            readiness = HRVReadiness(zScore: nil, todayHRV: nil, baselineMean: nil,
                baselineSampleCount: 0, category: .queryFailed,
                suggestion: "No HRV data found in Health. Wear your Apple Watch overnight for a few nights.".localized())
            print("[HealthKit] refreshReadiness: 0 samples found")
            return
        }

        let daily = extractDailyHRV(from: samples)
        dailyHRVHistory = daily
        print("[HealthKit] refreshReadiness: \(samples.count) raw samples → \(daily.count) distinct days")

        guard daily.count >= 7 else {
            readiness = HRVReadiness(zScore: nil, todayHRV: daily.first?.value,
                baselineMean: nil, baselineSampleCount: daily.count,
                category: .insufficient,
                suggestion: String(format: "%d days of HRV data. Wear your Apple Watch to sleep for at least 7 nights to establish a baseline.".localized(), daily.count))
            return
        }

        let today = daily.first?.value
        let past = Array(daily.dropFirst().map { $0.value })
        let mean = past.reduce(0, +) / Double(past.count)
        let variance = past.reduce(0) { $0 + pow($1 - mean, 2) } / Double(past.count)
        let stdDev = sqrt(variance)
        let z: Double? = today != nil && stdDev > 0 ? (today! - mean) / stdDev : nil
        let category: HRVReadiness.Category
        let suggestion: String
        if let z = z {
            if z > 1.0 {
                category = .excellent
                suggestion = "Your HRV is significantly above your baseline — great recovery! A prime day for focused studying.".localized()
            } else if z < -1.0 {
                category = .low
                suggestion = "Your HRV is below your baseline. You may be stressed or fatigued — consider lighter review or rest.".localized()
            } else {
                category = .normal
                suggestion = "Your HRV is within your normal range. Steady study rhythm recommended.".localized()
            }
        } else {
            category = .normal
            suggestion = "Your HRV is within your normal range. Steady study rhythm recommended.".localized()
        }
        readiness = HRVReadiness(zScore: z, todayHRV: today, baselineMean: mean,
            baselineSampleCount: daily.count, category: category, suggestion: suggestion)
    }


    private func extractDailyHRV(from samples: [HKQuantitySample]) -> [DailyHRV] {
        var map: [String: (Date, Double)] = [:]
        let cal = Calendar.current
        for s in samples {
            let key = cal.startOfDay(for: s.startDate).ISO8601Format()
            let v = s.quantity.doubleValue(for: HKUnit(from: "ms"))
            if map[key] == nil { map[key] = (s.startDate, v) }
        }
        return map.values.sorted { $0.0 > $1.0 }.map { DailyHRV(date: $0.0, value: $0.1) }
    }

    struct DailyHRV { let date: Date; let value: Double }
}
