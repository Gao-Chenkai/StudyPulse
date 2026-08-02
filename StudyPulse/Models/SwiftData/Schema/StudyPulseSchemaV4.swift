//
//  StudyPulseSchemaV4.swift
//  StudyPulse
//

import SwiftData

/// Additive schema for long-term time-investment projects and rewards.
enum StudyPulseSchemaV4: VersionedSchema {
    static let versionIdentifier = Schema.Version(4, 0, 0)

    static var models: [any PersistentModel.Type] {
        StudyPulseSchemaV3.models + [
            TimeInvestmentSubjectRecord.self,
            SubTaskRecord.self,
            GoalRewardRecord.self,
        ]
    }
}
