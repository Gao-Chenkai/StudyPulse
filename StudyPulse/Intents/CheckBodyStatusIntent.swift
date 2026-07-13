import AppIntents
import Foundation

/// Returns today's body-status summary (sleep, heart rate, exercise) without opening the app.
/// 直接返回今日身体状态摘要(睡眠 / 心率 / 运动),不打开 App。
struct CheckBodyStatusIntent: AppIntent {

    static let title: LocalizedStringResource = "Check Body Status"

    static let description = IntentDescription(
        "Check your body status — sleep, heart rate, and exercise for today.",
        categoryName: "Health"
    )

    /// 后台执行,直接返回值(Siri / 灵动岛可读),不进入 UI
    /// Run in background and return a spoken dialog; no UI launch.
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some ReturnsValue<String> {
        // 1) 没有缓存 → 提示用户去主 App 开启 HealthKit 同步
        // 1) No cache → prompt the user to enable HealthKit in the main app.
        guard let cache = IntentDataLoader.loadHealthCache() else {
            return .result(
                value: "Body status data is not available yet. Open StudyPulse and enable HealthKit."
            )
        }

        // 2) 按需拼接 睡眠 / 心率 / 运动 三段
        // 2) Compose sleep / heart rate / exercise segments on demand.
        var parts: [String] = []
        if let sleep = cache.sleepHours {
            // 睡眠时长保留 1 位小数;quality 是 LLM 产出的英文标签,原样插入
            // 1-decimal sleep duration; `quality` is the LLM-emitted label, kept verbatim.
            let h = String(format: "%.1f", sleep)
            let quality = cache.sleepQuality ?? "unknown"
            parts.append("Sleep: \(h) hours (\(quality))")
        }
        if let hr = cache.restingHeartRate {
            parts.append("Resting heart rate: \(Int(hr)) bpm")
        }
        if let ex = cache.exerciseMinutes {
            parts.append("Exercise today: \(Int(ex)) minutes")
        }

        // 3) 三段都缺失:把这一情况明确告诉用户
        // 3) All three segments missing — make that explicit to the user.
        guard !parts.isEmpty else {
            return .result(value: "No body status data available for today.")
        }

        return .result(value: "Today's status — " + parts.joined(separator: ". ") + ".")
    }
}
