//
//  MoveMarkTransportTests.swift
//  movemorkTests
//
//  The authenticated transport's refresh contract: proactive refresh, one backstop refresh + one retry
//  on a *known* token rejection (MoveMark API 401; Neon Data API's 400 token messages), nothing else,
//  and one shared refresh when many requests wake up with the same stale token.
//

import Foundation
import Testing
@testable import MoveMark

// MARK: - HTTP stub

/// Answers every request through `handler`; records what was asked. Tests are serialized, so one
/// static handler is safe. A handler may ask for a response delay; responses are delivered
/// asynchronously so concurrent requests overlap as they would on a real network.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (Int, String)) = { _ in (500, "{}") }
    nonisolated(unsafe) static var delay: (@Sendable (URLRequest) -> TimeInterval) = { _ in 0 }
    nonisolated(unsafe) static var seen: [URLRequest] = []
    static let lock = NSLock()

    static func reset(delay d: @escaping @Sendable (URLRequest) -> TimeInterval = { _ in 0 },
                      _ h: @escaping @Sendable (URLRequest) -> (Int, String)) {
        lock.lock(); handler = h; delay = d; seen = []; lock.unlock()
    }
    static func count(path: String) -> Int {
        lock.lock(); defer { lock.unlock() }
        return seen.filter { $0.url?.path.hasSuffix(path) == true }.count
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock(); Self.seen.append(request); let h = Self.handler; let d = Self.delay(request); Self.lock.unlock()
        let request = self.request
        DispatchQueue.global().asyncAfter(deadline: .now() + d) { [self] in
            let (status, body) = h(request)
            if status < 0 {  // a transport failure, not an HTTP answer
                client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
                return
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil,
                                           headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        }
    }
    override func stopLoading() {}

    static var session: URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }
}

private func jwt(sub: String = "11111111-1111-4111-8111-111111111111", lifetime: Int = 900, salt: String = UUID().uuidString) -> String {
    let now = Int(Date().timeIntervalSince1970)
    let payload = #"{"sub":"\#(sub)","iat":\#(now),"exp":\#(now + lifetime),"n":"\#(salt)"}"#
    let b64 = Data(payload.utf8).base64EncodedString()
        .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    return "eyJhbGciOiJFZERTQSJ9.\(b64).sig"
}

private func bearer(_ r: URLRequest) -> String { r.value(forHTTPHeaderField: "Authorization")?.replacingOccurrences(of: "Bearer ", with: "") ?? "" }

// Neon Data API / MoveMark API bodies as observed on the dev branch.
private let expiredBody = #"{"message":"JWT token has expired (exp=1792547058)","code":null,"detail":null,"hint":null}"#
private let signatureBody = #"{"message":"signature error","code":null,"detail":null,"hint":null}"#
private let missingBody = #"{"message":"missing authentication credentials: required authorization bearer token in JWT format","code":null,"detail":null,"hint":null}"#
private let rlsBody = #"{"code":"42501","details":null,"hint":null,"message":"new row violates row-level security policy for table \"properties\""}"#
private let pgrstBody = #"{"code":"PGRST100","details":"unexpected \"x\" expecting \"not\" or operator","hint":null,"message":"\"failed to parse filter (x)\" (line 1, column 4)"}"#
private let dataURL = URL(string: "https://ep-test.apirest.example/neondb/rest/v1/properties?select=id")!
private let apiURL = URL(string: "http://127.0.0.1:8787/api/exports")!
private let otherURL = URL(string: "https://elsewhere.example/whatever")!
private let origins = MoveMarkAuthenticatedTransport.AuthOrigins(dataAPIHost: "ep-test.apirest.example", apiHost: "127.0.0.1")

/// Counts token calls; `refreshed` mints "fresh-N".
private actor FakeTokens: AccessTokenProviding {
    var current = "stale"
    var refreshes = 0
    var refreshError: Error?
    func validAccessToken(forceRefresh: Bool) async throws -> String { current }
    func refreshedAccessToken(replacing rejected: String) async throws -> String {
        if let refreshError { throw refreshError }
        if current != rejected { return current }
        refreshes += 1
        current = "fresh-\(refreshes)"
        return current
    }
    func setRefreshError(_ e: Error) { refreshError = e }
}

@Suite(.serialized)
struct MoveMarkTransportTests {

    // MARK: Classification

