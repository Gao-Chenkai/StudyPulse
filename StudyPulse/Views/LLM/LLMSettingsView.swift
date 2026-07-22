//
//  LLMSettingsView.swift
//  StudyPulse
//
//  Settings → LLM 配置页:
//  - 启用开关
//  - Base URL / API Key / Model 输入
//  - Temperature 滑杆
//  - 自定义 System Prompt 追加
//  - "Test Connection" 按钮
//
//  Settings → LLM configuration page:
//  - Enable toggle
//  - Base URL / API Key / Model inputs
//  - Temperature slider
//  - Custom System Prompt appendix
//  - "Test Connection" button
//

import SwiftUI

/// Settings → LLM 配置页:Byok(自带 Key) 模式下的端点 / 鉴权 / 模型 / Prompt 设置。
/// Settings → LLM configuration page: endpoint / auth / model / prompt
/// settings for the BYOK (bring-your-own-key) mode.
struct LLMSettingsView: View {
    @Environment(RepositoryContainer.self) private var container

    /// System Prompt 追加段
    /// System prompt appendix.
    @State private var appendixInput: String = ""
    /// Temperature(0...2,默认 0.7)
    /// Temperature (0...2, default 0.7).
    @State private var temperature: Double = 0.7
    /// Recovery Radar cooldown in minutes (default 40).
    @State private var radarCooldownMinutes: Int = 40
    /// DEBUG 专用:全局覆盖系统 prompt(仅当 debugModeEnabled 时显示)
    /// DEBUG-only: global system-prompt override (only shown in DEBUG mode).
    @State private var overrideInput: String = ""

    /// 是否正在测试连接
    /// Whether a test-connection request is in flight.
    @State private var isTesting = false
    /// 测试结果 alert 文本
    /// Test-result alert text.
    @State private var testAlertMessage: String? = nil
    /// 最近一次测试是否成功(决定 alert 标题)
    /// Whether the most recent test succeeded (drives the alert title).
    @State private var testAlertSucceeded: Bool = false
    /// Whether a user-triggered Coach refresh is currently calling the configured LLM.
    @State private var isForceRefreshingCoach = false

