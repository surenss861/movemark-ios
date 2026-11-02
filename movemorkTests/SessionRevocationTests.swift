//
//  SessionRevocationTests.swift
//  movemorkTests
//
//  After a password reset, the first session signs every other session out: managed Neon Auth leaves
//  them alive (`revokeSessionsOnPasswordReset` is off and not configurable). Covers the request the app
//  sends (Better Auth `POST /revoke-other-sessions`) and when the pending mark is acted on, kept or dropped.
//

import Foundation
import Testing
@testable import MoveMark

private let authBase = URL(string: "https://ep-test.neonauth.example/neondb/auth")!

// In the transport suite: it shares StubURLProtocol's static handler, so it must run serialized with it.
extension MoveMarkTransportTests {
    private func signedInClient() async -> NeonAuthClient {
        let c = NeonAuthClient(http: StubURLProtocol.session, keychainService: "movemorkTests.revoke.\(UUID().uuidString)")
        await c.debugInstallSession(cookieName: "__Secure-neon-auth.session_token", cookieValue: "this-device",
                                    user: NeonAuthUser(id: UUID(), email: "qa@movemark.test"))
        return c
    }

    @Test func revokeOtherSessionsPostsWithThisDevicesSession() async throws {
        StubURLProtocol.reset { _ in (200, #"{"status":true}"#) }
        try await signedInClient().revokeOtherSessions(base: authBase)
        let request = try #require(StubURLProtocol.seen.first)
        #expect(StubURLProtocol.seen.count == 1)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://ep-test.neonauth.example/neondb/auth/revoke-other-sessions")
        #expect(request.value(forHTTPHeaderField: "Cookie") == "__Secure-neon-auth.session_token=this-device")
        #expect(request.value(forHTTPHeaderField: "Origin") == "https://ep-test.neonauth.example")
    }

    @Test func revokeOtherSessionsReportsAGoneSessionAndServerErrors() async throws {
        StubURLProtocol.reset { _ in (401, #"{"code":"UNAUTHORIZED","message":"Unauthorized"}"#) }
        await #expect(throws: NeonAuthError.sessionExpired) { try await signedInClient().revokeOtherSessions(base: authBase) }

        StubURLProtocol.reset { _ in (500, #"{"code":"INTERNAL","message":"boom"}"#) }
        await #expect(throws: NeonAuthError.rejected(code: "INTERNAL", message: "")) {
            try await signedInClient().revokeOtherSessions(base: authBase)
        }

        StubURLProtocol.reset { _ in (-1, "") }
        await #expect(throws: URLError.self) { try await signedInClient().revokeOtherSessions(base: authBase) }
    }

    @Test func revokeOtherSessionsWithoutASessionSendsNothing() async throws {
        StubURLProtocol.reset { _ in (200, "{}") }
        let c = NeonAuthClient(http: StubURLProtocol.session, keychainService: "movemorkTests.revoke.\(UUID().uuidString)")
        await #expect(throws: NeonAuthError.sessionExpired) { try await c.revokeOtherSessions(base: authBase) }
        #expect(StubURLProtocol.seen.isEmpty)
    }
}

@MainActor
struct PendingSessionRevocationTests {
    private func store() -> PendingSessionRevocation {
        let suite = "movemorkTests.revocation.\(UUID().uuidString)"
        return PendingSessionRevocation(defaults: UserDefaults(suiteName: suite)!)
    }

    private let resetAt = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func nothingHappensWithoutAReset() async {
        var calls = 0
        let outcome = await store().performIfPending(now: resetAt) { calls += 1 }
        #expect(outcome == .nothingPending)
        #expect(calls == 0)
    }

    @Test func firstSessionAfterAResetRevokesOnceThenForgets() async {
        let pending = store()
        pending.markPasswordReset(now: resetAt)
        var calls = 0
        #expect(await pending.performIfPending(now: resetAt.addingTimeInterval(120)) { calls += 1 } == .revoked)
        #expect(await pending.performIfPending(now: resetAt.addingTimeInterval(180)) { calls += 1 } == .nothingPending)
        #expect(calls == 1)
    }

    @Test func theMarkExpiresAfterTheWindow() async {
        let pending = store()
        pending.markPasswordReset(now: resetAt)
        #expect(pending.isPending(now: resetAt.addingTimeInterval(PendingSessionRevocation.window - 1)))
        var calls = 0
        let late = resetAt.addingTimeInterval(PendingSessionRevocation.window + 1)
        #expect(await pending.performIfPending(now: late) { calls += 1 } == .nothingPending)
        #expect(calls == 0)
        #expect(!pending.isPending(now: resetAt))  // expired marks are removed, not just ignored
    }

    @Test func offlineKeepsTheMarkForTheNextLaunch() async {
        let pending = store()
        pending.markPasswordReset(now: resetAt)
        let now = resetAt.addingTimeInterval(60)
        #expect(await pending.performIfPending(now: now) { throw URLError(.notConnectedToInternet) } == .willRetry)
        #expect(await pending.performIfPending(now: now) { throw NeonAuthError.rejected(code: "INTERNAL", message: "") } == .willRetry)
        #expect(await pending.performIfPending(now: now) {} == .revoked)
    }

    @Test func aSessionAlreadyGoneClearsTheMark() async {
        let pending = store()
        pending.markPasswordReset(now: resetAt)
        let now = resetAt.addingTimeInterval(60)
        #expect(await pending.performIfPending(now: now) { throw NeonAuthError.sessionExpired } == .sessionGone)
        #expect(!pending.isPending(now: now))
    }
}
