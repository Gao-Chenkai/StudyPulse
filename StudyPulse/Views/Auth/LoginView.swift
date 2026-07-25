//
//  LoginView.swift
//  StudyPulse
//
//  Cloud AI 邮箱登录页面。
//  Cloud AI email login page.
//

import SwiftUI

struct LoginView: View {
    @Environment(RepositoryContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    @State private var email: String = ""
    @State private var code: String = ""
    @State private var isSendingCode = false
    @State private var isVerifying = false
    @State private var codeSent = false
    @State private var errorMessage: String?
    @State private var cooldownSeconds = 0

    private let cooldownDuration = 60

    private var workerURL: String {
        container.envManager.preferences.cloudAIWorkerURL ?? "spapi.chenkai.space"
    }

    private var canSendCode: Bool {
        !isSendingCode && cooldownSeconds == 0 && isValidEmail(email) && !workerURL.isEmpty
    }

    private var canVerify: Bool {
        !isVerifying && code.count == 6 && !workerURL.isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                // Header
                Section {
                    VStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(Color.teal.opacity(0.18))
                            Image(systemName: "envelope.circle.fill")
                                .font(.system(size: 56, weight: .regular))
                                .foregroundColor(.teal)
                        }
                        .frame(width: 110, height: 110)

                        Text("Cloud AI Login".localized())
                            .font(.system(size: 22, weight: .semibold))

                        Text("Log in to use StudyPulse Cloud AI with your personal account. New users are automatically registered.".localized())
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .listRowBackground(Color.clear)
                }

                // Email input
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                        TextField("Email address".localized(), text: $email)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .disabled(codeSent)
                    }
                } header: {
                    Text("Email".localized())
                }

                // Send code button
                Section {
                    Button {
                        Task { await sendCode() }
                    } label: {
                        HStack {
                            if isSendingCode {
                                ProgressView().scaleEffect(0.8)
                            } else {
                                Image(systemName: "paperplane.fill")
                            }
                            Text(codeSent
                                ? (cooldownSeconds > 0
                                    ? String(format: "Resend in %ds".localized(), cooldownSeconds)
                                    : "Resend Code".localized())
                                : "Send Verification Code".localized())
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSendCode)
                    .tint(.teal)
                }

                // Verification code input
                if codeSent {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.secondary)
                                .frame(width: 20)
                            TextField("Verification code".localized(), text: $code)
                                .keyboardType(.numberPad)
                                .textContentType(.oneTimeCode)
                                .onChange(of: code) { _, newValue in
                                    // Limit to 6 digits
                                    let filtered = newValue.filter { $0.isNumber }
                                    if filtered.count > 6 {
                                        code = String(filtered.prefix(6))
                                    } else if filtered != newValue {
                                        code = filtered
                                    }
                                }
                        }
                    } header: {
                        Text("Verification Code".localized())
                    } footer: {
                        Text("A 6-digit code has been sent to your email. It expires in 10 minutes.".localized())
                    }

                    Section {
                        Button {
                            Task { await verifyCode() }
                        } label: {
                            HStack {
                                if isVerifying {
                                    ProgressView().scaleEffect(0.8)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                }
                                Text("Verify & Login".localized())
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canVerify)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .background(Color(.systemGroupedBackground))
            .containerBackground(.clear, for: .navigation)
            .navigationTitle("Login".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel".localized()) { dismiss() }
                }
            }
            .alert("Error".localized(), isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK".localized(), role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Actions

    @MainActor
    private func sendCode() async {
        errorMessage = nil
        isSendingCode = true
        defer { isSendingCode = false }

        do {
            try await AuthClient.shared.sendCode(email: email, workerURL: workerURL)
            codeSent = true
            code = ""
            startCooldown()
        } catch let error as AuthError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func verifyCode() async {
        errorMessage = nil
        isVerifying = true
        defer { isVerifying = false }

        do {
            let result = try await AuthClient.shared.verifyCode(
                email: email,
                code: code,
                workerURL: workerURL
            )
            try container.envManager.cloudSessionLogin(
                email: email,
                token: result.token,
                membershipType: result.membershipType,
                membershipExpiresAt: result.membershipExpiresAt
            )
            // 自动刷新 profile 以获取可用模型列表
            await container.envManager.refreshCloudProfile()
            dismiss()
        } catch let error as AuthError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startCooldown() {
        cooldownSeconds = cooldownDuration
        Task {
            while cooldownSeconds > 0 {
                try? await Task.sleep(for: .seconds(1))
                cooldownSeconds -= 1
            }
        }
    }

    private func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let regex = /^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/
        return trimmed.wholeMatch(of: regex) != nil
    }
}