    var body: some View {
        List {
            Section {
                SettingsDetailHeader(category: .llm)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            // 1) 总开关
            Section {
                Toggle(isOn: Binding(
                    get: { container.envManager.llmEnabled },
                    set: { container.envManager.llmEnabled = $0 }
                )) {
                    Label("Enable LLM Features".localized(), systemImage: "brain")
                }
                Toggle(isOn: Binding(
                    get: { container.envManager.preferences.coachEnabled },
                    set: { container.envManager.preferences.coachEnabled = $0 }
                )) {
                    Label("Enable AI Coach".localized(), systemImage: "brain.head.profile")
                }
                Toggle(isOn: Binding(
                    get: { container.envManager.preferences.coachAdaptivePlanEnabled },
                    set: { container.envManager.preferences.coachAdaptivePlanEnabled = $0 }
                )) {
                    Label("Adapt Coach plan for major health changes".localized(), systemImage: "heart.text.square")
                }
                Toggle(isOn: Binding(
                    get: { container.envManager.preferences.coachNotificationEnabled },
                    set: { container.envManager.preferences.coachNotificationEnabled = $0; CoachNotifications.shared.reschedule(enabled: $0, hour: container.envManager.preferences.coachNotificationHour) }
                )) {
                    Label("Daily Coach Notification".localized(), systemImage: "bell.badge")
                }
                Stepper(value: Binding(
                    get: { container.envManager.preferences.coachNotificationHour },
                    set: { container.envManager.preferences.coachNotificationHour = max(0, min(23, $0)); CoachNotifications.shared.reschedule(enabled: container.envManager.preferences.coachNotificationEnabled, hour: $0) }
                ), in: 0...23) {
                    Text(String(format: "Coach notification hour: %02d:00".localized(), container.envManager.preferences.coachNotificationHour))
                }
                Button {
                    Task { await forceRefreshCoach() }
                } label: {
                    HStack {
                        if isForceRefreshingCoach {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise.circle.fill")
                        }
                        Text("Force AI Coach Refresh".localized())
                    }
                }
                .disabled(isForceRefreshingCoach || !container.envManager.preferences.coachEnabled || !container.envManager.llmConfig.isConfigured)
            } footer: {
                Text("AI Coach is a separate opt-in. Major health changes are judged on-device; only then is a proposed plan generated through your configured LLM. Force refresh replaces any pending proposal, but it never changes Todo without your confirmation.".localized())
            }

            // 2) 供应商配置
            Section {
                if container.envManager.preferences.llmProviders.isEmpty {
                    ContentUnavailableView("No provider configured".localized(), systemImage: "server.rack")
                }
                ForEach(container.envManager.preferences.llmProviders) { provider in
                    HStack(spacing: 12) {
                        Button {
                            container.envManager.selectLLMProvider(provider.id)
                        } label: {
                            Image(systemName: provider.id == container.envManager.preferences.activeLLMProviderId ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(provider.id == container.envManager.preferences.activeLLMProviderId ? .accentColor : .secondary)
                        }
                        .buttonStyle(.plain)
                        NavigationLink(destination: LLMProviderEditor(provider: provider)) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(provider.name.isEmpty ? "Unnamed Provider".localized() : provider.name)
                                Text(provider.isConfigured ? provider.model : "Incomplete configuration".localized())
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) { container.envManager.deleteLLMProvider(provider.id) } label: {
                            Label("Delete".localized(), systemImage: "trash")
                        }
                    }
                }
                Button { container.envManager.addLLMProvider() } label: {
                    Label("Add Provider".localized(), systemImage: "plus.circle.fill")
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Temperature".localized())
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.1f", temperature))
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $temperature, in: 0...2, step: 0.1) {
                        Text("Temperature")
                    }
                    .onChange(of: temperature) { _, newValue in
                        container.envManager.setLLMTemperature(newValue)
                    }
                }
            } header: {
                Text("Providers".localized())
            } footer: {
                Text("Add multiple OpenAI-compatible providers, then tap one to make it active. StudyPulse never proxies your requests; the active provider receives your API key directly.".localized())
            }

            // 3) System Prompt 追加
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("System Prompt Appendix".localized())
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextEditor(text: $appendixInput)
                        .frame(minHeight: 100)
                        .onChange(of: appendixInput) { _, newValue in
                            container.envManager.setLLMSystemPromptAppendix(newValue.isEmpty ? nil : newValue)
                        }
                }
            } header: {
                Text("Advanced".localized())
            } footer: {
                Text("Optional. Appended to the default system prompt for every AI feature.".localized())
            }

