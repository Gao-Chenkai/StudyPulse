//
//  HomeAskViewModel.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/7/11.
//
//  主页 AI 提问 sheet 的 ViewModel。
//  实现两阶段流:
//  1) 路由阶段:把用户问题发给 LLM,让 LLM 选出需要的数据类别(body / grades / trends / review)
//  2) 抓取阶段:用 `HomeAskDataProvider` 按类别拉取数据
//  3) 回答阶段:把"用户问题 + 抓到的数据"发给 LLM,流式返回 Markdown 答案
//  多轮对话:每轮都重跑 1→2→3,确保 LLM 看到的是最新数据 + 完整历史
//

import Foundation
import SwiftUI
import Combine
import os

@MainActor
final class HomeAskViewModel: ObservableObject {
    struct Message: Identifiable, Equatable {
        let id: UUID
        let role: LLMRole
        var content: String
        var isStreaming: Bool
        var error: String?
        /// 路由阶段确定的类别(显示为该消息右上角的小标签)
        var routingCategories: [HomeAskRouterLLM.Category] = []
        var routingReasoning: String = ""
        /// 抓取到的数据(完整 Markdown 块,显示在折叠区里供用户查看)
        var dataSnapshot: String = ""

        init(
            id: UUID = UUID(),
            role: LLMRole,
            content: String = "",
            isStreaming: Bool = false,
            error: String? = nil,
            routingCategories: [HomeAskRouterLLM.Category] = [],
            routingReasoning: String = "",
            dataSnapshot: String = ""
        ) {
            self.id = id
            self.role = role
            self.content = content
            self.isStreaming = isStreaming
            self.error = error
            self.routingCategories = routingCategories
            self.routingReasoning = routingReasoning
            self.dataSnapshot = dataSnapshot
        }
    }

    enum Phase: Equatable {
        case idle
        case routing
        case answering
    }

    @Published var messages: [Message] = []
    @Published var phase: Phase = .idle
    @Published var inputText: String = ""
    @Published var dataProvider: HomeAskDataProvider
    let envManager: AppEnvironmentManager
    private var currentTask: Task<Void, Never>? = nil

    init(container: RepositoryContainer, envManager: AppEnvironmentManager) {
        self.envManager = envManager
        self.dataProvider = HomeAskDataProvider(
            container: container,
            hrvManager: HealthKitManager.shared,
            profile: container.profileRepo.profile
        )
    }

    // MARK: - Lifecycle

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }

    func reset() {
        cancel()
        messages.removeAll()
        phase = .idle
    }

    // MARK: - 发送

    /// 发送问题。两阶段:路由 → 抓取 → 流式回答。
    func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              phase == .idle,
              envManager.llmConfig.isConfigured
        else { return }

        // 1) 把用户消息加入历史
        messages.append(Message(role: .user, content: trimmed))
        inputText = ""

        // 2) assistant 占位
        let placeholder = Message(role: .assistant, content: "", isStreaming: true)
        messages.append(placeholder)

        currentTask = Task { [weak self] in
            await self?.runPipeline(userText: trimmed, placeholderId: placeholder.id)
        }
    }

    private func runPipeline(userText: String, placeholderId: UUID) async {
        let config = envManager.llmConfig
        guard config.isConfigured else {
            updateMessage(id: placeholderId) { $0.error = "请先在设置中配置大模型".localized(); $0.isStreaming = false }
            phase = .idle
            return
        }

        // === 阶段 1: 路由 ===
        phase = .routing
        var routing = HomeAskRouterLLM.Routing(
            categories: HomeAskRouterLLM.Category.allCases,
            reasoning: "兜底:全部分类"
        )
        do {
            let routePrompt = HomeAskRouterLLM.makePrompt(question: userText)
            var routeOutput = ""
            _ = try await LLMClient.shared.stream(prompt: routePrompt, config: config) { snapshot in
                routeOutput = snapshot
            }
            routing = HomeAskRouterLLM.parse(routeOutput)
            Log.llm.info("HomeAsk route: \(routing.categories.map(\.rawValue).joined(separator: ","), privacy: .public)")
        } catch is CancellationError {
            updateMessage(id: placeholderId) { $0.isStreaming = false; $0.error = "已取消".localized() }
            phase = .idle
            return
        } catch {
            Log.llm.error("HomeAsk routing failed: \(error.localizedDescription, privacy: .public)")
            // 路由失败 → 默认提供全部分类
        }
        // 把路由结果暂时记到 placeholder
        updateMessage(id: placeholderId) {
            $0.routingCategories = routing.categories
            $0.routingReasoning = routing.reasoning
        }

        // === 阶段 2: 抓取数据 ===
        let dataSections = dataProvider.fetch(categories: routing.categories)
        let dataBlock = dataSections.joined(separator: "\n\n")
        updateMessage(id: placeholderId) { $0.dataSnapshot = dataBlock }

        // === 阶段 3: 流式回答 ===
        phase = .answering
        let answerPrompt = HomeAskAnswerLLM.makePrompt(
            question: userText,
            activeCategories: routing.categories,
            dataSections: dataSections
        )
        do {
            _ = try await LLMClient.shared.stream(prompt: answerPrompt, config: config, caller: "HomeAsk-Answer") { [weak self] snapshot in
                self?.updateMessage(id: placeholderId) { $0.content = snapshot }
            }
            updateMessage(id: placeholderId) { $0.isStreaming = false }
        } catch is CancellationError {
            updateMessage(id: placeholderId) { $0.isStreaming = false; $0.error = "已取消".localized() }
        } catch {
            let desc = (error as? LLMError)?.errorDescription ?? error.localizedDescription
            updateMessage(id: placeholderId) { $0.isStreaming = false; $0.error = desc }
            Log.llm.error("HomeAsk answer failed: \(error.localizedDescription, privacy: .public)")
        }
        phase = .idle
    }

    private func updateMessage(id: UUID, _ mutate: (inout Message) -> Void) {
        guard let idx = messages.firstIndex(where: { $0.id == id }) else { return }
        mutate(&messages[idx])
    }
}
