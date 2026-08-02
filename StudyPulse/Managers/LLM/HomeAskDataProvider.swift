//
//  HomeAskDataProvider.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/7/11.
//
//  主页 AI 提问"路由 → 抓取 → 回答"中的"抓取"环节。
//  按 `HomeAskRouterLLM.Category` 类别,从 app 各数据源(HRV / 成绩 / 周报 / 错题 / 闪卡)
//  拉取对应数据并序列化为 Markdown 文本片段,供回答阶段喂给 LLM。
//
//  设计要点:
//  - 所有 fetch 都是纯函数 + 同步内存读,不发起网络请求(LLM 阶段才发请求)
//  - 数据尽量紧凑(数字 + 关键字段),避免浪费 LLM context window
//  - 单个 fetch 失败不抛异常,而是返回 "(本类别暂无数据)"
//

import Foundation
import SwiftUI

/// 主页 AI 提问的"按需数据抓取"层。
/// 在调用 LLM 之前按类别从 app 各数据源拉取数据并序列化为 Markdown。
/// On-demand data fetcher for the Home Ask AI. Pulls data from the
/// app's repositories per category and serialises it as Markdown before
/// feeding it to the LLM.
@MainActor
struct HomeAskDataProvider {
    let container: RepositoryContainer   // 主数据访问入口 / Repository facade
    let hrvManager: HealthKitManager    // HealthKit / HRV 数据 / HealthKit & HRV data
    let profile: UserProfile             // 当前用户档案 / Current user profile

    // MARK: - 4 类抓取入口 / 4 fetch entry points
    // MARK: - 4 类抓取入口

    /// 抓取 `body` 类数据(HRV / RHR / 睡眠 / 呼吸 / 锻炼 + 30 天基线)
    func fetchBody() -> String {
        guard hrvManager.hrvEnabled && hrvManager.hrvOnboardingCompleted else {
            return "## 身体状态\n(未启用 HRV / 未完成引导)\n"
        }
        let ctx = StudyReadinessAlgorithm.buildBodyReadinessContext(
            hrvEnabled: hrvManager.hrvEnabled,
            hrvOnboardingCompleted: hrvManager.hrvOnboardingCompleted,
            isAuthorized: hrvManager.isAuthorized,
            hrv: hrvManager.readiness,
            bodyStatus: hrvManager.bodyStatus,
            baselines: hrvManager.personalBaselines,
            age: profile.age
        )
        // 复用 BodyRadarLLM 的 user 内容编码(只取前 80 行避免太长)
        let raw = BodyRadarLLM.makePrompt(ctx).messages.first?.content
            ?? "## 身体状态\n(编码失败)\n"
        return "## 身体状态\n" + raw + "\n"
    }

    /// 抓取 `grades` 类数据(最近 10 次成绩 / 即将考试 / 单科预测)
    func fetchGrades() -> String {
        var out = "## 成绩\n"
        let grades = container.gradeRepo.grades
        if grades.isEmpty {
            out += "(暂无成绩记录)\n"
        } else {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            let recent = grades
                .sorted { $0.date > $1.date }
                .prefix(10)
            out += "最近 10 次成绩:\n"
            for g in recent {
                let full = g.fullScore.map { "/\(Int($0.rounded()))" } ?? ""
                out += "  - \(f.string(from: g.date))  \(g.subject): \(Int(g.score.rounded()))\(full)  \(g.examName)\n"
            }
        }
        // 即将到来的考试
        let now = Date()
        let upcoming = container.examRepo.filteredExamSets
            .filter { $0.examDate >= now }
            .sorted { $0.examDate < $1.examDate }
            .prefix(5)
        if !upcoming.isEmpty {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            out += "\n即将到来的考试(最近 5 个):\n"
            for e in upcoming {
                let days = max(0, Calendar.current.dateComponents([.day], from: now, to: e.examDate).day ?? 0)
                out += "  - \(f.string(from: e.examDate))(还有 \(days) 天)  \(e.subject): \(e.name)\n"
            }
        }
        // 学科平均
        let bySubject = Dictionary(grouping: grades, by: \.subject)
        if !bySubject.isEmpty {
            out += "\n各科平均(全部历史):\n"
            for (subj, gs) in bySubject.sorted(by: { $0.key < $1.key }) {
                let avg = gs.map(\.score).reduce(0, +) / Double(gs.count)
                out += "  - \(subj): 平均 \(String(format: "%.1f", avg)) (n=\(gs.count))\n"
            }
        }
        return out
    }

