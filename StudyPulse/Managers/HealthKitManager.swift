//
//  HealthKitManager.swift
//  StudyPulse
//
//  HRV-based study readiness using HealthKit + personal baseline (Z-score)
//  plus body status (heart rate, respiratory rate, last-night sleep)
//  for personalized study suggestions.
//
import Foundation
import HealthKit
import Combine
import os

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

// MARK: - Body Status Result
/// Snapshot of today's vital signs, last night's sleep, and today's
/// exercise minutes, used to tailor study suggestions based on the
/// student's physical state.
struct BodyStatus: Equatable {
    /// Most recent resting heart rate (bpm). `nil` if unavailable.
    let restingHeartRate: Double?
    /// Most recent heart rate reading (bpm). `nil` if unavailable.
    let latestHeartRate: Double?
    /// Most recent respiratory rate (breaths/min). `nil` if unavailable.
    let respiratoryRate: Double?
    /// Hours of sleep last night (total). `nil` if no sleep sample was
    /// found. Kept for the user-facing "hours slept" label / sleep
    /// quality bucket — NOT used for the "recovery sleep" radar axis.
    let lastNightSleepHours: Double?
    /// Deep sleep (N3 / slow-wave sleep) hours last night. The
    /// physically most restorative stage. `nil` if no stage breakdown
    /// is available.
    let deepSleepHours: Double?
    /// REM sleep hours last night. The cognitively restorative stage
    /// responsible for memory consolidation. `nil` if no stage
    /// breakdown is available.
    let remSleepHours: Double?
    /// Categorical quality bucket for last night's sleep.
    let sleepQuality: SleepQuality
    /// Minutes of brisk exercise recorded today (Apple Exercise Time,
    /// the "green ring"). `nil` if HealthKit has no reading.
    let exerciseMinutesToday: Double?
    /// Whether any of the signals has fresh data and can be acted on.
    let isUsable: Bool

    /// Restorative sleep = deep (N3) + REM. This is the value the
    /// algorithm and the recovery-radar chart use for the "Recovery
    /// Sleep" axis, because it reflects the brain- and body-recovery
    /// stages of sleep, not just time-in-bed.
    var restorativeSleepHours: Double? {
        switch (deepSleepHours, remSleepHours) {
        case let (d?, r?): return d + r
        case let (d?, nil): return d
        case let (nil, r?): return r
        default: return nil
        }
    }

    enum SleepQuality: String, Equatable {
        case unknown
        case poor       // < 6h
        case short      // 6h - 7h
        case good       // 7h - 9h
        case excellent  // >= 9h
    }
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

    /// Latest snapshot of heart rate, breathing, last-night sleep,
    /// and today's exercise. Used by `StudySuggestionsCard` and the
    /// recovery-radar card to tailor study suggestions.
    @Published var bodyStatus: BodyStatus = BodyStatus(
        restingHeartRate: nil,
        latestHeartRate: nil,
        respiratoryRate: nil,
        lastNightSleepHours: nil,
        deepSleepHours: nil,
        remSleepHours: nil,
        sleepQuality: .unknown,
        exerciseMinutesToday: nil,
        isUsable: false
    )

    /// The user's personal 30-day baselines, recomputed whenever a
    /// new daily snapshot is recorded. Used by the readiness
    /// algorithm to calibrate scores against the user's own history
    /// rather than just the population average.
    @Published var personalBaselines: PersonalBaselines = .empty

    /// True when HealthKit has granted read access for the body-status
    /// types (heart rate, respiratory rate, sleep).
    @Published var bodyStatusAuthorized: Bool = false


    var isHealthKitAvailable: Bool { HKHealthStore.isHealthDataAvailable() }
    @Published var isAuthorized: Bool = false

