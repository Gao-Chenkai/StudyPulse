//
//  ExamViewModel.swift
//  StudyPulse
//
//  Created by Antigravity on 2026/7/12.
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class ExamViewModel: ObservableObject {
    // MARK: - Dependencies
    private let container: RepositoryContainer

    // MARK: - UI States
    @Published var showingNewExamSet = false
    @Published var selectedExamForDetail: Exam? = nil
    @Published var selectedComprehensiveExam: comprehensiveExam? = nil
    @Published var showingPastExams = false
    @Published var viewMode: ExamViewMode = ExamViewMode.loadFromDefaults()
    @Published var predictionTarget: PredictionTarget? = nil
    @Published var comprehensivePredictionTarget: ComprehensivePredictionTarget? = nil

    // MARK: - Output States
    @Published private(set) var allItems: [ExamItem] = []
    @Published private(set) var upcomingItems: [ExamItem] = []
    @Published private(set) var pastItems: [ExamItem] = []
    @Published private(set) var groupedUpcoming: [ExamBucket] = []

    // MARK: - Init
    init(container: RepositoryContainer) {
        self.container = container
    }

    static func makeDefault(container: RepositoryContainer) -> ExamViewModel {
        ExamViewModel(container: container)
    }

    // MARK: - Computed Properties
    var showsCalendar: Bool {
        viewMode == .calendar
    }

    var allExamsSorted: [Any] {
        allItems.map { item -> Any in
            switch item {
            case .single(let e): return e
            case .comprehensive(let e): return e
            }
        }
    }

    var upcomingExams: [Any] {
        upcomingItems.map { item -> Any in
            switch item {
            case .single(let e): return e
            case .comprehensive(let e): return e
            }
        }
    }

    var pastExams: [Any] {
        pastItems.map { item -> Any in
            switch item {
            case .single(let e): return e
            case .comprehensive(let e): return e
            }
        }
    }

    var groupedExams: [(sectionTitle: String, exams: [Any])] {
        groupedUpcoming.map { bucket in
            (bucket.title, bucket.items.map { item -> Any in
                switch item {
                case .single(let e): return e
                case .comprehensive(let e): return e
                }
            })
        }
    }

    // MARK: - Actions
    func recompute() {
        let merged = ExamFilter.mergeAndSort(
            single: container.examRepo.filteredExamSets,
            comprehensive: container.examRepo.filteredComprehensiveExamSets
        )
        allItems = merged
        upcomingItems = ExamFilter.upcomingItems(from: merged)
        pastItems = ExamFilter.pastItems(from: merged)
        groupedUpcoming = ExamFilter.bucketUpcomingItems(from: merged)
    }

    func deleteExam(_ exam: Exam) {
        container.deleteExam(exam)
        recompute()
    }

    func deleteComprehensiveExam(_ exam: comprehensiveExam) {
        container.deleteComprehensiveExam(exam)
        recompute()
    }

    func toggleViewMode() {
        if viewMode == .list {
            viewMode = .calendar
        } else {
            viewMode = .list
        }
        viewMode.saveToDefaults()
    }

    func openPrediction(for exam: Exam) {
        let subjectGrades = container.gradeRepo.filteredGrades
            .filter { $0.subject == exam.subject }
        let fullScore = container.subjectRepo.subjects.first(where: { $0.name == exam.subject })?.fullScore ?? 100
        predictionTarget = PredictionTarget(
            exam: exam,
            history: subjectGrades,
            fullScore: fullScore
        )
    }

    func openPrediction(for exam: comprehensiveExam) {
        let predictor = ScorePredictorFactory.active
        let allSubjects = exam.subject
        var perSubject: [PerSubjectPrediction] = []
        var totalFull: Double = 0
        var totalPredicted: Double = 0
        var totalLower: Double = 0
        var totalUpper: Double = 0

        for subject in allSubjects {
            let grades = container.gradeRepo.filteredGrades.filter { $0.subject == subject }
            let mistakes = container.mistakeRepo.filteredMistakeSets.filter { $0.subject == subject }
            let context = MistakeContext.build(from: mistakes)
            let fullScore = container.subjectRepo.subjects.first(where: { $0.name == subject })?.fullScore ?? 100
            if let r = predictor.predict(history: grades, mistakeContext: context, examDate: exam.examDate, fullScore: fullScore) {
                perSubject.append(PerSubjectPrediction(subject: subject, result: r))
                totalFull += fullScore
                totalPredicted += r.predicted
                totalLower += r.lowerBound
                totalUpper += r.upperBound
            }
        }
        guard !perSubject.isEmpty else { return }
        comprehensivePredictionTarget = ComprehensivePredictionTarget(
            exam: exam,
            perSubject: perSubject,
            totalFull: totalFull,
            totalPredicted: totalPredicted,
            totalLower: totalLower,
            totalUpper: totalUpper
        )
    }
}