    @Test(arguments: [
        (401, "{}", true),                 // MoveMark API: expired/invalid token
        (400, expiredBody, true),          // Data API: expired, validly signed
        (400, signatureBody, true),        // Data API: not verifiable
        (400, missingBody, false),         // no token sent: a client bug, refreshing can't help
        (400, pgrstBody, false),           // ordinary PostgREST 400
        (400, #"{"message":"JWT token has expired","code":"PGRST301"}"#, false), // has a code: not Neon's token gate
        (403, rlsBody, false),             // RLS / authorization
        (404, "{}", false), (422, "{}", false), (500, "{}", false), (200, "[]", false),
    ])
    func classifiesOnlyKnownTokenRejections(status: Int, body: String, expected: Bool) {
        // The 401 rule belongs to the MoveMark API; every other rule to the Data API.
        let url = status == 401 ? apiURL : dataURL
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
        #expect(MoveMarkAuthenticatedTransport.isAuthRejection(data: Data(body.utf8), response: response, origins: origins) == expected)
    }

    @Test(arguments: [
        (otherURL, 400, expiredBody), (otherURL, 401, "{}"),  // lookalikes from an unrelated host
        (apiURL, 400, expiredBody),                           // Data API dialect from the MoveMark API
        (dataURL, 401, "{}"),                                 // 401 is not the Data API's token answer
    ])
    func rejectionRulesApplyOnlyToTheirOwnOrigin(url: URL, status: Int, body: String) {
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
        #expect(!MoveMarkAuthenticatedTransport.isAuthRejection(data: Data(body.utf8), response: response, origins: origins))
    }

    // MARK: Backstop: one refresh, one retry

    @Test(arguments: [(apiURL, 401, "{}"), (dataURL, 400, expiredBody), (dataURL, 400, signatureBody)])
    func rejectionRefreshesOnceAndRetriesOnce(url: URL, status: Int, body: String) async throws {
        let tokens = FakeTokens()
        StubURLProtocol.reset { r in bearer(r) == "stale" ? (status, body) : (200, "[]") }
        let (_, response) = try await MoveMarkAuthenticatedTransport(tokens: tokens, session: StubURLProtocol.session, origins: origins)
            .data(for: URLRequest(url: url))
        #expect((response as? HTTPURLResponse)?.statusCode == 200)
        #expect(await tokens.refreshes == 1)
        #expect(StubURLProtocol.seen.map(bearer) == ["stale", "fresh-1"])
    }

    @Test(arguments: [(400, pgrstBody), (400, missingBody), (403, rlsBody), (422, "{}")])
    func otherErrorsAreReturnedWithoutRefresh(status: Int, body: String) async throws {
        let tokens = FakeTokens()
        StubURLProtocol.reset { _ in (status, body) }
        let (data, response) = try await MoveMarkAuthenticatedTransport(tokens: tokens, session: StubURLProtocol.session, origins: origins)
            .data(for: URLRequest(url: dataURL))
        #expect((response as? HTTPURLResponse)?.statusCode == status && String(decoding: data, as: UTF8.self) == body)
        #expect(await tokens.refreshes == 0)
        #expect(StubURLProtocol.seen.count == 1)
    }

    @Test func secondRejectionIsSurfacedWithoutLooping() async throws {
        let tokens = FakeTokens()
        StubURLProtocol.reset { _ in (400, expiredBody) }  // rejects every token
        let (data, response) = try await MoveMarkAuthenticatedTransport(tokens: tokens, session: StubURLProtocol.session, origins: origins)
            .data(for: URLRequest(url: dataURL))
        #expect((response as? HTTPURLResponse)?.statusCode == 400 && String(decoding: data, as: UTF8.self) == expiredBody)
        #expect(await tokens.refreshes == 1)
        #expect(StubURLProtocol.seen.count == 2)
    }

    @Test func refreshFailureSurfacesWithoutRetrying() async throws {
        let tokens = FakeTokens()
        await tokens.setRefreshError(NeonAuthError.sessionExpired)
        StubURLProtocol.reset { _ in (401, "{}") }
        await #expect(throws: NeonAuthError.sessionExpired) {
            _ = try await MoveMarkAuthenticatedTransport(tokens: tokens, session: StubURLProtocol.session, origins: origins).data(for: URLRequest(url: apiURL))
        }
        #expect(StubURLProtocol.seen.count == 1)
    }

    // MARK: The real NeonAuthClient: proactive refresh, single flight, session loss

    private func client() async -> NeonAuthClient {
        let c = NeonAuthClient(http: StubURLProtocol.session, keychainService: "movemorkTests.transport.\(UUID().uuidString)")
        await c.debugInstallSession(cookieName: "__Secure-neon-auth.session_token", cookieValue: "cookie",
                                    user: NeonAuthUser(id: UUID(), email: "qa@movemark.test"))
        return c
    }