    /// All HealthKit types we read from. Authorizing once covers HRV
    /// and the body status types together.
    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []
        if let hrv = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            types.insert(hrv)
        }
        if let hr = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            types.insert(hr)
        }
        if let rhr = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) {
            types.insert(rhr)
        }
        if let rr = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) {
            types.insert(rr)
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        if let exercise = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) {
            types.insert(exercise)
        }
        return types
    }

    private init() {
        self.hrvEnabled = UserDefaults.standard.bool(forKey: "hrv_enabled")
        self.hrvOnboardingCompleted = UserDefaults.standard.bool(forKey: "hrv_onboarding_completed")
        self.hrvDetailLevel = HRVDetailLevel(rawValue: UserDefaults.standard.string(forKey: "hrv_detail_level") ?? "") ?? .dataAndSuggestion
        // Load any previously saved 30-day history so the algorithm
        // starts with a personal baseline as soon as the app opens.
        let history = HealthHistoryStore.load()
        self.personalBaselines = PersonalBaselines.compute(from: history)
        Log.healthKit.info("HealthKitManager 初始化 / HealthKitManager init; enabled=\(self.hrvEnabled, privacy: .public) onboarded=\(self.hrvOnboardingCompleted, privacy: .public) historyCount=\(history.count, privacy: .public)")
        // 注意：不在 init 里立刻发起 HealthKit 查询；
        // 由 App 在主数据加载完成后再调用 bootstrap()，避免和 DataManager 启动 I/O 竞争。
    }

    /// 启动时调用：在主数据加载就绪后再去请求 HealthKit 授权与刷新数据。
    /// Called on launch: only after the main data is ready, request HK auth and refresh data.
    func bootstrap() async {
        Log.healthKit.info("HealthKit bootstrap 开始 / HealthKit bootstrap start")
        await checkAuthorizationStatus()
        Log.healthKit.info("HealthKit 授权状态 / HealthKit authorization: isAuthorized=\(self.isAuthorized, privacy: .public) bodyStatusAuthorized=\(self.bodyStatusAuthorized, privacy: .public)")
        if hrvEnabled && hrvOnboardingCompleted {
            await refreshReadiness()
            await refreshBodyStatus()
        } else {
            Log.healthKit.debug("HRV 未启用或未完成引导，跳过刷新 / HRV not enabled or onboarding incomplete, skipping refresh")
        }
    }

    func requestAuthorization() async -> Bool {
        guard isHealthKitAvailable else {
            Log.healthKit.warning("HealthKit 在此设备不可用 / HealthKit is not available on this device")
            return false
        }
        do {
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
            await checkAuthorizationStatus()
            Log.healthKit.info("HealthKit 授权完成 / HealthKit authorization complete; isAuthorized=\(self.isAuthorized, privacy: .public)")
            return isAuthorized
        } catch {
            Log.healthKit.error("HealthKit 鉴权失败 / HealthKit Auth error: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    func checkAuthorizationStatus() async {
        let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)
        let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
        // Use async status check (iOS 15+) — synchronous authorizationStatus(for:)
        // can return stale results right after requestAuthorization completes.
        if let status = try? await healthStore.statusForAuthorizationRequest(toShare: [], read: readTypes) {
            isAuthorized = (status == .unnecessary)
            Log.healthKit.debug("HealthKit 异步授权状态 / HealthKit async authorization status: \(status.rawValue, privacy: .public)")
        } else {
            let hrvStatus = hrvType.map { healthStore.authorizationStatus(for: $0) } ?? .notDetermined
            isAuthorized = (hrvStatus == .sharingAuthorized)
            Log.healthKit.debug("HealthKit 同步授权状态 / HealthKit sync authorization status: \(hrvStatus.rawValue, privacy: .public)")
        }
        // Treat body status as authorized when the user granted access to
        // any of the relevant types. HealthKit only returns "authorized" or
        // "denied", never "never asked", so we conservatively assume it's
        // available once the umbrella status is unnecessary/sharingAuthorized.
        bodyStatusAuthorized = isAuthorized ||
            (hrType.map { healthStore.authorizationStatus(for: $0) == .sharingAuthorized } ?? false) ||
            (sleepType.map { healthStore.authorizationStatus(for: $0) == .sharingAuthorized } ?? false)
        Log.healthKit.debug("HealthKit 详细状态 / HealthKit detailed status: isAuthorized=\(self.isAuthorized, privacy: .public) bodyStatusAuthorized=\(self.bodyStatusAuthorized, privacy: .public)")
    }

    func enable() async {
        Log.healthKit.info("用户启用 HRV / HRV enable requested")
        hrvEnabled = true
        let granted = await requestAuthorization()
        if granted {
            await refreshReadiness()
            await refreshBodyStatus()
        } else {
            Log.healthKit.warning("HRV 启用后未获得授权 / HRV enable: not authorized")
        }
    }

    func disable() {
        Log.healthKit.info("用户禁用 HRV / HRV disable requested")
        hrvEnabled = false
    }

    /// Fetch HRV (SDNN) samples from the past `days` calendar days.
    /// Returns empty array when no samples match; never returns nil.
    private func fetchHRVSamples(days: Int = 14) async -> [HKQuantitySample] {
        Log.healthKit.debug("开始获取最近 \(days, privacy: .public) 天 HRV 样本 / Fetching HRV samples for last \(days, privacy: .public) days")
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            Log.healthKit.warning("HRV 类型不可用 / HRV type unavailable")
            return []
        }
        let end = Date()
        guard let start = Calendar.current.date(byAdding: .day, value: -days, to: end) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        return await withCheckedContinuation { c in
            let q = HKSampleQuery(sampleType: hrvType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, results, error in
                if let error = error {
                    Log.healthKit.error("HRV 查询失败 / HRV Query error: \(error.localizedDescription, privacy: .public)")
                    c.resume(returning: [])
                    return
                }
                let samples = (results as? [HKQuantitySample]) ?? []
                Log.healthKit.debug("HRV 样本获取成功 / HRV samples fetched: rawCount=\(samples.count, privacy: .public) start=\(start, privacy: .public) end=\(end, privacy: .public)")
                c.resume(returning: samples)
            }
            healthStore.execute(q)
        }
    }

    /// Fetch the most recent heart-rate reading (any kind) within the past day.
    private func fetchLatestHeartRate() async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return nil }
        let end = Date()
        guard let start = Calendar.current.date(byAdding: .hour, value: -24, to: end) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        return await withCheckedContinuation { c in
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, results, _ in
                let sample = (results as? [HKQuantitySample])?.first
                let value = sample.map { $0.quantity.doubleValue(for: HKUnit(from: "count/min")) }
                c.resume(returning: value)
            }
            healthStore.execute(q)
        }
    }

    /// Fetch the most recent resting heart-rate reading within the past 7 days.
    private func fetchRestingHeartRate() async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return nil }
        let end = Date()
        guard let start = Calendar.current.date(byAdding: .day, value: -7, to: end) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        return await withCheckedContinuation { c in
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, results, _ in
                let sample = (results as? [HKQuantitySample])?.first
                let value = sample.map { $0.quantity.doubleValue(for: HKUnit(from: "count/min")) }
                c.resume(returning: value)
            }
            healthStore.execute(q)
        }
    }

    /// Fetch the most recent respiratory-rate reading within the past day.
    private func fetchLatestRespiratoryRate() async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) else { return nil }
        let end = Date()
        guard let start = Calendar.current.date(byAdding: .day, value: -1, to: end) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        return await withCheckedContinuation { c in
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, results, _ in
                let sample = (results as? [HKQuantitySample])?.first
                let value = sample.map { $0.quantity.doubleValue(for: HKUnit(from: "count/min")) }
                c.resume(returning: value)
            }
            healthStore.execute(q)
        }
    }

    /// Fetch last night's sleep and return total hours, deep (N3)
    /// hours, REM hours, and a quality bucket. The quality bucket is
    /// based on TOTAL sleep hours (so the user-facing label matches
    /// what they think of as "a 7-hour night"), but the algorithm
    /// itself uses deep+REM ("restorative sleep") for calibration.
    private func fetchLastNightSleep() async -> (
        hours: Double, deepHours: Double, remHours: Double,
        quality: BodyStatus.SleepQuality
    )? {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let cal = Calendar.current
        let now = Date()
        // Look at sleep that ended within the last 18 hours, started after 6 PM yesterday
        // at the latest. That covers both early risers and night owls.
        guard let earliestStart = cal.date(byAdding: .hour, value: -24, to: now) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: earliestStart, end: now, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        return await withCheckedContinuation { c in
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, results, _ in
                guard let samples = results as? [HKCategorySample], !samples.isEmpty else {
                    c.resume(returning: nil)
                    return
                }
                // Asleep values from HKCategoryValueSleepAnalysis.
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue
                ]
                let deepValue = HKCategoryValueSleepAnalysis.asleepDeep.rawValue
                let remValue = HKCategoryValueSleepAnalysis.asleepREM.rawValue
                // Group samples into contiguous sleep sessions (gap > 90 min = new session).
                let sorted = samples.sorted { $0.startDate < $1.startDate }
                var sessions: [(start: Date, end: Date, deep: TimeInterval, rem: TimeInterval)] = []
                for s in sorted where asleepValues.contains(s.value) {
                    let dur = max(0, s.endDate.timeIntervalSince(s.startDate))
                    let isDeep = s.value == deepValue
                    let isRem = s.value == remValue
                    if var last = sessions.last, s.startDate.timeIntervalSince(last.end) < 90 * 60 {
                        last.end = max(last.end, s.endDate)
                        if isDeep { last.deep += dur }
                        else if isRem { last.rem += dur }
                        sessions[sessions.count - 1] = last
                    } else {
                        sessions.append((s.startDate, s.endDate,
                                         isDeep ? dur : 0,
                                         isRem ? dur : 0))
                    }
                }
                // The most recent session is "last night" if it ended within the last 18h.
                guard let last = sessions.last,
                      now.timeIntervalSince(last.end) < 18 * 3600 else {
                    c.resume(returning: nil)
                    return
                }
                let hours = max(0, last.end.timeIntervalSince(last.start) / 3600.0)
                let deepHours = max(0, last.deep / 3600.0)
                let remHours = max(0, last.rem / 3600.0)
                let quality: BodyStatus.SleepQuality
                if hours < 6 { quality = .poor }
                else if hours < 7 { quality = .short }
                else if hours < 9 { quality = .good }
                else { quality = .excellent }
                c.resume(returning: (hours: hours,
                                     deepHours: deepHours,
                                     remHours: remHours,
                                     quality: quality))
            }
            healthStore.execute(q)
        }
    }

    /// Sum today's Apple Exercise Time samples (the green "Exercise"
    /// activity ring). Returns `nil` when no samples exist for today.
    /// Apple Exercise Time is the number of minutes of brisk activity
    /// recorded by the Apple Watch or a connected source.
    private func fetchTodayExerciseMinutes() async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) else {
            return nil
        }
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { c in
            let q = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                let value = result?
                    .sumQuantity()?
                    .doubleValue(for: HKUnit.minute())
                c.resume(returning: value)
            }
            healthStore.execute(q)
        }
    }

    /// Refresh the body status snapshot. Safe to call repeatedly.
    /// Also records today's snapshot to the 30-day history (used to
    /// calibrate the algorithm) and recomputes personal baselines.
    func refreshBodyStatus() async {
        guard hrvEnabled, isAuthorized else {
            bodyStatus = BodyStatus(
                restingHeartRate: nil,
                latestHeartRate: nil,
                respiratoryRate: nil,
                lastNightSleepHours: nil,
                deepSleepHours: nil,
                remSleepHours: nil,
                sleepQuality: .unknown,
                exerciseMinutesToday: nil,
                isUsable: false
            )
            return
        }
        async let restingHR = fetchRestingHeartRate()
        async let latestHR = fetchLatestHeartRate()
        async let respRate = fetchLatestRespiratoryRate()
        async let sleep = fetchLastNightSleep()
        async let exercise = fetchTodayExerciseMinutes()
        let (rhr, lhr, rr, sl, ex) = await (restingHR, latestHR, respRate, sleep, exercise)
        let hasAny = rhr != nil || lhr != nil || rr != nil || sl != nil || ex != nil
        bodyStatus = BodyStatus(
            restingHeartRate: rhr,
            latestHeartRate: lhr,
            respiratoryRate: rr,
            lastNightSleepHours: sl?.hours,
            deepSleepHours: sl?.deepHours,
            remSleepHours: sl?.remHours,
            sleepQuality: sl?.quality ?? .unknown,
            exerciseMinutesToday: ex,
            isUsable: hasAny
        )
        Log.healthKit.info("refreshBodyStatus 完成 / refreshBodyStatus done; hr=\(lhr?.description ?? "-", privacy: .public) rhr=\(rhr?.description ?? "-", privacy: .public) rr=\(rr?.description ?? "-", privacy: .public) sleep=\(sl?.hours.description ?? "-", privacy: .public)h deep=\(sl?.deepHours.description ?? "-", privacy: .public)h rem=\(sl?.remHours.description ?? "-", privacy: .public)h exercise=\(ex?.description ?? "-", privacy: .public)min isUsable=\(hasAny, privacy: .public)")

        // Record today's snapshot to the 30-day history. We use the
        // first sample of the day for HRV (via `fetchHRVSamples`
        // history); here we just record what we have so far and
        // `fetchHRVForHistory` back-fills today's HRV specifically.
        let todayHRV = await fetchTodayHRV()
       recordTodaySnapshot(todayHRV: todayHRV)
        writeIntentHealthCache()
   }

    /// Fetch today's first HRV sample for the daily history snapshot.
    private func fetchTodayHRV() async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            return nil
        }
        let start = Calendar.current.startOfDay(for: Date())
        let end = Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        return await withCheckedContinuation { c in
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, results, _ in
                let sample = (results as? [HKQuantitySample])?.first
                let value = sample.map { $0.quantity.doubleValue(for: HKUnit(from: "ms")) }
                c.resume(returning: value)
            }
            healthStore.execute(q)
        }
    }

    /// Persist today's snapshot and recompute the 30-day baselines
    /// that the algorithm reads from. No-op if every field is nil
    /// (i.e. we couldn't read any signal today).
    private func recordTodaySnapshot(todayHRV: Double?) {
        let bs = bodyStatus
        guard bs.isUsable || todayHRV != nil else { return }
        let snapshot = DailyHealthSnapshot(
            date: Date(),
            hrv: todayHRV,
            restingHeartRate: bs.restingHeartRate,
            respiratoryRate: bs.respiratoryRate,
            sleepHours: bs.lastNightSleepHours,
            deepSleepHours: bs.deepSleepHours,
            remSleepHours: bs.remSleepHours,
            exerciseMinutes: bs.exerciseMinutesToday
        )
        let history = HealthHistoryStore.upsert(snapshot: snapshot)
        personalBaselines = PersonalBaselines.compute(from: history)
    }

    func refreshReadiness() async {
        Log.healthKit.info("refreshReadiness 开始 / refreshReadiness start")
        guard hrvEnabled, isAuthorized else {
            readiness = HRVReadiness(zScore: nil, todayHRV: nil, baselineMean: nil,
                baselineSampleCount: 0, category: .noAuthorization,
                suggestion: "Enable HealthKit access in Settings.".localized())
            Log.healthKit.warning("refreshReadiness 跳过：未启用或未授权 / refreshReadiness skipped: not enabled or not authorized")
            HRVWidgetSyncManager.syncHRV(from: self)
            return
        }
        let samples = await fetchHRVSamples(days: 14)
        lastSampleCount = samples.count

        guard !samples.isEmpty else {
            readiness = HRVReadiness(zScore: nil, todayHRV: nil, baselineMean: nil,
                baselineSampleCount: 0, category: .queryFailed,
                suggestion: "No HRV data found in Health. Wear your Apple Watch overnight for a few nights.".localized())
            Log.healthKit.warning("refreshReadiness 未找到 HRV 样本 / refreshReadiness: 0 samples found")
            HRVWidgetSyncManager.syncHRV(from: self)
            return
        }

        let daily = extractDailyHRV(from: samples)
        dailyHRVHistory = daily
        Log.healthKit.info("refreshReadiness 解析完成 / refreshReadiness: rawSamples=\(samples.count, privacy: .public) distinctDays=\(daily.count, privacy: .public)")

        guard daily.count >= 7 else {
            readiness = HRVReadiness(zScore: nil, todayHRV: daily.first?.value,
                baselineMean: nil, baselineSampleCount: daily.count,
                category: .insufficient,
                suggestion: String(format: "%d days of HRV data. Wear your Apple Watch to sleep for at least 7 nights to establish a baseline.".localized(), daily.count))
            Log.healthKit.info("refreshReadiness 数据不足 / refreshReadiness: insufficient data days=\(daily.count, privacy: .public)")
            HRVWidgetSyncManager.syncHRV(from: self)
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
       Log.healthKit.info("refreshReadiness 完成 / refreshReadiness done; category=\(category.rawValue, privacy: .public) z=\(z ?? 0, privacy: .public) today=\(today ?? 0, privacy: .public) baseline=\(mean, privacy: .public) stdDev=\(stdDev, privacy: .public) days=\(daily.count, privacy: .public)")
       HRVWidgetSyncManager.syncHRV(from: self)
        writeIntentHealthCache()
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

    // MARK: - Intent Health Cache

    /// Writes the latest readiness + body-status snapshot so background
    /// App Intents can surface health-aware study suggestions without
    /// opening the app.
    private func writeIntentHealthCache() {
        let qualityStr: String = switch bodyStatus.sleepQuality {
        case .unknown: "unknown"
        case .poor: "poor"
        case .short: "short"
        case .good: "good"
        case .excellent: "excellent"
        }

        let cache = IntentHealthCache(
            readinessCategory: readiness.category.rawValue,
            readinessSuggestion: readiness.suggestion,
            sleepHours: bodyStatus.lastNightSleepHours,
            sleepQuality: qualityStr,
            restingHeartRate: bodyStatus.restingHeartRate,
            exerciseMinutes: bodyStatus.exerciseMinutesToday,
            lastUpdated: Date()
        )

        guard let data = try? JSONEncoder().encode(cache) else { return }
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("readiness_cache.json")
        try? data.write(to: url)
    }
}