            // 3.5) 恢复雷达 LLM 冷却时间
            Section {
                Stepper(value: $radarCooldownMinutes, in: 5...180, step: 5) {
                    HStack {
                        Label("Recovery Radar AI Cooldown".localized(), systemImage: "heart.text.square")
                        Spacer()
                        Text(String(format: "%d min".localized(), radarCooldownMinutes))
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }
                .onChange(of: radarCooldownMinutes) { _, newValue in
                    container.envManager.setRadarAICooldownMinutes(newValue)
                }
            } header: {
                Text("AI Rate Limits".localized())
            } footer: {
                Text("Controls how often the Recovery Radar automatically asks the LLM. Analyze now can bypass this cooldown.".localized())
            }

            Section {
                Toggle("Enable Habit Insight".localized(), isOn: Binding(
                    get: { container.envManager.preferences.habitInsightEnabled },
                    set: { container.envManager.setHabitInsightEnabled($0) }
                ))
                Stepper(value: Binding(
                    get: { container.envManager.preferences.habitInsightCooldownMinutes },
                    set: { container.envManager.setHabitInsightCooldownMinutes($0) }
                ), in: 5...180, step: 5) {
                    Text("Habit Insight Cooldown".localized())
                }
            } header: {
                Text("Habit Insight".localized())
            } footer: {
                Text("habitInsight.section.footer".localized())
            }

            Section {
                Toggle("Daily Best-Window Notification".localized(), isOn: Binding(
                    get: { container.envManager.preferences.habitInsightNotificationEnabled },
                    set: { enabled in
                        container.envManager.setHabitInsightNotificationEnabled(enabled)
                        let p = container.envManager.preferences
                        HabitInsightNotifications.shared.reschedule(enabled: enabled, hour: p.habitInsightNotificationHour, body: p.lastHabitInsightNotificationBody)
                    }
                ))
                Stepper(value: Binding(
                    get: { container.envManager.preferences.habitInsightNotificationHour },
                    set: { hour in
                        container.envManager.setHabitInsightNotificationHour(hour)
                        let p = container.envManager.preferences
                        HabitInsightNotifications.shared.reschedule(enabled: p.habitInsightNotificationEnabled, hour: hour, body: p.lastHabitInsightNotificationBody)
                    }
                ), in: 0...23) {
                    Text("Notification Hour".localized())
                }
            } header: {
                Text("Daily Notification".localized())
            }

            // 3.6) DEBUG 模式专用:全局覆盖系统 prompt
            if container.envManager.debugModeEnabled {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "ladybug.fill").foregroundColor(.yellow)
                            Text("DEBUG: Override System Prompt".localized())
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.primary)
                        }
                        TextEditor(text: $overrideInput)
                            .frame(minHeight: 140)
                            .font(.system(.footnote, design: .monospaced))
                            .onChange(of: overrideInput) { _, newValue in
                                container.envManager.setLLMDebugOverrideSystemPrompt(newValue.isEmpty ? nil : newValue)
                            }
                        if !overrideInput.isEmpty {
                            Button(role: .destructive) {
                                overrideInput = ""
                                container.envManager.setLLMDebugOverrideSystemPrompt(nil)
                            } label: {
                                Label("Clear Override".localized(), systemImage: "trash")
                            }
                            .font(.caption)
                        }
                    }
                } header: {
                    HStack {
                        Image(systemName: "ladybug.fill").foregroundColor(.yellow)
                        Text("DEBUG Override".localized())
                    }
                } footer: {
                    Text("当此处有内容时,所有 AI 功能都会**完全使用此 prompt**,跳过默认 + Appendix。\n仅 DEBUG 模式可见,便于排查 prompt 行为。".localized())
                        .font(.caption2)
                }
            }

            // 4) 测试连接
            Section {
                Button {
                    Task { await runTestConnection() }
                } label: {
                    HStack {
                        if isTesting {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                        }
                        Text("Test Connection".localized())
                    }
                }
                .disabled(isTesting || !container.envManager.llmConfig.isConfigured)
            } footer: {
                Text("Sends a minimal request to verify the endpoint, API key and model.".localized())
            }

            // 5) AI Assistant 入口
            Section {
                NavigationLink(destination: LLMChatView()) {
                    Label("AI Assistant".localized(), systemImage: "bubble.left.and.bubble.right.fill")
                }
            } footer: {
                Text("Ask questions about your grades, mistakes, or exams.".localized())
            }
        }
        .listStyle(.insetGrouped)
        .background(Color(.systemGroupedBackground))
        .containerBackground(.clear, for: .navigation)
        .debugModeContainer()
        .debugLayoutBoundsAuto()
        .navigationTitle("LLM".localized())
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { syncFromPreferences() }
        .alert(
            testAlertSucceeded ? "Connection successful".localized() : "Connection failed".localized(),
            isPresented: Binding(
                get: { testAlertMessage != nil },
                set: { if !$0 { testAlertMessage = nil } }
            )
        ) {
            Button("OK".localized(), role: .cancel) { }
        } message: {
            Text(testAlertMessage ?? "")
        }
    }

    // MARK: - Helpers / 辅助方法

    /// 从 `container.envManager.preferences` 拉一份初始值填到本地 @State(只跑一次)
    /// Pull initial values from `container.envManager.preferences` into local @State
    /// (runs once on appear).
    private func syncFromPreferences() {
        let prefs = container.envManager.preferences
        appendixInput = prefs.llmSystemPromptAppendix ?? ""
        temperature = prefs.llmTemperature
        radarCooldownMinutes = prefs.radarAICooldownMinutes
    }

    /// 真正发一次 minimal 请求来验证端点 / Key / 模型
    /// Send a minimal request to verify endpoint / key / model.
    @MainActor
    private func runTestConnection() async {
        isTesting = true
        defer { isTesting = false }
        do {
            try await LLMClient.shared.testConnection(config: container.envManager.llmConfig)
            testAlertSucceeded = true
            testAlertMessage = "Endpoint reachable, model responded.".localized()
        } catch let error as LLMError {
            testAlertSucceeded = false
            testAlertMessage = error.errorDescription
        } catch {
            testAlertSucceeded = false
            testAlertMessage = error.localizedDescription
        }
    }

    @MainActor
    private func forceRefreshCoach() async {
        isForceRefreshingCoach = true
        defer { isForceRefreshingCoach = false }
        do {
            _ = try await CoachCoordinator(container: container).forceRefreshProposal()
            testAlertSucceeded = true
            testAlertMessage = "A fresh AI Coach proposal is ready to review.".localized()
        } catch let error as LocalizedError {
            testAlertSucceeded = false
            testAlertMessage = error.errorDescription ?? error.localizedDescription
        } catch {
            testAlertSucceeded = false
            testAlertMessage = error.localizedDescription
        }
    }
}

