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
        case loading = "loading"          // 启动期 bootstrap 占位 / placeholder during bootstrap
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

    /// 启动期 bootstrap 阶段标志。true 表示后台仍在跑 14 天 HRV 查询 +
    /// PersonalBaselines 重算，UI 应显示 Loading 占位。
    /// Bootstrap phase flag. While `true`, the background task is still
    /// running the 14-day HRV query and PersonalBaselines recompute,
    /// so the UI should show a Loading placeholder.
    @Published var isHealthBootstrapping: Bool = false

    /// HRV 增量查询水位：上一次成功执行的 `refreshReadiness` 截止时间。
    /// 下一次 `refreshReadiness` 只查询 `[lastHRVQueryEndDate, now]`
    /// 区间的新样本，避免每次都拉全量 14 天。
    /// Incremental HRV query watermark: the end date of the last
    /// successful `refreshReadiness`. Subsequent calls only fetch
    /// samples in `[lastHRVQueryEndDate, now]`, avoiding a full
    /// 14-day pull on every refresh.
    @Published var lastHRVQueryEndDate: Date? {
        didSet { UserDefaults.standard.set(lastHRVQueryEndDate, forKey: "hrv_last_query_end_date") }
    }


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
        // 恢复上次的 HRV 增量查询水位
        // Restore the last HRV query watermark for incremental queries
        self.lastHRVQueryEndDate = UserDefaults.standard.object(forKey: "hrv_last_query_end_date") as? Date
        // Load any previously saved 30-day history so the algorithm
        // starts with a personal baseline as soon as the app opens.
        let history = HealthHistoryStore.load()
        self.personalBaselines = PersonalBaselines.compute(from: history)
        Log.healthKit.info("HealthKitManager 初始化 / HealthKitManager init; enabled=\(self.hrvEnabled, privacy: .public) onboarded=\(self.hrvOnboardingCompleted, privacy: .public) historyCount=\(history.count, privacy: .public) watermark=\(self.lastHRVQueryEndDate?.description ?? "nil", privacy: .public)")
        // 注意：不在 init 里立刻发起 HealthKit 查询；
        // 由 App 在主数据加载完成后再调用 bootstrap()，避免和 DataManager 启动 I/O 竞争。
    }

    /// 启动时调用：在主数据加载就绪后再去请求 HealthKit 授权与刷新数据。
    /// 分两段执行：
    ///  1) **缓存 + 占位**：检查授权；若 HRV 未启用/未完成引导直接返回；
    ///     否则把 `isHealthBootstrapping` 置 true、把 readiness 切到
    ///     `.loading` 占位，让 UI 立即显示 Loading 并返回，不阻塞主线程。
    ///  2) **后台补全**：派生一个独立 Task 跑 `runBootstrapBackground()`，
    ///     完成 14 天 HRV 查询 + 30 天基线重算，结束时把
    ///     `isHealthBootstrapping` 置 false 并显式 `objectWillChange.send()`
    ///     触发一次刷新。
    /// Called on launch: only after the main data is ready, request HK auth and refresh data.
    /// Two-phase bootstrap:
    ///  1) Cache + placeholder: check auth; if HRV isn't enabled/onboarded
    ///     return immediately. Otherwise set `isHealthBootstrapping = true`
    ///     and switch readiness to the `.loading` category so the UI
    ///     shows a Loading placeholder without blocking the main thread.
    ///  2) Background completion: spawn a detached task that runs
    ///     `runBootstrapBackground()` (14-day HRV query + 30-day
    ///     PersonalBaselines recompute), then flips the bootstrap flag
    ///     off and explicitly calls `objectWillChange.send()` for a
    ///     single UI refresh.
    func bootstrap() async {
        Log.healthKit.info("HealthKit bootstrap 开始 / start (two-phase)")
        await checkAuthorizationStatus()
        Log.healthKit.info("HealthKit 授权状态 / auth: isAuthorized=\(self.isAuthorized, privacy: .public) bodyStatusAuthorized=\(self.bodyStatusAuthorized, privacy: .public)")
        guard hrvEnabled, hrvOnboardingCompleted else {
            Log.healthKit.debug("HRV 未启用或未完成引导，跳过刷新 / HRV not enabled or onboarding incomplete, skipping refresh")
            return
        }

        // ----- Phase 1: 缓存 + 占位 / cache + placeholder -----
        // 立即把状态切到 loading，避免首屏卡住显示 "insufficient"。
        // Flip the state to loading immediately so the home view
        // doesn't sit on a stale "insufficient" placeholder.
        isHealthBootstrapping = true
        if readiness.category != .loading {
            readiness = HRVReadiness(
                zScore: nil,
                todayHRV: nil,
                baselineMean: nil,
                baselineSampleCount: 0,
                category: .loading,
                suggestion: "Loading...".localized()
            )
        }
        HRVWidgetSyncManager.syncHRV(from: self)
        Log.healthKit.info("HealthKit bootstrap phase1 完成，进入后台补全 / phase1 done, dispatching background")

        // ----- Phase 2: 后台补全 / background completion -----
        // 用 Task 派生后台工作；@MainActor 类的实例方法仍由主 Actor 调度，
        // 内部 `await` 的 HK 查询是异步挂起的，不会阻塞主线程。
        // Spawn a Task for the background work. The HK queries inside
        // are async-suspending and run off the main thread; only the
        // final @Published assignments briefly hop back to main.
        Task { [weak self] in
            await self?.runBootstrapBackground()
        }
    }

    /// Bootstrap 第二阶段：跑 HRV 增量查询 + body status 刷新 +
    /// PersonalBaselines 后台重算，结束后翻 `isHealthBootstrapping`
    /// 标志位并显式 `objectWillChange.send()` 触发单次 UI 刷新。
    /// Bootstrap phase 2: incremental HRV query, body status refresh,
    /// PersonalBaselines recompute. Flips the bootstrap flag off and
    /// sends a single `objectWillChange` for one UI refresh.
    private func runBootstrapBackground() async {
        Log.healthKit.info("HealthKit bootstrap phase2 开始 / phase2 start")
        await refreshReadiness()
        await refreshBodyStatus()
        isHealthBootstrapping = false
        objectWillChange.send()
        Log.healthKit.info("HealthKit bootstrap phase2 完成 / phase2 done; category=\(self.readiness.category.rawValue, privacy: .public) isUsable=\(self.bodyStatus.isUsable, privacy: .public)")
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

    /// Fetch HRV (SDNN) samples in `[start, end)`. Returns empty array
    /// when no samples match; never returns nil. Used by
    /// `refreshReadiness` for both the initial 14-day pull and the
    /// incremental `[lastQueryEndDate, now)` delta.
    private func fetchHRVSamples(start: Date, end: Date) async -> [HKQuantitySample] {
        Log.healthKit.debug("获取 HRV 样本 / Fetching HRV samples: start=\(start, privacy: .public) end=\(end, privacy: .public)")
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            Log.healthKit.warning("HRV 类型不可用 / HRV type unavailable")
            return []
        }
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
    ///
    /// 流程：
    ///  1) 并行跑 5 路 HK 查询（async let，全部异步挂起、不阻塞主线程）。
    ///  2) 拿到结果后立即把 `bodyStatus` 设上 — 唤醒 UI。
    ///  3) `recordTodaySnapshotAsync` 把今日 snapshot 写入
    ///     `~/Documents/health_history.json` 并在后台线程上重算
    ///     `PersonalBaselines`（CPU 密集），完事再回主 Actor 写
    ///     `personalBaselines` @Published 触发单次刷新。
    ///
    /// Flow:
    ///  1) Fire 5 parallel HK queries (async let — non-blocking).
    ///  2) Publish `bodyStatus` immediately so the UI wakes up.
    ///  3) `recordTodaySnapshotAsync` writes today's snapshot to
    ///     health_history.json and recomputes `PersonalBaselines` on
    ///     a background queue (CPU-bound), then assigns the @Published
    ///     on the main actor to trigger a single UI refresh.
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
        let newBodyStatus = BodyStatus(
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
        bodyStatus = newBodyStatus
        Log.healthKit.info("refreshBodyStatus 完成 / done; hr=\(lhr?.description ?? "-", privacy: .public) rhr=\(rhr?.description ?? "-", privacy: .public) rr=\(rr?.description ?? "-", privacy: .public) sleep=\(sl?.hours.description ?? "-", privacy: .public)h deep=\(sl?.deepHours.description ?? "-", privacy: .public)h rem=\(sl?.remHours.description ?? "-", privacy: .public)h exercise=\(ex?.description ?? "-", privacy: .public)min isUsable=\(hasAny, privacy: .public)")

        // Record today's snapshot to the 30-day history. We use the
        // first sample of the day for HRV (via `fetchHRVSamples`
        // history); here we just record what we have so far and
        // `fetchHRVForHistory` back-fills today's HRV specifically.
        // The file I/O + baselines compute are offloaded to a
        // background queue to keep the main thread responsive.
        let todayHRV = await fetchTodayHRV()
        recordTodaySnapshotAsync(bodyStatus: newBodyStatus, todayHRV: todayHRV)
        writeIntentHealthCache()
   }

    /// Snapshot recording + 30-day baseline recompute, run on a
    /// background queue. Writes the merged history file and assigns
    /// the resulting `personalBaselines` back on the main actor so
    /// SwiftUI gets a single `objectWillChange` pulse.
    private func recordTodaySnapshotAsync(bodyStatus bs: BodyStatus, todayHRV: Double?) {
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
        Task.detached(priority: .utility) { [weak self] in
            // 文件 I/O + PersonalBaselines.compute 都在后台线程跑，
            // PersonalBaselines.compute 是纯函数，非 actor 隔离。
            // File I/O + baseline recompute run on a background thread;
            // `PersonalBaselines.compute` is a pure function, not
            // actor-isolated, so it's safe to call off the main actor.
            let history = HealthHistoryStore.upsert(snapshot: snapshot)
            let newBaselines = PersonalBaselines.compute(from: history)
            await MainActor.run {
                self?.personalBaselines = newBaselines
                Log.healthKit.info("PersonalBaselines 后台重算完成 / background recompute done; samples=\(history.count, privacy: .public)")
            }
        }
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

    /// Refresh the HRV readiness state.
    ///
    /// 增量策略：缓存 `lastHRVQueryEndDate`，下次只拉
    /// `[lastHRVQueryEndDate, now)` 的新样本并与现有 `dailyHRVHistory`
    /// 合并，避免每次 refreshReadiness 都查全量 14 天。
    /// 首次调用（无水位）退回到 14 天全量查询。
    ///
    /// Incremental strategy: cache `lastHRVQueryEndDate` and only pull
    /// `[lastHRVQueryEndDate, now)` new samples on each call, merging
    /// them into `dailyHRVHistory`. The very first call (no watermark
    /// yet) falls back to the full 14-day pull.
    func refreshReadiness() async {
        Log.healthKit.info("refreshReadiness 开始 / start")
        guard hrvEnabled, isAuthorized else {
            readiness = HRVReadiness(zScore: nil, todayHRV: nil, baselineMean: nil,
                baselineSampleCount: 0, category: .noAuthorization,
                suggestion: "Enable HealthKit access in Settings.".localized())
            Log.healthKit.warning("refreshReadiness 跳过：未启用或未授权 / skipped: not enabled or not authorized")
            HRVWidgetSyncManager.syncHRV(from: self)
            return
        }
        let end = Date()
        // 增量窗口：未命中水位时回退到 14 天全量；命中时只取水位到现在的 delta。
        // Incremental window: no watermark → 14-day full pull; otherwise
        // only fetch the [watermark, now) delta.
        let watermark = lastHRVQueryEndDate
        let start: Date
        if let w = watermark, w < end {
            // 略微往回覆盖 1 天，应对 HK 写入时间戳的轻微回填。
            // Nudge the start back 1 day to absorb any late-arriving
            // samples whose startDate is just before the previous query end.
            let lookback = Calendar.current.date(byAdding: .day, value: -1, to: w) ?? w
            start = max(lookback, Calendar.current.date(byAdding: .day, value: -14, to: end) ?? end)
            Log.healthKit.info("refreshReadiness 增量查询 / incremental: from=\(start, privacy: .public) to=\(end, privacy: .public)")
        } else {
            start = Calendar.current.date(byAdding: .day, value: -14, to: end) ?? end
            Log.healthKit.info("refreshReadiness 首次查询（14 天全量）/ first run (14d full): from=\(start, privacy: .public) to=\(end, privacy: .public)")
        }

        let newSamples = await fetchHRVSamples(start: start, end: end)
        lastSampleCount = newSamples.count
        lastHRVQueryEndDate = end

        // 合并到 dailyHRVHistory：去重（同日只保留第一个样本）+ 按日期降序。
        // Merge into `dailyHRVHistory`: dedup (one entry per day, the
        // first sample) and sort by date descending.
        let existingDays = Set(dailyHRVHistory.map { Calendar.current.startOfDay(for: $0.date) })
        let newDaily = extractDailyHRV(from: newSamples)
            .filter { !existingDays.contains(Calendar.current.startOfDay(for: $0.date)) }
        if !newDaily.isEmpty {
            dailyHRVHistory = (dailyHRVHistory + newDaily).sorted { $0.date > $1.date }
            Log.healthKit.info("refreshReadiness 合并新增 / merged new daily entries: added=\(newDaily.count, privacy: .public) total=\(self.dailyHRVHistory.count, privacy: .public)")
        } else if !dailyHRVHistory.isEmpty {
            Log.healthKit.debug("refreshReadiness 无新样本，复用历史 / no new samples, reusing history: days=\(self.dailyHRVHistory.count, privacy: .public)")
        }

        let daily = dailyHRVHistory
        guard !daily.isEmpty else {
            readiness = HRVReadiness(zScore: nil, todayHRV: nil, baselineMean: nil,
                baselineSampleCount: 0, category: .queryFailed,
                suggestion: "No HRV data found in Health. Wear your Apple Watch overnight for a few nights.".localized())
            Log.healthKit.warning("refreshReadiness 未找到 HRV 样本 / 0 samples found")
            HRVWidgetSyncManager.syncHRV(from: self)
            return
        }
        Log.healthKit.info("refreshReadiness 解析完成 / parsed: rawNewSamples=\(newSamples.count, privacy: .public) distinctDays=\(daily.count, privacy: .public)")

        guard daily.count >= 7 else {
            readiness = HRVReadiness(zScore: nil, todayHRV: daily.first?.value,
                baselineMean: nil, baselineSampleCount: daily.count,
                category: .insufficient,
                suggestion: String(format: "%d days of HRV data. Wear your Apple Watch to sleep for at least 7 nights to establish a baseline.".localized(), daily.count))
            Log.healthKit.info("refreshReadiness 数据不足 / insufficient data: days=\(daily.count, privacy: .public)")
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
        Log.healthKit.info("refreshReadiness 完成 / done; category=\(category.rawValue, privacy: .public) z=\(z ?? 0, privacy: .public) today=\(today ?? 0, privacy: .public) baseline=\(mean, privacy: .public) stdDev=\(stdDev, privacy: .public) days=\(daily.count, privacy: .public)")
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
