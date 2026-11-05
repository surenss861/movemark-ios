//
//  SocialSignInTests.swift
//  movemorkTests
//
//  The social-sign-in probe layer: the gate never accepts a non-probe URL; `signInSocial` sends exactly
//  the Better Auth ID-token request and keeps a session only on success; the probe runner always leaves
//  the probe signed out and never calls the network for a cancelled sheet.
//

import Foundation
import Testing
@testable import MoveMark

/// Like `StubURLProtocol`, but can answer with response headers (Set-Cookie).
final class SocialStubURLProtocol: URLProtocol, @unchecked Sendable {
    struct Reply: Sendable { var status: Int; var body: String; var headers: [String: String] = [:] }
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> Reply) = { _ in Reply(status: 500, body: "{}") }
    nonisolated(unsafe) static var seen: [(path: String, body: Data?, headers: [String: String])] = []
    static let lock = NSLock()

    static func reset(_ h: @escaping @Sendable (URLRequest) -> Reply) {
        lock.lock(); handler = h; seen = []; lock.unlock()
    }
    static var paths: [String] { lock.lock(); defer { lock.unlock() }; return seen.map(\.path) }
    static func body(forPathSuffix suffix: String) -> Data? {
        lock.lock(); defer { lock.unlock() }
        return seen.first { $0.path.hasSuffix(suffix) }?.body
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
        Self.seen.append((request.url?.path ?? "", body, request.allHTTPHeaderFields ?? [:]))
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

private let probeURL = URL(string: "https://ep-probe-123.neonauth.c-8.us-east-2.aws.neon.tech/neondb/auth")!
private let userId = "22222222-2222-4222-8222-222222222222"

private func jwt(lifetime: Int = 900) -> String {
    let now = Int(Date().timeIntervalSince1970)
    let payload = #"{"sub":"\#(userId)","iat":\#(now),"exp":\#(now + lifetime)}"#
    let b64 = Data(payload.utf8).base64EncodedString()
        .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    return "eyJhbGciOiJFZERTQSJ9.\(b64).sig"
}

/// Neon Auth as observed for a successful sign-in: session cookie, user, then `/token` mints a JWT.
@Sendable private func neonAuthAccepts(_ r: URLRequest) -> SocialStubURLProtocol.Reply {
    let path = r.url?.path ?? ""
    if path.hasSuffix("/sign-in/social") {
        return .init(status: 200, body: #"{"redirect":false,"token":"t","user":{"id":"\#(userId)","email":"probe@privaterelay.appleid.com"}}"#,
                     headers: ["Set-Cookie": "__Secure-neon-auth.session_token=cookie-value; Path=/; HttpOnly; Secure; SameSite=None"])
    }
    if path.hasSuffix("/token") { return .init(status: 200, body: #"{"token":"\#(jwt())"}"#) }
    if path.hasSuffix("/sign-out") { return .init(status: 200, body: #"{"success":true}"#) }
    return .init(status: 404, body: "{}")
}

private func probeClient() -> NeonAuthClient {
    NeonAuthClient(baseURL: probeURL, http: SocialStubURLProtocol.session, keychainService: "movemorkTests.social.\(UUID().uuidString)")
}

@MainActor
private final class FakeCredentials: SocialCredentialProviding {
    var result: Result<SocialIdentityToken, Error>
    var calls = 0
    init(_ result: Result<SocialIdentityToken, Error>) { self.result = result }
    func credential(for provider: SocialProvider) async throws -> SocialIdentityToken {
        calls += 1
        return try result.get()
    }
}

@Suite(.serialized)
struct SocialSignInTests {

    // MARK: Gate

    @Test(arguments: [
        ("https://ep-probe-123.neonauth.c-8.us-east-2.aws.neon.tech/neondb/auth", true),
        ("http://ep-probe-123.neonauth.c-8.us-east-2.aws.neon.tech/neondb/auth", false),   // not HTTPS
        ("https://evil.example/neondb/auth", false),                                       // not Neon Auth
        ("https://ep-x.neonauth.us-east-2.aws.neon.tech.evil.example/auth", false),        // suffix trick
        ("https://ep-app-999.neonauth.c-8.us-east-2.aws.neon.tech/neondb/auth", false),    // the app's own auth
        ("", false),
        ("not a url", false),
    ])
    func probeURLIsOnlyAnHTTPSNeonAuthHostThatIsNotTheApps(raw: String, accepted: Bool) {
        let app = URL(string: "https://ep-app-999.neonauth.c-8.us-east-2.aws.neon.tech/neondb/auth")
        #expect((SocialSignInConfig.validatedProbeURL(raw, appAuthURL: app) != nil) == accepted)
    }

    @Test func providerOrderIsAppleFirstOnIOS() {
        #expect(SocialProvider.iOSOrder == [.apple, .google])
    }

    @Test func nonceHashIsSHA256Hex() {
        #expect(NativeSocialCredentialProvider.sha256Hex("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        let a = NativeSocialCredentialProvider.randomNonce(), b = NativeSocialCredentialProvider.randomNonce()
        #expect(a.count == 32 && a != b)
    }

    // MARK: signInSocial

    @Test func signInSocialSendsTheIDTokenRequestAndKeepsTheSession() async throws {
        SocialStubURLProtocol.reset(neonAuthAccepts)
        let client = probeClient()
        let user = try await client.signInSocial(SocialIdentityToken(provider: .apple, idToken: "id-token", nonce: "hashed-nonce"))

        #expect(user.id.uuidString.lowercased() == userId)
        #expect(user.email == "probe@privaterelay.appleid.com")  // Hide My Email address passes through as-is
        let body = try #require(SocialStubURLProtocol.body(forPathSuffix: "/sign-in/social"))
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["provider"] as? String == "apple")
        let idToken = try #require(json["idToken"] as? [String: Any])
        #expect(idToken["token"] as? String == "id-token")
        #expect(idToken["nonce"] as? String == "hashed-nonce")
        #expect(json.keys.sorted() == ["idToken", "provider"])  // no callbackURL: never the redirect flow
        #expect(SocialStubURLProtocol.headers(forPathSuffix: "/sign-in/social")["Origin"] == "https://ep-probe-123.neonauth.c-8.us-east-2.aws.neon.tech")
        #expect(SocialStubURLProtocol.paths.last?.hasSuffix("/token") == true)  // proved usable before returning
        #expect(await client.currentUser()?.id == user.id)
        await client.endSessionLocally(notify: false)
    }

    @Test func googleTokenWithoutNonceOmitsIt() async throws {
        SocialStubURLProtocol.reset(neonAuthAccepts)
        let client = probeClient()
        _ = try await client.signInSocial(SocialIdentityToken(provider: .google, idToken: "g-token", nonce: nil))
        let body = try #require(SocialStubURLProtocol.body(forPathSuffix: "/sign-in/social"))
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["provider"] as? String == "google")
        #expect((json["idToken"] as? [String: Any])?["nonce"] == nil)
        await client.endSessionLocally(notify: false)
    }

    @Test(arguments: [(401, "ACCOUNT_NOT_LINKED"), (400, "INVALID_TOKEN"), (429, "RATE_LIMITED")])
    func rejectedTokenKeepsNoSession(status: Int, code: String) async throws {
        SocialStubURLProtocol.reset { _ in .init(status: status, body: #"{"code":"\#(code)","message":"no"}"#) }
        let client = probeClient()
        await #expect(throws: NeonAuthError.self) {
            _ = try await client.signInSocial(SocialIdentityToken(provider: .google, idToken: "x", nonce: nil))
        }
        #expect(await client.currentUser() == nil)
        #expect(SocialStubURLProtocol.paths.allSatisfy { !$0.hasSuffix("/token") })
    }

    // MARK: Probe runner

    @MainActor @Test func probeRunReportsIdentityThenSignsOutOfTheProbe() async throws {
        SocialStubURLProtocol.reset(neonAuthAccepts)
        let client = probeClient()
        let runner = SocialProbeRunner(
            credentials: FakeCredentials(.success(SocialIdentityToken(provider: .apple, idToken: "id", nonce: "n"))),
            makeClient: { url in
                #expect(url == probeURL)
                return client
            }
        )
        let result = try await runner.run(.apple, probeURL: probeURL)
        #expect(result == SocialProbeResult(provider: .apple, userId: UUID(uuidString: userId)!, email: "probe@privaterelay.appleid.com"))
        #expect(SocialStubURLProtocol.paths.last?.hasSuffix("/sign-out") == true)
        #expect(await client.currentUser() == nil)
    }

    @MainActor @Test func cancelledSheetMakesNoNetworkCall() async throws {
        SocialStubURLProtocol.reset(neonAuthAccepts)
        let runner = SocialProbeRunner(credentials: FakeCredentials(.failure(SocialSignInError.cancelled)), makeClient: { _ in probeClient() })
        await #expect(throws: SocialSignInError.cancelled) { _ = try await runner.run(.apple, probeURL: probeURL) }
        #expect(SocialStubURLProtocol.paths.isEmpty)
    }

    @MainActor @Test func failedProbeSignInLeavesNoProbeSession() async throws {
        SocialStubURLProtocol.reset { _ in .init(status: 401, body: #"{"code":"ACCOUNT_NOT_LINKED","message":"account not linked"}"#) }
        let client = probeClient()
        let runner = SocialProbeRunner(
            credentials: FakeCredentials(.success(SocialIdentityToken(provider: .google, idToken: "id", nonce: nil))),
            makeClient: { _ in client }
        )
        await #expect(throws: NeonAuthError.self) { _ = try await runner.run(.google, probeURL: probeURL) }
        #expect(await client.currentUser() == nil)
    }

    @MainActor @Test func googleIsUnavailableUntilItsSDKIsAdded() async {
        await #expect(throws: SocialSignInError.providerUnavailable(.google)) {
            _ = try await NativeSocialCredentialProvider().credential(for: .google)
        }
    }
}
