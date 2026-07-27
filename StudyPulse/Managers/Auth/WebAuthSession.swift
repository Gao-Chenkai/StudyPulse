import AuthenticationServices
import Foundation
import UIKit
import os

enum WebAuthError: Error, LocalizedError, Equatable {
    case cancelled
    case oauthFailed(String)
    case callbackMissing
    case accessTokenMissing
    case refreshTokenMissing
    case invalidCallback

    var errorDescription: String? {
        switch self {
        case .cancelled: return "Login was cancelled."
        case .oauthFailed(let message): return message
        case .callbackMissing: return "The login callback was not received."
        case .accessTokenMissing: return "The login response did not contain an access token."
        case .refreshTokenMissing: return "The login response did not contain a refresh token."
        case .invalidCallback: return "The login callback is invalid."
        }
    }
}

enum WebAuthCallbackParser {
    static func parse(_ url: URL) throws -> AuthTokenPair {
        guard url.scheme == "studypulse", url.host == "auth", url.path == "/callback" else {
            throw WebAuthError.invalidCallback
        }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw WebAuthError.invalidCallback
        }
        var values: [String: String] = [:]
        for item in components.queryItems ?? [] {
            if let value = item.value { values[item.name] = value }
        }
        if let error = values["error"] {
            throw WebAuthError.oauthFailed(values["error_description"] ?? error)
        }
        guard values["access_token"] != nil else { throw WebAuthError.accessTokenMissing }
        guard values["refresh_token"] != nil else { throw WebAuthError.refreshTokenMissing }
        guard let accessToken = values["access_token"], !accessToken.isEmpty else {
            throw WebAuthError.accessTokenMissing
        }
        guard let refreshToken = values["refresh_token"], !refreshToken.isEmpty else {
            throw WebAuthError.refreshTokenMissing
        }
        return AuthTokenPair(accessToken: accessToken, refreshToken: refreshToken)
    }
}

extension Notification.Name {
    static let studyPulseAuthCallbackHandled = Notification.Name("StudyPulse.authCallbackHandled")
}

/// Handles URL-scheme callbacks delivered directly to the application.
///
/// `ASWebAuthenticationSession` normally receives the callback itself, but
/// iOS can also deliver the custom-scheme URL through the scene lifecycle
/// (notably when the app is backgrounded or cold-launched). Keeping this path
/// at the app level makes both cases use the same token persistence logic.
@MainActor
enum AuthCallbackHandler {
    static func handle(_ url: URL, container: RepositoryContainer) async {
        do {
            let pair = try WebAuthCallbackParser.parse(url)
            try container.envManager.cloudSessionLogin(
                accessToken: pair.accessToken,
                refreshToken: pair.refreshToken
            )
            await container.envManager.refreshCloudProfile()
            NotificationCenter.default.post(
                name: .studyPulseAuthCallbackHandled,
                object: pair
            )
            Log.preferences.info("Auth callback handled and tokens saved")
        } catch {
            Log.preferences.error("Auth callback failed: \(error.localizedDescription)")
            NotificationCenter.default.post(
                name: .studyPulseAuthCallbackHandled,
                object: error
            )
        }
    }
}

@MainActor
final class WebAuthSession: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let loginURL = URL(string: "https://auth.chenkai.space/login?return_to=studypulse%3A%2F%2Fauth%2Fcallback")!

    private var session: ASWebAuthenticationSession?

    func authenticate() async throws -> AuthTokenPair {
        try await withCheckedThrowingContinuation { continuation in
            let authSession = ASWebAuthenticationSession(
                url: Self.loginURL,
                callbackURLScheme: "studypulse"
            ) { [weak self] callbackURL, error in
                self?.session = nil
                if let authError = error as? ASWebAuthenticationSessionError,
                   authError.code == .canceledLogin {
                    continuation.resume(throwing: WebAuthError.cancelled)
                    return
                }
                if let error {
                    continuation.resume(throwing: WebAuthError.oauthFailed(error.localizedDescription))
                    return
                }
                guard let callbackURL else {
                    continuation.resume(throwing: WebAuthError.callbackMissing)
                    return
                }
                do {
                    continuation.resume(returning: try WebAuthCallbackParser.parse(callbackURL))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            authSession.presentationContextProvider = self
            authSession.prefersEphemeralWebBrowserSession = false
            self.session = authSession
            guard authSession.start() else {
                self.session = nil
                continuation.resume(throwing: WebAuthError.networkStartFailed)
                return
            }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first!
        return ASPresentationAnchor(windowScene: scene)
    }
}

private extension WebAuthError {
    static let networkStartFailed = WebAuthError.oauthFailed("Unable to start the secure login session.")
}
