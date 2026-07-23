//
//  StudyPulseMigrationPlan.swift
//  StudyPulse
//

import SwiftData

enum StudyPulseMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [
            StudyPulseSchemaV1.self,
            StudyPulseSchemaV2.self,
        ]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(
                fromVersion: StudyPulseSchemaV1.self,
                toVersion: StudyPulseSchemaV2.self
            ),
        ]
    }
}
