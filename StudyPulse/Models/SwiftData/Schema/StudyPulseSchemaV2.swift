//
//  StudyPulseSchemaV2.swift
//  StudyPulse
//
//  Current SwiftData schema.
//

import Foundation
import SwiftData

/// An internal record that makes the first explicit migration a real schema
/// transition while leaving all user-owned entities untouched.
@Model
final class StudyPulseSchemaMetadataRecord {
    @Attribute(.unique) var id: String
    var schemaVersion: Int
    var migratedAt: Date

    init(
        id: String = "primary",
        schemaVersion: Int = 2,
        migratedAt: Date = .now
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.migratedAt = migratedAt
    }
}

/// The current application schema.
enum StudyPulseSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        StudyPulseSchemaV1.models + [StudyPulseSchemaMetadataRecord.self]
    }
}
