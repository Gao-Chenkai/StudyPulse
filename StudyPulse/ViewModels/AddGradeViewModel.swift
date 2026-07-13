//
//  AddGradeViewModel.swift
//  StudyPulse
//
//  Created by Antigravity on 2026/7/12.
//
//  新增成绩 ViewModel。负责单科/综合考试的成绩录入 + 保存到 Repository。
//  Add-grade ViewModel. Single/comprehensive exam form + persistence.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class AddGradeViewModel: ObservableObject {
    // MARK: - 依赖项 / Dependencies
    private let container: RepositoryContainer

    // MARK: - 输入/输出状态 / Input & output state
    /// 考试名称 / Exam name
    @Published var examName: String = ""
    /// 考试日期 / Exam date
    @Published var selectedDate: Date = Date()
    /// 重要性(影响预测权重) / Importance (affects prediction weight)
    @Published var importance: Int = 3
    /// 是否综合考试 / Whether this is a comprehensive exam
    @Published var isComprehensiveExam: Bool = false
    /// 单科考试时选中的科目 / Selected subject (single-subject exam)
    @Published var selectedSingleSubject: String = ""
    /// 综合考试时选中的多个科目 / Selected subjects (comprehensive exam)
    @Published var selectedMultipleSubjects: [String] = []
    /// 各科目的分项成绩 / Per-subject score entries
    @Published var subjectScores: [SubjectScore] = []

    /// 单个科目的成绩条目(支持原分 / 排名)
    /// Per-subject score entry (supports raw-score and ranking).
    struct SubjectScore: Identifiable, Equatable {
        let id: UUID
        let subject: String
        var score: Double
        var useRawScore: Bool
        var useRanking: Bool
        var rawScore: Double
        var ranking: Int?

        init(subject: String, score: Double = 85.0, useRawScore: Bool = false, useRanking: Bool = false, rawScore: Double = 85.0, ranking: Int? = 1) {
            self.id = UUID()
            self.subject = subject
            self.score = score
            self.useRawScore = useRawScore
            self.useRanking = useRanking
            self.rawScore = rawScore
            self.ranking = ranking
        }
    }

    // MARK: - 初始化 / Initialization
    init(container: RepositoryContainer) {
        self.container = container
    }

    /// 从 Siri / 外部入口预填科目与分数
    /// Pre-fills subject & score from Siri / external entry.
    func seedPreset(presetSubject: String, presetScore: Double, presetExamName: String?) {
        self.selectedSingleSubject = presetSubject
        self.examName = presetExamName ?? ""
        self.subjectScores = [
            SubjectScore(subject: presetSubject, score: presetScore)
        ]
    }

    // MARK: - 计算属性 / Computed properties
    /// 启用且非 "GROUP:" 聚合的科目列表
    /// Enabled subjects, excluding "GROUP:" aggregate entries.
    var availableSubjects: [String] {
        container.subjectRepo.subjects.filter {
            $0.enabled && !$0.name.starts(with: "GROUP:")
        }.map { $0.name }
    }

    /// 返回内部科目名的显示名(优先 subject.displayName,否则本地化 name)
    /// Display name for a subject (prefers `displayName`, falls back to localized `name`).
    func displayName(forSubject name: String) -> String {
        if let subject = container.subjectRepo.subjects.first(where: { $0.name == name }) {
            return subject.displayName.isEmpty ? name.localized() : subject.displayName
        }
        return name.localized()
    }

    /// 动态列表高度(60pt 每行) / Dynamic list height (60pt per row)
    var dynamicListHeight: CGFloat {
        CGFloat(availableSubjects.count * 60)
    }

    /// 某科目的满分 / Full-score for a subject
    func fullScore(for subject: String) -> Double {
        container.fullScore(for: subject)
    }

    // MARK: - 操作 / Actions
    /// 切换综合考试多选列表中某科目的选中状态
    /// Toggles a subject's selection in the comprehensive-exam list.
    func toggleSubject(_ subject: String) {
        if selectedMultipleSubjects.contains(subject) {
            selectedMultipleSubjects.removeAll { $0 == subject }
        } else {
            selectedMultipleSubjects.append(subject)
        }
        syncSubjectScores()
    }

    /// 同步 `subjectScores` 与当前选中科目
    /// Reconciles `subjectScores` with the current subject selection.
    func syncSubjectScores() {
        let selected = isComprehensiveExam ? selectedMultipleSubjects : [selectedSingleSubject]
        let existing = subjectScores.map { $0.subject }

        // 新选中的科目 → 默认分数 85 / Newly selected → default score 85.
        for sub in selected where !existing.contains(sub) {
            subjectScores.append(SubjectScore(subject: sub))
        }

        // 取消选中的科目 → 移除 / Dropped subjects → remove.
        subjectScores.removeAll { !selected.contains($0.subject) }
    }

    /// 把 `subjectScores` 转成 `Grade` 模型,保存到 Repository
    /// Converts `subjectScores` into `Grade` models and persists them.
    func saveGrades() {
        let newGrades: [Grade] = subjectScores.map { subjectScore in
            var grade = Grade(
                subject: subjectScore.subject,
                score: subjectScore.score,
                rawScore: subjectScore.useRawScore ? subjectScore.rawScore : nil,
                ranking: subjectScore.useRanking ? subjectScore.ranking : nil,
                importance: importance,
                date: selectedDate,
                examName: examName
            )
            // 记录此次成绩对应的满分
            // Record the full-score for this entry.
            grade.fullScore = container.fullScore(for: subjectScore.subject)
            return grade
        }
        container.addGrades(newGrades)
    }
}