    /// 抓取 `trends` 类数据(本周 / 本月 周报摘要)。
    /// 包含周报/月报 + 本地自动趋势分析摘要。
    /// Fetch `trends` data: weekly + monthly report summaries, plus the
    /// local auto-trend text summary.
    func fetchTrends() -> String {
        var out = "## 趋势\n"
        let now = Date()
        let sessions = container.studySessionRepo.sessions
        let grades = container.gradeRepo.grades
        let mistakes = container.mistakeRepo.mistakeSets
        let exams = container.examRepo.filteredExamSets
        let subjects = container.subjectRepo.subjects

        func render(_ data: WeeklyReportManager.ReportData, periodLabel: String) -> String {
            var s = "### \(periodLabel)\n"
            s += "  - 总学习时长:\(data.totalStudyMinutes) 分钟\n"
            s += "  - 完成 Session:\(data.sessionCount) 个\n"
            s += "  - 平均 Session 时长:\(Int(data.averageSessionMinutes.rounded())) 分钟\n"
            s += "  - 成绩记录:\(data.gradeCount) 条(平均得分率 \(String(format: "%.0f%%", data.averageScoreRate * 100)))\n"
            s += "  - 错题新增:\(data.mistakeCount) 条\n"
            s += "  - 考试:\(data.examCount) 场\n"
            if !data.subjectDistribution.isEmpty {
                s += "  - 学科错题分布:\n"
                for entry in data.subjectDistribution.sorted(by: { $0.percentage > $1.percentage }) {
                    s += "    - \(entry.subject): \(entry.mistakeCount) 条(\(String(format: "%.0f%%", entry.percentage * 100)))\n"
                }
            }
            if !data.intensityDistribution.isEmpty {
                let summary = data.intensityDistribution
                    .map { "\($0.intensity.rawValue):\($0.count)" }
                    .joined(separator: ", ")
                s += "  - 强度分布:\(summary)\n"
            }
            if let top = data.topSubject {
                s += "  - 最佳学科:\(top)\n"
            }
            if let weak = data.weakestSubject {
                s += "  - 待加强学科:\(weak)\n"
            }
            return s
        }

        // 周报(过去 7 天)— 含日记情绪维度,让 HomeAsk 趋势摘要感知心情/精力
        // Weekly summary (past 7 days) — includes diary mood dimension so
        // HomeAsk trend summary is aware of mood / energy signals.
        let weekData = WeeklyReportManager.aggregateData(
            period: .weekly,
            sessions: sessions,
            grades: grades,
            mistakes: mistakes,
            exams: exams,
            subjects: subjects,
            diaryEntries: container.diaryRepo.diaryEntries,
            now: now
        )
        out += render(weekData, periodLabel: "本周(过去 7 天)")

        // 月报(过去 30 天)— 同步含日记情绪维度
        // Monthly summary (past 30 days) — also includes diary mood dimension.
        let monthData = WeeklyReportManager.aggregateData(
            period: .monthly,
            sessions: sessions,
            grades: grades,
            mistakes: mistakes,
            exams: exams,
            subjects: subjects,
            diaryEntries: container.diaryRepo.diaryEntries,
            now: now
        )
        out += "\n" + render(monthData, periodLabel: "本月(过去 30 天)")

        // 本地算法生成的趋势摘要
        out += "\n### 自动趋势分析(本地)\n"
        out += WeeklyReportManager.generateSummary(data: weekData, profile: profile)
        return out
    }

    /// 抓取 `review` 类数据(错题 / 待复习闪卡)。
    /// 包括错题统计、按学科分布、待加强题 + SRS 今日/未来 7 天待复习数。
    /// Fetch `review` data: mistake counts, per-subject distribution, weak
    /// items (<60% mastery), and SRS today/7-day due counts.
    func fetchReview() -> String {
        var out = "## 复习\n"
        let mistakes = container.mistakeRepo.mistakeSets
        if mistakes.isEmpty {
            out += "(暂无错题)\n"
        } else {
            out += "错题总数:\(mistakes.count)\n"
            let ctx = MistakeContext.build(from: mistakes)
            out += "  - 已复习错题数:\(ctx.reviewedMistakeCount)\n"
            out += "  - 平均掌握度:\(String(format: "%.0f%%", ctx.averageMastery * 100))\n"
            out += "  - 总曝光次数:\(ctx.totalExposureCount)\n"
            // 按学科分组
            let bySubject = Dictionary(grouping: mistakes, by: \.subject)
            out += "\n各科错题数:\n"
            for (subj, list) in bySubject.sorted(by: { $0.key < $1.key }) {
                out += "  - \(subj.isEmpty ? "(无学科)" : subj): \(list.count) 题\n"
            }
            // 待复习(掌握度 < 0.6 或 最近复习 > 7 天)
            let due = mistakes.filter { note in
                note.masteryScore < 0.6
            }
            if !due.isEmpty {
                out += "\n待加强错题(掌握度 < 60%):\n"
                for note in due.prefix(5) {
                    out += "  - [\(note.subject)] \(note.title)(掌握度 \(String(format: "%.0f%%", note.masteryScore * 100)))\n"
                }
            }
        }

        // SRS 待复习
        let srs = SRSAlgorithm.overview(from: mistakes)
        out += "\n闪卡(SRS)状态:\n"
        out += "  - 今日待复习:\(srs.dueCount)\n"
        out += "  - 未来 7 天待复习:\(srs.upcomingCount)\n"
        return out
    }

    // MARK: - 路由抓取主入口 / Router-driven fetch entry
    // MARK: - 路由抓取主入口

    /// 按路由结果抓取所有选中类别的数据。
    /// - Returns: 每个类别的 Markdown 片段(按 body / grades / trends / review 顺序)。
    /// Fetch every selected category in router order.
    /// - Returns: One Markdown section per category, in the order the router selected.
    func fetch(categories: [HomeAskRouterLLM.Category]) -> [String] {
        var sections: [String] = []
        for cat in categories {
            let block: String
            // switch 派发:把 category 枚举映射到对应的 fetchXxx()
            // Dispatch: route each category to its corresponding fetcher.
            switch cat {
            case .body:   block = fetchBody()
            case .grades: block = fetchGrades()
            case .trends: block = fetchTrends()
            case .review: block = fetchReview()
            }
            sections.append(block)
        }
        return sections
    }
}
