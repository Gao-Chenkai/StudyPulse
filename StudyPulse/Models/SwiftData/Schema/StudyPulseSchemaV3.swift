//
//  StudyPulseSchemaV3.swift
//  StudyPulse
//
//  Additive schema for Exam Reverse Planner payload records.
//

import SwiftData

/// Current schema. V1 and V2 remain frozen so existing on-device stores can
/// migrate through the same version history they were created with.
enum StudyPulseSchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        StudyPulseSchemaV2.models + [
            ExamGoalRecord.self,
            ExamPlanRecord.self,
        ]
    }
}
