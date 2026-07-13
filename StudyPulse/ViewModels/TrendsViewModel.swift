//
//  TrendsViewModel.swift
//  StudyPulse
//
//  趋势页 VM。负责按 subject 分组 + 排序 + 关注科目识别。
//  Trends-page VM. Group by subject, sort, detect subjects needing attention.
//
import Foundation
import Combine

@MainActor
final class TrendsViewModel: ObservableObject {

    // MARK: - 依赖项 / Dependencies
    private let container: RepositoryContainer

    // MARK: - 输出状态 / Output state
    /// 按 subject 分组,每组按日期升序 / Grouped by subject, sorted asc.
    @Published private(set) var gradesBySubject: [String: [Grade]] = [:]
    /// 启用的 + 有成绩的科目 / Enabled subjects that actually have grades.
    @Published private(set) var activeSubjects: [String] = []
    /// 需要关注的科目(平均 < 70 或近期下滑 > 15) / Subjects needing attention.
    @Published private(set) var subjectsNeedingAttention: [String] = []

    // MARK: - 初始化 / Initialization
    init(container: RepositoryContainer) {
        self.container = container
    }

    /// 工厂方法 / Factory.
    static func makeDefault(container: RepositoryContainer) -> TrendsViewModel {
        TrendsViewModel(container: container)
    }

    // MARK: - 业务方法 / Business methods
    /// 集中重算 3 个缓存 / Recompute all 3 caches.
    func recompute() {
        let filteredGrades = container.gradeRepo.filteredGrades
        let subjects = container.subjectRepo.subjects

        // 1. 单次 group by subject + sort
        var groups: [String: [Grade]] = [:]
        for g in filteredGrades {
            groups[g.subject, default: []].append(g)
        }
        var sorted: [String: [Grade]] = [:]
        for (subject, arr) in groups {
            sorted[subject] = arr.sorted { $0.date < $1.date }
        }
        gradesBySubject = sorted

        // 2. 启用的 + 有成绩的科目
        let enabledNames = subjects.filter { $0.enabled }.map { $0.name }
        activeSubjects = enabledNames.filter { !(sorted[$0]?.isEmpty ?? true) }

        // 3. 需要关注:平均 < 70 或最近 3 次下滑 > 15
        // 阈值 70 / 15:低于 70 直接红牌;最近 3 次跌幅 > 15 提示
        var needAttention: [String] = []
        for subject in activeSubjects {
            guard let arr = sorted[subject], arr.count >= 2 else { continue }
            let recent = Array(arr.suffix(3))
            // 平均 < 70 → 关注
            let avg = recent.reduce(0.0) { $0 + $1.score } / Double(recent.count)
            if avg < 70 {
                needAttention.append(subject)
                continue
            }
            if recent.count >= 2 {
                // 最近 vs 最早跌幅 > 15 → 关注
                guard let first = recent.first?.score, let last = recent.last?.score else { continue }
                if last < first - 15 {
                    needAttention.append(subject)
                }
            }
        }
        subjectsNeedingAttention = needAttention
    }

    // MARK: - SubjectDetailView 派生数据 / Derived data for SubjectDetailView
    /// 给定 subject,返回其全部成绩(按时间升序) / All grades for a subject.
    func gradesForSubject(_ subject: String) -> [Grade] {
        gradesBySubject[subject] ?? []
    }

    /// 最近一条成绩 / Latest grade.
    func latestGrade(for subject: String) -> Grade? {
        gradesBySubject[subject]?.last
    }

    /// 完整历史(等同 `gradesForSubject`) / Full history (alias).
    func gradeHistory(for subject: String) -> [Grade] {
        gradesBySubject[subject] ?? []
    }

    // MARK: - SubjectDetailView 统计 / Statistics for SubjectDetailView
    /// 平均分(空返回 0) / Average score (0 when empty).
    func averageScore(for grades: [Grade]) -> Double {
        guard !grades.isEmpty else { return 0 }
        return grades.map { $0.score }.reduce(0, +) / Double(grades.count)
    }

    /// 平均排名(无效排名不参与,空返回 0) / Average rank (ignores invalid ranks).
    func averageRank(for grades: [Grade]) -> Int {
        let valid = grades.filter { ($0.ranking ?? 0) > 0 }
        guard !valid.isEmpty else { return 0 }
        let sum = valid.compactMap { $0.ranking }.reduce(0, +)
        return sum / valid.count
    }
}
