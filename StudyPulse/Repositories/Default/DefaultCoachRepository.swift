import Foundation
import SwiftData

@Observable @MainActor
final class DefaultCoachRepository: CoachRepository {
    private(set) var goals: [CoachGoal] = []
    private(set) var analyses: [CoachAnalysis] = []
    private(set) var proposals: [CoachProposal] = []
    private(set) var chats: [CoachChat] = []
    private(set) var messages: [CoachConversationMessage] = []
    private var context: ModelContext?

    func loadAll(context: ModelContext) async {
        self.context = context
        goals = (try? context.fetch(FetchDescriptor<CoachGoalRecord>()))?.compactMap { $0.toSnapshot() } ?? []
        analyses = (try? context.fetch(FetchDescriptor<CoachAnalysisRecord>(sortBy: [SortDescriptor(\.calculatedAt, order: .reverse)])))?.compactMap { $0.toSnapshot() } ?? []
        proposals = (try? context.fetch(FetchDescriptor<CoachProposalRecord>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])))?.compactMap { $0.toSnapshot() } ?? []
        messages = (try? context.fetch(FetchDescriptor<CoachConversationMessageRecord>(sortBy: [SortDescriptor(\.createdAt)])))?.compactMap { $0.toSnapshot() } ?? []
        chats = (try? context.fetch(FetchDescriptor<CoachChatRecord>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])))?.compactMap { $0.toSnapshot() } ?? []
        migrateLegacyMessagesToChats()
    }

    func addGoal(_ goal: CoachGoal) {
        guard !goals.contains(where: { $0.id == goal.id }) else { return }
        context?.insert(CoachGoalRecord(from: goal)); try? context?.save(); goals.append(goal)
    }

    func updateGoal(_ goal: CoachGoal) {
        if let i = goals.firstIndex(where: { $0.id == goal.id }) { goals[i] = goal }
        if let context, let record = (try? context.fetch(FetchDescriptor<CoachGoalRecord>()))?.first(where: { $0.id == goal.id }) {
            record.payload = (try? JSONEncoder().encode(goal)) ?? Data(); record.updatedAt = goal.updatedAt
            try? context.save()
        }
    }

    func deleteGoal(_ goal: CoachGoal) {
        chats(for: goal.id).forEach(deleteChat)
        deleteMessages(for: goal.id)
        if let context, let record = (try? context.fetch(FetchDescriptor<CoachGoalRecord>()))?.first(where: { $0.id == goal.id }) { context.delete(record); try? context.save() }
        goals.removeAll { $0.id == goal.id }
    }

    func chats(for goalID: UUID) -> [CoachChat] {
        chats.filter { $0.goalID == goalID }.sorted { $0.updatedAt > $1.updatedAt }
    }

    func standaloneChats() -> [CoachChat] {
        chats.filter { $0.goalID == nil }.sorted { $0.updatedAt > $1.updatedAt }
    }

    func addChat(_ chat: CoachChat) {
        guard !chats.contains(where: { $0.id == chat.id }) else { return }
        chats.append(chat)
        context?.insert(CoachChatRecord(from: chat)); try? context?.save()
    }

    func updateChat(_ chat: CoachChat) {
        if let index = chats.firstIndex(where: { $0.id == chat.id }) { chats[index] = chat }
        if let context, let record = (try? context.fetch(FetchDescriptor<CoachChatRecord>()))?.first(where: { $0.id == chat.id }) {
            record.payload = (try? JSONEncoder().encode(chat)) ?? Data(); record.updatedAt = chat.updatedAt
            try? context.save()
        }
    }

    func deleteChat(_ chat: CoachChat) {
        deleteMessages(forChatID: chat.id)
        if let context, let record = (try? context.fetch(FetchDescriptor<CoachChatRecord>()))?.first(where: { $0.id == chat.id }) {
            context.delete(record); try? context.save()
        }
        chats.removeAll { $0.id == chat.id }
    }

    func saveAnalysis(_ analysis: CoachAnalysis) {
        // Keep every successful run so Coach history can show a trend.
        if let context, let record = (try? context.fetch(FetchDescriptor<CoachAnalysisRecord>()))?.first(where: { $0.id == analysis.id }) {
            record.payload = (try? JSONEncoder().encode(analysis)) ?? Data(); record.calculatedAt = analysis.calculatedAt
        } else { context?.insert(CoachAnalysisRecord(from: analysis)) }
        analyses.removeAll { $0.id == analysis.id }
        try? context?.save(); analyses.insert(analysis, at: 0)
    }

    func saveProposal(_ proposal: CoachProposal) {
        if let i = proposals.firstIndex(where: { $0.id == proposal.id }) { proposals[i] = proposal }
        else { proposals.insert(proposal, at: 0) }
        if let context, let record = (try? context.fetch(FetchDescriptor<CoachProposalRecord>()))?.first(where: { $0.id == proposal.id }) {
            record.payload = (try? JSONEncoder().encode(proposal)) ?? Data(); record.statusRaw = proposal.status.rawValue
        } else { context?.insert(CoachProposalRecord(from: proposal)) }
        try? context?.save()
    }

    func proposal(id: UUID) -> CoachProposal? { proposals.first { $0.id == id } }

    func messages(for goalID: UUID) -> [CoachConversationMessage] {
        messages.filter { $0.goalID == goalID }.sorted { $0.createdAt < $1.createdAt }
    }

    func messages(forChatID chatID: UUID) -> [CoachConversationMessage] {
        messages.filter { $0.chatID == chatID }.sorted { $0.createdAt < $1.createdAt }
    }

    func addMessage(_ message: CoachConversationMessage) {
        guard !messages.contains(where: { $0.id == message.id }) else { return }
        messages.append(message); context?.insert(CoachConversationMessageRecord(from: message)); try? context?.save()
    }

    func updateMessage(_ message: CoachConversationMessage) {
        if let index = messages.firstIndex(where: { $0.id == message.id }) { messages[index] = message }
        if let context, let record = (try? context.fetch(FetchDescriptor<CoachConversationMessageRecord>()))?.first(where: { $0.id == message.id }) {
            record.payload = (try? JSONEncoder().encode(message)) ?? Data(); record.roleRaw = message.role.rawValue
            record.createdAt = message.createdAt; try? context.save()
        }
    }

    func deleteMessages(for goalID: UUID) {
        if let context {
            let records = (try? context.fetch(FetchDescriptor<CoachConversationMessageRecord>()))?.filter { $0.goalID == goalID } ?? []
            records.forEach(context.delete); try? context.save()
        }
        messages.removeAll { $0.goalID == goalID }
    }

    func deleteMessages(forChatID chatID: UUID) {
        if let context {
            let records = (try? context.fetch(FetchDescriptor<CoachConversationMessageRecord>()))?.filter {
                $0.toSnapshot()?.chatID == chatID
            } ?? []
            records.forEach(context.delete); try? context.save()
        }
        messages.removeAll { $0.chatID == chatID }
    }

    private func migrateLegacyMessagesToChats() {
        let legacyGoalIDs = Set(messages.compactMap { message in
            chats.contains(where: { $0.id == message.chatID }) ? nil : message.goalID
        })
        for goalID in legacyGoalIDs {
            let legacy = messages.filter { message in
                message.goalID == goalID && !chats.contains(where: { chat in chat.id == message.chatID })
            }
            guard !legacy.isEmpty else { continue }
            let chat = CoachChat(goalID: goalID, title: "New chat")
            addChat(chat)
            for old in legacy {
                let migrated = CoachConversationMessage(id: old.id, goalID: old.goalID, chatID: chat.id,
                                                        role: old.role, content: old.content,
                                                        createdAt: old.createdAt, isStreaming: old.isStreaming,
                                                        error: old.error, todoSuggestions: old.todoSuggestions)
                if let index = messages.firstIndex(where: { $0.id == old.id }) { messages[index] = migrated }
                if let context, let record = (try? context.fetch(FetchDescriptor<CoachConversationMessageRecord>()))?.first(where: { $0.id == old.id }) {
                    record.payload = (try? JSONEncoder().encode(migrated)) ?? Data()
                }
            }
        }
        try? context?.save()
    }
}
