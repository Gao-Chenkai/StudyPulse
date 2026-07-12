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
//  Created for LLM BYOK integration (2026-07-11).
//

import SwiftUI

struct LLMSettingsView: View {
    @EnvironmentObject private var envManager: AppEnvironmentManager

    @State private var baseURLInput: String = ""
    @State private var apiKeyInput: String = ""
    @State private var modelInput: String = ""
    @State private var appendixInput: String = ""
    @State private var temperature: Double = 0.7
    /// DEBUG 专用:全局覆盖系统 prompt(仅当 debugModeEnabled 时显示)
    @State private var overrideInput: String = ""

    @State private var isTesting = false
    @State private var testAlertMessage: String? = nil
    @State private var testAlertSucceeded: Bool = false

    /// 是否已经保存了 API Key(用于决定显示 SecureField 还是占位文字)
    private var hasSavedAPIKey: Bool {
        !(envManager.preferences.llmAPIKey?.isEmpty ?? true)
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
                    get: { envManager.llmEnabled },
                    set: { envManager.llmEnabled = $0 }
                )) {
                    Label("Enable LLM Features".localized(), systemImage: "brain")
                }
            } footer: {
                Text("When off, every AI feature silently falls back to its local implementation.".localized())
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
                            envManager.setLLMBaseURL(newValue.isEmpty ? nil : newValue)
                        }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("API Key".localized())
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if hasSavedAPIKey {
                        HStack {
                            Text(maskedKey(envManager.preferences.llmAPIKey ?? ""))
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button("Change".localized()) {
                                // 清掉已保存的 key,这样 SecureField 才会重新出现
                                // Clear the saved key so the SecureField reappears.
                                envManager.setLLMAPIKey(nil)
                                apiKeyInput = ""
                            }
                            .font(.caption)
                        }
                    } else {
                        SecureField("sk-...", text: $apiKeyInput)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .onChange(of: apiKeyInput) { _, newValue in
                                envManager.setLLMAPIKey(newValue)
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
                            envManager.setLLMModel(newValue.isEmpty ? nil : newValue)
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
                        envManager.setLLMTemperature(newValue)
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
                            envManager.setLLMSystemPromptAppendix(newValue.isEmpty ? nil : newValue)
                        }
                }
            } header: {
                Text("Advanced".localized())
            } footer: {
                Text("Optional. Appended to the default system prompt for every AI feature.".localized())
            }

            // 3.5) DEBUG 模式专用:全局覆盖系统 prompt
            if envManager.debugModeEnabled {
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
                                envManager.setLLMDebugOverrideSystemPrompt(newValue.isEmpty ? nil : newValue)
                            }
                        if !overrideInput.isEmpty {
                            Button(role: .destructive) {
                                overrideInput = ""
                                envManager.setLLMDebugOverrideSystemPrompt(nil)
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
                .disabled(isTesting || !envManager.llmConfig.isConfigured)
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

    // MARK: - Helpers

    private func syncFromPreferences() {
        let prefs = envManager.preferences
        baseURLInput = prefs.llmBaseURL ?? ""
        modelInput = prefs.llmModel ?? ""
        appendixInput = prefs.llmSystemPromptAppendix ?? ""
        temperature = prefs.llmTemperature
    }

    private func maskedKey(_ key: String) -> String {
        guard key.count > 4 else { return "•" + String(repeating: "•", count: max(key.count, 4)) }
        let suffix = key.suffix(4)
        return "••••••••\(suffix)"
    }

    @MainActor
    private func runTestConnection() async {
        isTesting = true
        defer { isTesting = false }
        do {
            try await LLMClient.shared.testConnection(config: envManager.llmConfig)
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