private struct LLMProviderEditor: View {
    @Environment(RepositoryContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    let provider: LLMProvider
    @State private var name: String
    @State private var baseURL: String
    @State private var apiKey: String
    @State private var model: String
    @State private var multimodalEnabled: Bool
    @State private var thinkingEnabled: Bool

    init(provider: LLMProvider) {
        self.provider = provider
        _name = State(initialValue: provider.name)
        _baseURL = State(initialValue: provider.baseURL)
        _apiKey = State(initialValue: provider.apiKey)
        _model = State(initialValue: provider.model)
        _multimodalEnabled = State(initialValue: provider.multimodalEnabled)
        _thinkingEnabled = State(initialValue: provider.thinkingEnabled)
    }

    var body: some View {
        Form {
            Section {
                TextField("Provider Name".localized(), text: $name)
                TextField("https://api.openai.com", text: $baseURL, axis: .vertical)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .keyboardType(.URL)
                SecureField("API Key".localized(), text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                TextField("gpt-4o-mini", text: $model)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                Toggle("Enable Multimodal".localized(), isOn: $multimodalEnabled)
                Toggle("Enable Thinking".localized(), isOn: $thinkingEnabled)
            } header: {
                Text("Connection".localized())
            }

            Section {
                Text("Multimodal uses the content-array format for vision-capable models. Thinking uses the provider's thinking parameter when enabled.".localized())
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    container.envManager.selectLLMProvider(provider.id)
                } label: {
                    Label(
                        provider.id == container.envManager.preferences.activeLLMProviderId
                            ? "Active Provider".localized()
                            : "Use This Provider".localized(),
                        systemImage: provider.id == container.envManager.preferences.activeLLMProviderId
                            ? "checkmark.circle.fill" : "checkmark.circle"
                    )
                }
                .disabled(provider.id == container.envManager.preferences.activeLLMProviderId)
            } footer: {
                Text("All AI features use the active provider.".localized())
            }
        }
        .navigationTitle("Provider".localized())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done".localized()) {
                    save()
                    dismiss()
                }
            }
        }
        .onDisappear { save() }
    }

    private func save() {
        container.envManager.updateLLMProvider(
            LLMProvider(
                id: provider.id,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                baseURL: baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
                apiKey: apiKey,
                model: model.trimmingCharacters(in: .whitespacesAndNewlines),
                multimodalEnabled: multimodalEnabled,
                thinkingEnabled: thinkingEnabled
            )
        )
    }
}
