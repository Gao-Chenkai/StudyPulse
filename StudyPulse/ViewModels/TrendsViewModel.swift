//
//  TrendsViewModel.swift
//  StudyPulse
//
//  趋势页 ViewModel。负责按 subject 分组 + 排序 + 关注科目识别。
// 抽取自 TrendsView.recomputeAll() 及其 SubjectDetailView 的 computed properties。
//
//  Created for MVVM refactor (2026-07-05).
//  Updated for Repository pattern (2026-07-05).
//

import Foundation
import Combine

@MainActor
final class TrendsViewModel: ObservableObject {

    // MARK: - Dependencies

    private let container: RepositoryContainer

    // MARK: - Output State

    /// 按 subject 分组,每组按日期升序
    @Published private(set) var gradesBySubject: [String: [Grade]] = [:]
    /// 启用的 + 有成绩的科目
    @Published private(set) var activeSubjects: [String] = []
    /// 需要关注的科目(平均分 < 70 或近期下滑 > 15)
    @Published private(set) var subjectsNeedingAttention: [String] = []

    // MARK: - Init

    init(container: RepositoryContainer) {
        self.container = container
    }

    static func makeDefault(container: RepositoryContainer) -> TrendsViewModel {
        TrendsViewModel(container: container)
    }

    // MARK: - 业务方法

    /// 集中重算 3 个缓存。View 在 onAppear / grades 变化时调用。
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

        // 3. 需要关注:平均分 < 70 或最近 3 次下滑 > 15
        var needAttention: [String] = []
        for subject in activeSubjects {
            guard let arr = sorted[subject], arr.count >= 2 else { continue }
            let recent = Array(arr.suffix(3))
            let avg = recent.reduce(0.0) { $0 + $1.score } / Double(recent.count)
            if avg < 70 {
                needAttention.append(subject)
                continue
            }
            if recent.count >= 2 {
                guard let first = recent.first?.score, let last = recent.last?.score else { continue }
                if last < first - 15 {
                    needAttention.append(subject)
                }
            }
        }
        subjectsNeedingAttention = needAttention
    }

    // MARK: - 业务方法:SubjectDetailView 用的派生数据

    /// 给定 subject 列表,过滤 + 排序
    func gradesForSubject(_ subject: String) -> [Grade] {
        gradesBySubject[subject] ?? []
    }

    func latestGrade(for subject: String) -> Grade? {
        gradesBySubject[subject]?.last
    }

    func gradeHistory(for subject: String) -> [Grade] {
        gradesBySubject[subject] ?? []
    }

    // MARK: - 业务方法:SubjectDetailView 的统计

    /// 平均分(空返回 0)
    func averageScore(for grades: [Grade]) -> Double {
        guard !grades.isEmpty else { return 0 }
        return grades.map { $0.score }.reduce(0, +) / Double(grades.count)
    }

    /// 平均排名(无效排名不参与计算,空返回 0)
    func averageRank(for grades: [Grade]) -> Int {
        let valid = grades.filter { ($0.ranking ?? 0) > 0 }
        guard !valid.isEmpty else { return 0 }
        let sum = valid.compactMap { $0.ranking }.reduce(0, +)
        return sum / valid.count
    }
}
