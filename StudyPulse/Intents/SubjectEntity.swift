import AppIntents
import Foundation

/// AppEntity wrapping a Subject so Shortcuts can present a pickable
/// subject list keyed on the internal `Subject.name` identifier.
struct SubjectEntity: AppEntity {

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Subject"

    /// Internal subject name (e.g. "Mathematics") — stable identifier.
    var id: String

    /// User-facing display name (e.g. "数学", "Mathematics").
    var displayName: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: displayName))
    }

    static let defaultQuery = SubjectQuery()
}

struct SubjectQuery: EntityStringQuery {

    func entities(for identifiers: [String]) async throws -> [SubjectEntity] {
        let subjects = IntentDataLoader.loadSubjects()
        return identifiers.compactMap { id in
            subjects.first(where: { $0.name == id }).map {
                SubjectEntity(id: $0.name, displayName: $0.displayName)
            }
        }
    }

    func entities(matching query: String) async throws -> [SubjectEntity] {
        let subjects = IntentDataLoader.loadSubjects()
        return subjects
            .filter {
                $0.displayName.localizedCaseInsensitiveContains(query)
                || $0.name.localizedCaseInsensitiveContains(query)
            }
            .map { SubjectEntity(id: $0.name, displayName: $0.displayName) }
    }

    func suggestedEntities() async throws -> [SubjectEntity] {
        let subjects = IntentDataLoader.loadSubjects()
        return subjects
            .filter(\.enabled)
            .map { SubjectEntity(id: $0.name, displayName: $0.displayName) }
    }
}
