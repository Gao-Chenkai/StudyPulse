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

    /// Base URL 输入(临时,onChange 即写回 envManager)
    /// Base URL input (temporary, written back to envManager on change).
    @State private var baseURLInput: String = ""
    /// API Key 输入(临时,onChange 即写回 envManager)
    /// API Key input (temporary, written back to envManager on change).
    @State private var apiKeyInput: String = ""
    /// 模型名输入
    /// Model name input.
    @State private var modelInput: String = ""
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

    /// 是否已经保存了 API Key(用于决定显示 SecureField 还是占位文字)
    /// Whether an API Key is already saved (decides whether to show the
    /// SecureField or the masked placeholder).
    private var hasSavedAPIKey: Bool {
        !(container.envManager.preferences.llmAPIKey?.isEmpty ?? true)
    }

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
            } footer: {
                Text("AI Coach is a separate opt-in. It requires the LLM switch and a valid BYOK configuration; it never changes Todo without your confirmation.".localized())
            }

            // 2) 端点配置
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Base URL".localized())
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("https://api.openai.com", text: $baseURLInput, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .keyboardType(.URL)
                        .onChange(of: baseURLInput) { _, newValue in
                            container.envManager.setLLMBaseURL(newValue.isEmpty ? nil : newValue)
                        }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("API Key".localized())
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if hasSavedAPIKey {
                        HStack {
                            Text(maskedKey(container.envManager.preferences.llmAPIKey ?? ""))
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button("Change".localized()) {
                                // 清掉已保存的 key,这样 SecureField 才会重新出现
                                // Clear the saved key so the SecureField reappears.
                                container.envManager.setLLMAPIKey(nil)
                                apiKeyInput = ""
                            }
                            .font(.caption)
                        }
                    } else {
                        SecureField("sk-...", text: $apiKeyInput)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .onChange(of: apiKeyInput) { _, newValue in
                                container.envManager.setLLMAPIKey(newValue)
                            }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Model".localized())
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("gpt-4o-mini", text: $modelInput, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .onChange(of: modelInput) { _, newValue in
                            container.envManager.setLLMModel(newValue.isEmpty ? nil : newValue)
                        }
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
                Text("Provider".localized())
            } footer: {
                Text("StudyPulse never proxies your requests. The endpoint receives your API key directly.".localized())
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
        baseURLInput = prefs.llmBaseURL ?? ""
        modelInput = prefs.llmModel ?? ""
        appendixInput = prefs.llmSystemPromptAppendix ?? ""
        temperature = prefs.llmTemperature
        radarCooldownMinutes = prefs.radarAICooldownMinutes
    }

    /// 把 API Key 脱敏:保留末 4 位
    /// Mask the API key: keep the last 4 characters.
    private func maskedKey(_ key: String) -> String {
        guard key.count > 4 else { return "•" + String(repeating: "•", count: max(key.count, 4)) }
        let suffix = key.suffix(4)
        return "••••••••\(suffix)"
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
}
