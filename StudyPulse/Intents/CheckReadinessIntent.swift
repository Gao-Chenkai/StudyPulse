import AppIntents
import Foundation

/// Returns the latest HRV-based readiness suggestion without opening the app.
/// 直接返回基于 HRV 的最新"学习就绪度"建议,不打 App。
struct CheckReadinessIntent: AppIntent {

    static let title: LocalizedStringResource = "Check Study Readiness"

    static let description = IntentDescription(
        "Check your HRV-based study readiness and suggestions.",
        categoryName: "Health"
    )

    /// 后台执行,直接返回文案
    /// Run in background and return the dialog directly.
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some ReturnsValue<String> {
        // 缓存 / 分类 / 建议 三者都存在时才有可读内容;
        // 否则统一用一段 fallback 提示引导用户开启 HealthKit。
        // Only return the suggestion if cache + category + suggestion
        // are all populated; otherwise prompt the user to enable HealthKit.
        guard let cache = IntentDataLoader.loadHealthCache(),
              let suggestion = cache.readinessSuggestion,
              cache.readinessCategory != nil else {
            return .result(
                value: "Study readiness data is not available yet. Open StudyPulse and enable HealthKit to get personalized suggestions."
            )
        }

        return .result(value: suggestion)
    }
}
