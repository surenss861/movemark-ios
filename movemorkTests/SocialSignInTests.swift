//
//  SocialSignInTests.swift
//  movemorkTests
//
//  Neon Auth's browser sign-in: the request shape, the challenge staying with this attempt, the verifier exchange
//  keeping a session only on success, and the return URL accepting nothing but the expected shape.
//

import Foundation
import Testing
@testable import MoveMark

/// Like `StubURLProtocol`, but can answer with response headers (Set-Cookie).
final class SocialStubURLProtocol: URLProtocol, @unchecked Sendable {
    struct Reply: Sendable { var status: Int; var body: String; var headers: [String: String] = [:] }
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> Reply) = { _ in Reply(status: 500, body: "{}") }
    nonisolated(unsafe) static var seen: [(path: String, query: String?, body: Data?, headers: [String: String])] = []
    static let lock = NSLock()

    static func reset(_ h: @escaping @Sendable (URLRequest) -> Reply) {
        lock.lock(); handler = h; seen = []; lock.unlock()
    }
    static var paths: [String] { lock.lock(); defer { lock.unlock() }; return seen.map(\.path) }
    static func body(forPathSuffix suffix: String) -> Data? {
        lock.lock(); defer { lock.unlock() }
        return seen.first { $0.path.hasSuffix(suffix) }?.body
    }
    static func queries(forPathSuffix suffix: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        return seen.first { $0.path.hasSuffix(suffix) }?.query
    }
    static func headers(forPathSuffix suffix: String) -> [String: String] {
        lock.lock(); defer { lock.unlock() }
        return seen.first { $0.path.hasSuffix(suffix) }?.headers ?? [:]
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        var body = request.httpBody
        if body == nil, let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }
            var data = Data(); var buf = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable { let n = stream.read(&buf, maxLength: buf.count); if n <= 0 { break }; data.append(buf, count: n) }
            body = data
        }
        Self.lock.lock()
        Self.seen.append((request.url?.path ?? "", request.url?.query, body, request.allHTTPHeaderFields ?? [:]))
        let h = Self.handler
        Self.lock.unlock()
        let reply = h(request)
        var headers = reply.headers; headers["Content-Type"] = "application/json"
        let response = HTTPURLResponse(url: request.url!, statusCode: reply.status, httpVersion: nil, headerFields: headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(reply.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}

    static var session: URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [SocialStubURLProtocol.self]
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        return URLSession(configuration: config)
    }
}

private let base = URL(string: "https://ep-test-123.neonauth.c-7.us-east-2.aws.neon.tech/neondb/auth")!
private let userId = "22222222-2222-4222-8222-222222222222"
private let challenge = "__Secure-neon-auth.session_challenge=chal-1; __Secure-neon-auth.session_challange=chal-1"

private func jwt(lifetime: Int = 900) -> String {
    let now = Int(Date().timeIntervalSince1970)
    let payload = #"{"sub":"\#(userId)","iat":\#(now),"exp":\#(now + lifetime)}"#
    let b64 = Data(payload.utf8).base64EncodedString()
        .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    return "eyJhbGciOiJFZERTQSJ9.\(b64).sig"
}