    @Test func proactiveRefreshBeforeExpiryAndCachingOtherwise() async throws {
        StubURLProtocol.reset { r in r.url!.path.hasSuffix("/token") ? (200, #"{"token":"\#(jwt())"}"#) : (200, "[]") }
        let c = await client()
        let first = try await c.validAccessToken()
        #expect(try await c.validAccessToken() == first)            // fresh: served from cache
        #expect(StubURLProtocol.count(path: "/token") == 1)
        await c.debugCacheAccessToken(first, refreshAfter: Date().addingTimeInterval(-1))  // inside the leeway
        let second = try await c.validAccessToken()
        #expect(second != first && StubURLProtocol.count(path: "/token") == 2)
    }

    @Test func concurrentStaleRequestsShareOneRefresh() async throws {
        // After app resume, requests holding the same stale token are rejected at different moments:
        // some while the first refresh is in flight, some after it has finished. Neither group may
        // refresh again.
        final class Counter: @unchecked Sendable { var n = 0; let lock = NSLock()
            func next() -> Int { lock.lock(); defer { lock.unlock() }; n += 1; return n } }
        let staleArrivals = Counter()
        StubURLProtocol.reset(delay: { r in
            if r.url!.path.hasSuffix("/token") { return 0.05 }
            // Stale requests are answered 0.04s … 0.4s apart: rejections land during and after the refresh.
            return bearer(r) == "stale-token" ? Double(staleArrivals.next()) * 0.04 : 0
        }) { r in
            if r.url!.path.hasSuffix("/token") { return (200, #"{"token":"\#(jwt())"}"#) }
            return bearer(r) == "stale-token" ? (400, expiredBody) : (200, "[]")
        }
        let c = await client()
        await c.debugCacheAccessToken("stale-token")  // looks fresh locally; the server says expired
        let transport = MoveMarkAuthenticatedTransport(tokens: c, session: StubURLProtocol.session, origins: origins)
        let statuses = try await withThrowingTaskGroup(of: Int.self) { group in
            for _ in 0..<10 {
                group.addTask { (try await transport.data(for: URLRequest(url: dataURL)).1 as? HTTPURLResponse)?.statusCode ?? 0 }
            }
            return try await group.reduce(into: [Int]()) { $0.append($1) }
        }
        #expect(statuses == Array(repeating: 200, count: 10))
        #expect(StubURLProtocol.count(path: "/token") == 1)   // one refresh, not ten
    }

    @Test(arguments: [500, 503, 0])  // 0 = transport failure (offline / DNS / timeout)
    func transientRefreshFailureKeepsTheSession(status: Int) async throws {
        StubURLProtocol.reset { r in
            if r.url!.path.hasSuffix("/token") { return status == 0 ? (-1, "") : (status, "{}") }
            return (400, expiredBody)
        }
        let c = await client()
        await c.debugCacheAccessToken("stale-token")
        await #expect(throws: (any Error).self) {
            _ = try await MoveMarkAuthenticatedTransport(tokens: c, session: StubURLProtocol.session, origins: origins).data(for: URLRequest(url: dataURL))
        }
        #expect(await c.currentUser() != nil)  // a valid session survives a flaky refresh
    }

    @Test func sessionRejectedDuringRefreshSignsOutOnceAndDoesNotRetry() async throws {
        StubURLProtocol.reset { r in r.url!.path.hasSuffix("/token") ? (401, "{}") : (400, expiredBody) }
        let c = await client()
        await c.debugCacheAccessToken("stale-token")
        final class Flag: @unchecked Sendable { var posted = false }
        let flag = Flag()
        let observer = NotificationCenter.default.addObserver(forName: .moveMarkSessionExpired, object: nil, queue: nil) { _ in flag.posted = true }
        defer { NotificationCenter.default.removeObserver(observer) }
        await #expect(throws: NeonAuthError.sessionExpired) {
            _ = try await MoveMarkAuthenticatedTransport(tokens: c, session: StubURLProtocol.session, origins: origins).data(for: URLRequest(url: dataURL))
        }
        #expect(await c.currentUser() == nil)                 // session ended locally
        #expect(StubURLProtocol.count(path: "/token") == 1)
        #expect(StubURLProtocol.count(path: "/properties") == 1)  // no retry after the session died
        #expect(flag.posted)                                  // the app is told to show sign-in
    }
}
