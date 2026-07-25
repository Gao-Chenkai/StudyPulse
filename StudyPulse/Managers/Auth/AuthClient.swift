//
//  AuthClient.swift
//  StudyPulse
//
//  Cloud AI 邮箱登录 HTTP 客户端。
//  Cloud AI email-login HTTP client.
//

import Foundation
import os

// MARK: - Auth Error

enum AuthError: Error, LocalizedError {
    case invalidEmail
    case sendCodeFailed(String)
    case verifyFailed(String)
    case logoutFailed(String)
    case network(String)
    case missingWorkerURL

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Please enter a valid email address.".localized()
        case .sendCodeFailed(let msg):
            return String(format: "Failed to send verification code: %@".localized(), msg)
        case .verifyFailed(let msg):
            return String(format: "Verification failed: %@".localized(), msg)
        case .logoutFailed(let msg):
            return String(format: "Logout failed: %@".localized(), msg)
        case .network(let msg):
            return String(format: "Network error: %@".localized(), msg)
        case .missingWorkerURL:
            return "Cloud AI Worker URL not configured.".localized()
        }
    }
}

// MARK: - Auth Response Types

struct AuthSendResponse: Decodable {
    let success: Bool
    let error: String?
}

struct AuthVerifyResponse: Decodable {
    let success: Bool
    let error: String?
    let data: AuthTokenData?
}

struct AuthTokenData: Decodable {
    let token: String
    let membership_type: String?
    let membership_expires_at: String?
}

struct AuthLogoutResponse: Decodable {
    let success: Bool
    let error: String?
}

// MARK: - Profile Response Types

struct ProfileResponse: Decodable {
    let success: Bool
    let error: String?
    let data: ProfileData?
}

struct ProfileData: Decodable {
    let email: String?
    let role: String?
    let membership: MembershipInfo?
    let plan: PlanInfo?
}

struct MembershipInfo: Decodable {
    let type: String?
    let expires_at: String?
    let effective_type: String?
}

struct PlanInfo: Decodable {
    let name: String?
    let daily_request_limit: Int?
    let monthly_token_limit: Int?
    let available_models: [String]?
}

// MARK: - Auth Client

@MainActor
final class AuthClient: @unchecked Sendable {
    static let shared = AuthClient()

    private let session: URLSession
    private let timeoutSeconds: TimeInterval = 30

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public API

    /// 发送验证码到指定邮箱。
    func sendCode(email: String, workerURL: String) async throws {
        guard isValidEmail(email) else { throw AuthError.invalidEmail }
        let url = try buildURL(base: workerURL, path: "/auth/email/send")
        let body = try JSONSerialization.data(withJSONObject: ["email": email])
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = timeoutSeconds

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AuthError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AuthError.network("Non-HTTP response")
        }

        let decoded = try JSONDecoder().decode(AuthSendResponse.self, from: data)
        if http.statusCode == 200, decoded.success {
            return
        }
        let msg = decoded.error ?? "HTTP \(http.statusCode)"
        throw AuthError.sendCodeFailed(msg)
    }

    /// 验证验证码并登录，返回 Session Token 和会员信息。
    func verifyCode(email: String, code: String, workerURL: String) async throws -> (token: String, membershipType: String?, membershipExpiresAt: String?) {
        guard isValidEmail(email) else { throw AuthError.invalidEmail }
        let url = try buildURL(base: workerURL, path: "/auth/email/verify")
        let body = try JSONSerialization.data(withJSONObject: ["email": email, "code": code])
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = timeoutSeconds

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AuthError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AuthError.network("Non-HTTP response")
        }

        let decoded = try JSONDecoder().decode(AuthVerifyResponse.self, from: data)
        if http.statusCode == 200, decoded.success, let token = decoded.data?.token {
            return (token, decoded.data?.membership_type, decoded.data?.membership_expires_at)
        }
        let msg = decoded.error ?? "HTTP \(http.statusCode)"
        throw AuthError.verifyFailed(msg)
    }

    /// 退出登录。
    func logout(sessionToken: String, workerURL: String) async throws {
        let url = try buildURL(base: workerURL, path: "/auth/logout")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = timeoutSeconds

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AuthError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AuthError.network("Non-HTTP response")
        }

        // 服务端即使 token 已失效也返回 200 success，客户端只清本地状态即可
        if http.statusCode == 200 {
            return
        }
        let decoded = (try? JSONDecoder().decode(AuthLogoutResponse.self, from: data))
        let msg = decoded?.error ?? "HTTP \(http.statusCode)"
        throw AuthError.logoutFailed(msg)
    }

    /// 获取当前用户信息和会员状态。
    func getProfile(sessionToken: String, workerURL: String) async throws -> ProfileData {
        let url = try buildURL(base: workerURL, path: "/user/profile")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = timeoutSeconds

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AuthError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AuthError.network("Non-HTTP response")
        }

        let decoded = try JSONDecoder().decode(ProfileResponse.self, from: data)
        if http.statusCode == 200, decoded.success, let profileData = decoded.data {
            return profileData
        }
        let msg = decoded.error ?? "HTTP \(http.statusCode)"
        throw AuthError.network(msg)
    }

    // MARK: - Helpers

    private func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let regex = /^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/
        return trimmed.wholeMatch(of: regex) != nil
    }

    private func buildURL(base: String, path: String) throws -> URL {
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
        let lowered = cleaned.lowercased()
        let normalized: String
        if lowered.hasPrefix("http://") || lowered.hasPrefix("https://") {
            normalized = cleaned
        } else {
            normalized = "https://\(cleaned)"
        }
        guard let url = URL(string: normalized)?.appendingPathComponent(path) else {
            throw AuthError.missingWorkerURL
        }
        return url
    }
}
