//
//  TrendWidgetSyncManager.swift
//  StudyPulse
//
//  Syncs grade trend data to Widget App Group
//

import Foundation
import WidgetKit
import os

@MainActor
enum TrendWidgetSyncManager {
    /// 把成绩趋势数据同步到 widget 共享容器。
    /// 优先使用用户在 widget 配置中选择的科目;否则选历史数据最多的科目。
    /// Sync grade trend data to the widget shared container. Prefers the
    /// user-selected subject; otherwise picks the subject with the most grades.
    static func syncTrend(grades: [Grade], subjects: [Subject]) {
        Log.widget.info("开始同步趋势 widget / Syncing trend widget: grades=\(grades.count, privacy: .public) subjects=\(subjects.count, privacy: .public)")
        let subjectScores = Dictionary(grouping: grades, by: \.subject)

        let chosenSubject: String?
        let preferredSubject = TrendWidgetDataStore.loadPreferredSubject()

        // If user has a preferred subject and it has grades, use it
        if let preferred = preferredSubject, subjectScores[preferred] != nil {
            chosenSubject = preferred
            Log.widget.debug("趋势 widget 使用用户偏好科目 / Trend widget using preferred subject: \(preferred, privacy: .public)")
        } else {
            // Otherwise fall back to auto-selection (subject with most grades)
            chosenSubject = subjectScores.max(by: { $0.value.count < $1.value.count })?.key
            if chosenSubject == nil {
                Log.widget.warning("趋势 widget 同步失败：没有可用的成绩 / Trend widget sync aborted: no grades available")
            } else {
                Log.widget.debug("趋势 widget 自动选择科目 / Trend widget auto-selected subject: \(chosenSubject ?? "-", privacy: .public)")
            }
        }

        guard let bestSubject = chosenSubject else {
            return
        }

        let subjectGrades = subjectScores[bestSubject]?.sorted(by: { $0.date < $1.date }) ?? []
        // fullScore 来自 Subject 配置;找不到时兜底 100(避免出现 >100% 折线)
        // fullScore comes from Subject config; fall back to 100 to avoid >100% chart values.
        let fullScore = subjects.first(where: { $0.name == bestSubject })?.fullScore ?? 100

        let points = subjectGrades.map { grade in
            TrendPoint(
                date: grade.date,
                score: grade.score,
                subject: bestSubject,
                fullScore: fullScore
            )
        }

        // 只保留最近 20 个点(避免 UserDefaults 体积过大,也是 widget 折线最佳展示量)
        // Keep only the 20 most recent points (limits UserDefaults size; also the
        // sweet spot for a readable line chart in the widget).
        let stored = Array(points.suffix(20))
        TrendWidgetDataStore.save(points: stored)
        WidgetCenter.shared.reloadTimelines(ofKind: "TrendWidget")
        Log.widget.info("趋势 widget 同步完成 / Trend widget sync done: subject=\(bestSubject, privacy: .public) points=\(stored.count, privacy: .public)")
    }
}