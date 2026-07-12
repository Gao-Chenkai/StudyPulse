//
//  AddGradeViewModel.swift
//  StudyPulse
//
//  Created by Antigravity on 2026/7/12.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class AddGradeViewModel: ObservableObject {
    // MARK: - Dependencies
    private let container: RepositoryContainer

    // MARK: - Input/Output State
    @Published var examName: String = ""
    @Published var selectedDate: Date = Date()
    @Published var importance: Int = 3
    @Published var isComprehensiveExam: Bool = false
    @Published var selectedSingleSubject: String = ""
    @Published var selectedMultipleSubjects: [String] = []
    @Published var subjectScores: [SubjectScore] = []

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

    // MARK: - Init
    init(container: RepositoryContainer) {
        self.container = container
    }

    /// Convenience initializer to seed with Siri-provided values
    func seedPreset(presetSubject: String, presetScore: Double, presetExamName: String?) {
        self.selectedSingleSubject = presetSubject
        self.examName = presetExamName ?? ""
        self.subjectScores = [
            SubjectScore(subject: presetSubject, score: presetScore)
        ]
    }

    // MARK: - Computed Properties / Helpers
    var availableSubjects: [String] {
        container.subjectRepo.subjects.filter {
            $0.enabled && !$0.name.starts(with: "GROUP:")
        }.map { $0.name }
    }

    func displayName(forSubject name: String) -> String {
        if let subject = container.subjectRepo.subjects.first(where: { $0.name == name }) {
            return subject.displayName.isEmpty ? name.localized() : subject.displayName
        }
        return name.localized()
    }

    var dynamicListHeight: CGFloat {
        CGFloat(availableSubjects.count * 60)
    }

    func fullScore(for subject: String) -> Double {
        container.fullScore(for: subject)
    }

    // MARK: - Actions
    func toggleSubject(_ subject: String) {
        if selectedMultipleSubjects.contains(subject) {
            selectedMultipleSubjects.removeAll { $0 == subject }
        } else {
            selectedMultipleSubjects.append(subject)
        }
        syncSubjectScores()
    }

    func syncSubjectScores() {
        let selected = isComprehensiveExam ? selectedMultipleSubjects : [selectedSingleSubject]
        let existing = subjectScores.map { $0.subject }

        for sub in selected where !existing.contains(sub) {
            subjectScores.append(SubjectScore(subject: sub))
        }

        subjectScores.removeAll { !selected.contains($0.subject) }
    }

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
            grade.fullScore = container.fullScore(for: subjectScore.subject)
            return grade
        }
        container.addGrades(newGrades)
    }
}