/// Neon Auth as observed on production: a browser URL and two challenge cookies, then the verifier exchange.
@Sendable private func neonAuth(_ r: URLRequest) -> SocialStubURLProtocol.Reply {
    let path = r.url?.path ?? ""
    if path.hasSuffix("/sign-in/social") {
        return .init(status: 200, body: #"{"url":"https://ep-test-123.neonauth.c-7.us-east-2.aws.neon.tech/neondb/auth/sign-in/social/init?token=t1","redirect":true}"#,
                     headers: ["Set-Cookie": "__Secure-neon-auth.session_challenge=chal-1; Path=/; Secure, __Secure-neon-auth.session_challange=chal-1; Path=/; Secure"])
    }
    if path.hasSuffix("/get-session") {
        return .init(status: 200, body: #"{"session":{"id":"s"},"user":{"id":"\#(userId)","email":"probe@example.com"}}"#,
                     headers: ["Set-Cookie": "__Secure-neon-auth.session_token=cookie-value; Path=/; HttpOnly; Secure"])
    }
    if path.hasSuffix("/token") { return .init(status: 200, body: #"{"token":"\#(jwt())"}"#) }
    return .init(status: 404, body: "{}")
}

private func client() -> NeonAuthClient {
    NeonAuthClient(baseURL: base, http: SocialStubURLProtocol.session, keychainService: "movemorkTests.social.\(UUID().uuidString)")
}

@Suite(.serialized)
struct SocialSignInTests {

    // MARK: Gate

    @Test func modeIsOffUnlessTheLiveFlagIsSet() {
        #expect(SocialSignInConfig.resolvedMode(liveFlag: false) == .off)
        #expect(SocialSignInConfig.resolvedMode(liveFlag: true) == .live)
    }

    @Test func thisTestBuildIsOffWithoutLaunchArguments() {
        #expect(SocialSignInConfig.mode == .off)
    }

    @Test func providerOrderIsAppleFirstOnIOS() {
        #expect(SocialProvider.iOSOrder == [.apple, .google])
    }

    // MARK: Return URL

    @Test func verifierIsReadOnlyFromTheExpectedReturnURL() throws {
        let ok = URL(string: "movemark://auth/callback?neon_auth_session_verifier=abc-123")!
        #expect(try SocialBrowserReturn.verifier(from: ok) == "abc-123")
    }

    @Test(arguments: [
        "https://evil.example/auth/callback?neon_auth_session_verifier=abc",  // wrong scheme
        "movemark://reset-password?neon_auth_session_verifier=abc",            // wrong host
        "movemark://auth/other?neon_auth_session_verifier=abc",                // wrong path
        "movemark://auth/callback",                                            // nothing
        "movemark://auth/callback?neon_auth_session_verifier=",                // empty
        "movemark://auth/callback?error=server_error",
    ])
    func anythingElseIsAFailedSignIn(raw: String) {
        #expect(throws: SocialSignInError.self) { _ = try SocialBrowserReturn.verifier(from: URL(string: raw)!) }
    }

    @Test func anExistingAccountConflictTellsThePersonHowToGetIn() {
        let url = URL(string: "movemark://auth/callback?error=account_not_linked")!
        #expect(throws: SocialSignInError.failed(SocialBrowserReturn.accountConflictMessage)) {
            _ = try SocialBrowserReturn.verifier(from: url)
        }
    }

    @Test func aDeclinedConsentIsTreatedAsCancelled() {
        #expect(throws: SocialSignInError.cancelled) {
            _ = try SocialBrowserReturn.verifier(from: URL(string: "movemark://auth/callback?error=access_denied")!)
        }
    }

    // MARK: Start

    @Test func startSendsProviderAndCallbackAndKeepsTheChallengeForThisAttempt() async throws {
        SocialStubURLProtocol.reset(neonAuth)
        let c = client()
        let start = try await c.beginBrowserSignIn(provider: .google, callbackURL: SocialBrowserReturn.callbackURL)

        #expect(start.url.path.hasSuffix("/sign-in/social/init"))
        #expect(start.challengeCookies == challenge)
        let body = try #require(SocialStubURLProtocol.body(forPathSuffix: "/sign-in/social"))
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: String])
        #expect(json == ["provider": "google", "callbackURL": "https://account.movemark.ca/auth/return"])
        #expect(SocialStubURLProtocol.headers(forPathSuffix: "/sign-in/social")["Origin"] == "https://ep-test-123.neonauth.c-7.us-east-2.aws.neon.tech")
        #expect(await c.currentUser() == nil)  // starting creates no session
    }

    @Test func aRefusedCallbackIsARejectionWithItsCode() async {
        SocialStubURLProtocol.reset { _ in .init(status: 403, body: #"{"error":"Invalid callbackURL","code":"INVALID_CALLBACKURL"}"#) }
        await #expect(throws: NeonAuthError.rejected(code: "INVALID_CALLBACKURL", message: "Invalid callbackURL")) {
            _ = try await client().beginBrowserSignIn(provider: .apple, callbackURL: SocialBrowserReturn.callbackURL)
        }
    }

    @Test func aStartWithoutAChallengeCookieStops() async {
        SocialStubURLProtocol.reset { _ in .init(status: 200, body: #"{"url":"https://x.example/init","redirect":true}"#) }
        await #expect(throws: NeonAuthError.invalidResponse) {
            _ = try await client().beginBrowserSignIn(provider: .google, callbackURL: SocialBrowserReturn.callbackURL)
        }
    }

    // MARK: Exchange

    @Test func exchangeSendsVerifierAndChallengeAndKeepsTheSession() async throws {
        SocialStubURLProtocol.reset(neonAuth)
        let c = client()
        let user = try await c.finishBrowserSignIn(verifier: "v-1", challengeCookies: challenge)

        #expect(user.id.uuidString.lowercased() == userId)
        #expect(SocialStubURLProtocol.headers(forPathSuffix: "/get-session")["Cookie"] == challenge)
        #expect(SocialStubURLProtocol.queries(forPathSuffix: "/get-session") == "neon_auth_session_verifier=v-1")
        #expect(SocialStubURLProtocol.paths.last?.hasSuffix("/token") == true)  // proved usable before returning
        #expect(await c.currentUser()?.id == user.id)
        await c.endSessionLocally(notify: false)
    }

    @Test(arguments: [(400, "VERIFICATION_NOT_FOUND"), (400, "SESSION_CHALLENGE_COOKIE_NOT_FOUND"), (429, "RATE_LIMITED")])
    func aRefusedOrReplayedVerifierKeepsNoSession(status: Int, code: String) async {
        SocialStubURLProtocol.reset { _ in .init(status: status, body: #"{"code":"\#(code)","error":"no"}"#) }
        let c = client()
        await #expect(throws: NeonAuthError.self) { _ = try await c.finishBrowserSignIn(verifier: "used", challengeCookies: challenge) }
        #expect(await c.currentUser() == nil)
        #expect(SocialStubURLProtocol.paths.allSatisfy { !$0.hasSuffix("/token") })
    }

    @Test func anExchangeWithoutASessionCookieKeepsNoSession() async {
        SocialStubURLProtocol.reset { _ in .init(status: 200, body: "null") }
        let c = client()
        await #expect(throws: NeonAuthError.invalidResponse) { _ = try await c.finishBrowserSignIn(verifier: "v", challengeCookies: challenge) }
        #expect(await c.currentUser() == nil)
    }
}
