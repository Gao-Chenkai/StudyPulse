//
//  StudyPulseSchemaV1.swift
//  StudyPulse
//
//  The first frozen, explicitly versioned SwiftData schema.
//

import SwiftData

/// The schema shipped before explicit SwiftData migrations were introduced.
///
/// Do not add, remove, rename, or otherwise change a model in this list. A
/// persistent-model change must be introduced by a new `VersionedSchema`.
enum StudyPulseSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            SubjectRecord.self,
            GradeRecord.self,
            MistakeNoteRecord.self,
            ExamRecord.self,
            ComprehensiveExamRecord.self,
            TaskItemRecord.self,
            UserProfileRecord.self,
            StudyPhaseRecord.self,
            PlantStateRecord.self,
            RoutineRecord.self,
            RoutineInstanceRecord.self,
            DiaryEntryRecord.self,
            CoachGoalRecord.self,
            CoachAnalysisRecord.self,
            CoachProposalRecord.self,
            CoachConversationMessageRecord.self,
            CoachChatRecord.self,
            StudySessionRecord.self,
            ExamAutopsyRecord.self,
            ExamSimulationRecord.self,
        ]
    }
}
