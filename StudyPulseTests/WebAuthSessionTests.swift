import XCTest
@testable import StudyPulse

@MainActor
final class WebAuthSessionTests: XCTestCase {
    func testLoginURLUsesEncodedReturnToCallback() throws {
        let components = try XCTUnwrap(URLComponents(url: WebAuthSession.loginURL, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.scheme, "https")
        XCTAssertEqual(components.host, "auth.chenkai.space")
        XCTAssertEqual(
            components.queryItems?.first(where: { $0.name == "return_to" })?.value,
            "studypulse://auth/callback"
        )
        XCTAssertTrue(WebAuthSession.loginURL.absoluteString.contains("return_to=studypulse%3A%2F%2Fauth%2Fcallback"))
    }

    func testCallbackParsesBothTokens() throws {
        let url = try XCTUnwrap(URL(string: "studypulse://auth/callback?access_token=access%201&refresh_token=refresh%2B1"))
        XCTAssertEqual(
            try WebAuthCallbackParser.parse(url),
            AuthTokenPair(accessToken: "access 1", refreshToken: "refresh+1")
        )
    }

    func testCallbackRejectsMissingRefreshToken() throws {
        let url = try XCTUnwrap(URL(string: "studypulse://auth/callback?access_token=access"))
        XCTAssertThrowsError(try WebAuthCallbackParser.parse(url)) { error in
            XCTAssertEqual(error as? WebAuthError, .refreshTokenMissing)
        }
    }

    func testCallbackReportsOAuthFailure() throws {
        let url = try XCTUnwrap(URL(string: "studypulse://auth/callback?error=access_denied&error_description=GitHub%20denied"))
        XCTAssertThrowsError(try WebAuthCallbackParser.parse(url)) { error in
            XCTAssertEqual(error as? WebAuthError, .oauthFailed("GitHub denied"))
        }
    }

    func testTokenPairIsStoredAndClearedOnlyInKeychain() throws {
        let keychain = KeychainStore(service: "StudyPulse.AuthTests.\(UUID().uuidString)")
        let store = AuthTokenStore(keychain: keychain)
        let pair = AuthTokenPair(accessToken: "access", refreshToken: "refresh")
        do {
            try store.save(pair)
        } catch KeychainStore.StoreError.unexpectedStatus(-34018) {
            throw XCTSkip("The simulator test process has no Keychain access entitlement.")
        }
        XCTAssertEqual(store.pair, pair)
        XCTAssertNil(UserDefaults.standard.string(forKey: "access_token"))
        try store.clear()
        XCTAssertNil(store.pair)
    }
}

@MainActor
final class AuthRefreshTests: XCTestCase {
    func testRefreshSavesRotatedTokenPair() async throws {
        let keychain = KeychainStore(service: "StudyPulse.RefreshTests.\(UUID().uuidString)")
        let tokenStore = AuthTokenStore(keychain: keychain)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RefreshStubURLProtocol.self]
        RefreshStubURLProtocol.responseData = Data(#"{"access_token":"new-access","refresh_token":"new-refresh"}"#.utf8)
        RefreshStubURLProtocol.statusCode = 200
        let client = AuthClient(session: URLSession(configuration: configuration))

        let pair: AuthTokenPair
        do {
            pair = try await client.refreshAccessToken(refreshToken: "old-refresh", tokenStore: tokenStore)
        } catch KeychainStore.StoreError.unexpectedStatus(-34018) {
            throw XCTSkip("The simulator test process has no Keychain access entitlement.")
        }
        XCTAssertEqual(pair, AuthTokenPair(accessToken: "new-access", refreshToken: "new-refresh"))
        XCTAssertEqual(tokenStore.pair, pair)
        XCTAssertEqual(RefreshStubURLProtocol.lastBody, #"{"refresh_token":"old-refresh"}"#)
    }
}

private final class RefreshStubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responseData = Data()
    nonisolated(unsafe) static var statusCode = 200
    nonisolated(unsafe) static var lastBody: String?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastBody = request.httpBody.flatMap { String(data: $0, encoding: .utf8) }
        let response = HTTPURLResponse(
            url: request.url!, statusCode: Self.statusCode, httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
