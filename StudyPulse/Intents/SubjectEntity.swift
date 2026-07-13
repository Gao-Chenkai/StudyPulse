import AppIntents
import Foundation

/// AppEntity wrapping a Subject so Shortcuts can present a pickable
/// subject list keyed on the internal `Subject.name` identifier.
/// 把 Subject 包装为 AppEntity,使 Shortcuts 能基于内部 `Subject.name`
/// 标识符呈现可挑选的学科列表。
struct SubjectEntity: AppEntity {

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Subject"

    /// Internal subject name (e.g. "Mathematics") — stable identifier.
    /// 内部学科名(如 "Mathematics")—— 稳定标识符。
    var id: String

    /// User-facing display name (e.g. "数学", "Mathematics").
    /// 面向用户的显示名(如 "数学" / "Mathematics")。
    var displayName: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: displayName))
    }

    static let defaultQuery = SubjectQuery()
}

struct SubjectQuery: EntityStringQuery {

    /// 按 id 列表批量解析(Shortcuts 选中已有项时调用)
    /// Resolve a batch of entities by id (called when Shortcuts pre-selects
    /// existing items).
    func entities(for identifiers: [String]) async throws -> [SubjectEntity] {
        let subjects = IntentDataLoader.loadSubjects()
        return identifiers.compactMap { id in
            subjects.first(where: { $0.name == id }).map {
                SubjectEntity(id: $0.name, displayName: $0.displayName)
            }
        }
    }

    /// 模糊搜索:本地化大小写不敏感地匹配 displayName 或 name
    /// Fuzzy search: case-insensitive substring match on either
    /// `displayName` or `name`.
    func entities(matching query: String) async throws -> [SubjectEntity] {
        let subjects = IntentDataLoader.loadSubjects()
        return subjects
            .filter {
                $0.displayName.localizedCaseInsensitiveContains(query)
                || $0.name.localizedCaseInsensitiveContains(query)
            }
            .map { SubjectEntity(id: $0.name, displayName: $0.displayName) }
    }

    /// Shortcuts 列表里默认显示的"建议项":只展示启用的学科
    /// Default suggestions shown in the Shortcuts picker: only enabled subjects.
    func suggestedEntities() async throws -> [SubjectEntity] {
        let subjects = IntentDataLoader.loadSubjects()
        return subjects
            .filter(\.enabled)
            .map { SubjectEntity(id: $0.name, displayName: $0.displayName) }
    }
}
