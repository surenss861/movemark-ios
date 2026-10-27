//
//  NeonAuthClient.swift
//  movemork
//
//  MoveMark — the one place that talks to Neon Auth (Managed Better Auth) and owns the session.
//
//  Two credentials, kept apart on purpose:
//  - the **session cookie** (7 days, Keychain, this device only) proves the sign-in;
//  - the **access token** (Ed25519 JWT, 15 minutes, memory only) is what the Data API and the
//    MoveMark API accept. It is minted from the cookie by `GET /token` and refreshed here, once,
//    for every caller — repositories never see expiry or refresh.
//
//  Email/password only in the recovery build; no OAuth.
//

import Foundation
import os
import Security

private let neonAuthLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "movemork", category: "NeonAuth")

struct NeonAuthUser: Codable, Equatable, Sendable {
    let id: UUID
    let email: String
}

enum NeonAuthError: LocalizedError, Equatable {
    case notConfigured
    /// No session, or the server no longer accepts it. The user must sign in again.
    case sessionExpired
    /// Neon Auth answered with an error the user can act on.
    case rejected(code: String?, message: String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "This build is not configured to reach MoveMark’s servers."
        case .sessionExpired:
            return "Your session has ended. Sign in again."
        case .rejected(let code, let message):
            switch code {
            // One message for an unknown email and a wrong password: telling them apart would let anyone
            // find out which addresses have a MoveMark account.
            case "INVALID_EMAIL_OR_PASSWORD":
                return "Email or password doesn’t match."
            case "RATE_LIMITED": return "Too many attempts. Wait a minute, then try again."
            case "USER_ALREADY_EXISTS", "USER_ALREADY_EXISTS_USE_ANOTHER_EMAIL":
                return "An account with this email already exists. Sign in instead."
            case "PASSWORD_TOO_SHORT": return "Password is too short."
            case "PASSWORD_TOO_LONG": return "Password is too long."
            case "INVALID_EMAIL": return "Enter a valid email."
            case "INVALID_TOKEN": return "This reset link is invalid or has expired. Request a new one."
            default: return message.isEmpty ? "Couldn’t reach MoveMark. Try again." : message
            }
        case .invalidResponse:
            return "Couldn’t reach MoveMark. Try again."
        }
    }
}

actor NeonAuthClient {
    static let shared = NeonAuthClient()

    /// Refresh this long before the access token's own expiry, so a request never leaves with a token
    /// that dies in flight.
    private let refreshLeeway: TimeInterval = 90

    private let keychain: NeonAuthKeychain
    /// Cookies are handled by hand (one cookie, one host); a shared cookie store would leak the session
    /// into unrelated requests.
    private let http: URLSession

    /// `http` and `keychainService` are injectable for tests only; the app uses `shared`.
    init(http: URLSession? = nil, keychainService: String? = nil) {
        self.keychain = NeonAuthKeychain(service: keychainService ?? "\(Bundle.main.bundleIdentifier ?? "movemork").neon-auth")
        self.http = http ?? {
            let config = URLSessionConfiguration.ephemeral
            config.httpCookieStorage = nil
            config.httpShouldSetCookies = false
            config.httpCookieAcceptPolicy = .never
            config.timeoutIntervalForRequest = 30
            return URLSession(configuration: config)
        }()
    }

    private var stored: NeonAuthKeychain.Stored?
    private var loadedFromKeychain = false
    private var accessToken: (value: String, refreshAfter: Date)?
    private var refreshTask: Task<String, Error>?

    // MARK: - Session

    /// The signed-in user persisted on this device, if any. Does not touch the network.
    func currentUser() -> NeonAuthUser? {
        loadIfNeeded()
        return stored?.user
    }

    /// A valid access token, minting a new one when the cached token is close to expiry. Concurrent callers
    /// share one refresh. Throws `.sessionExpired` (and posts `.moveMarkSessionExpired`) only when Neon Auth
    /// rejects the session itself — a network failure is thrown as-is and never signs anyone out.
    func validAccessToken(forceRefresh: Bool = false) async throws -> String {
        loadIfNeeded()
        guard stored != nil else { throw NeonAuthError.sessionExpired }
        if !forceRefresh, let accessToken, accessToken.refreshAfter > Date() {
            return accessToken.value
        }
        if let refreshTask {
            return try await refreshTask.value
        }
        let task = Task { try await self.mintAccessToken() }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    /// The backstop after a server rejected `rejected`: one refresh for everyone holding that token.
    ///
    /// When several requests woke up with the same stale token and were all rejected, only the first
    /// refreshes; the rest find a different (newer) token already cached, or join the refresh in flight.
    /// A token that was itself just minted is never refreshed twice.
    func refreshedAccessToken(replacing rejected: String) async throws -> String {
        loadIfNeeded()
        guard stored != nil else { throw NeonAuthError.sessionExpired }
        if let accessToken, accessToken.value != rejected {
            return accessToken.value
        }
        if let refreshTask {
            return try await refreshTask.value
        }
        let task = Task { try await self.mintAccessToken() }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    private func mintAccessToken() async throws -> String {
        guard let base = MoveMarkBackendConfig.neonAuthURL else { throw NeonAuthError.notConfigured }
        guard let stored else { throw NeonAuthError.sessionExpired }
        var request = URLRequest(url: base.appendingPathComponent("token"))
        request.setValue(stored.cookieHeader, forHTTPHeaderField: "Cookie")
        let (data, response) = try await http.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 || status == 403 {
            neonAuthLog.notice("session rejected by Neon Auth (HTTP \(status)); signing out locally")
            await endSessionLocally(notify: true)
            throw NeonAuthError.sessionExpired
        }
        guard status == 200,
              let body = try? JSONDecoder().decode(TokenBody.self, from: data),
              let lifetime = Self.lifetime(ofJWT: body.token)
        else { throw NeonAuthError.invalidResponse }
        // Expiry is measured on this device's clock from the token's own lifetime, so a skewed clock
        // can't make a fresh token look expired (or an old one look fresh).
        let refreshAfter = Date().addingTimeInterval(max(30, lifetime - refreshLeeway))
        accessToken = (body.token, refreshAfter)
        return body.token
    }

    #if DEBUG
    /// Tests only: the cached access token, without refreshing.
    func debugCachedAccessToken() -> String? { accessToken?.value }

    /// Tests only: cache `token` as if fresh, so the next request presents it (e.g. an expired token, to
    /// prove the transport's refresh-and-retry backstop).
    func debugCacheAccessToken(_ token: String, refreshAfter: Date = Date().addingTimeInterval(600)) {
        accessToken = (token, refreshAfter)
    }

    /// Tests only: a signed-in session without the network (pairs with an injected `http` and keychain).
    func debugInstallSession(cookieName: String, cookieValue: String, user: NeonAuthUser) {
        stored = NeonAuthKeychain.Stored(cookieName: cookieName, cookieValue: cookieValue, user: user)
        loadedFromKeychain = true
    }
    #endif

    // MARK: - Sign up / in / out

    /// Nil when the account was created but Neon Auth issued no session (email verification required).
    func signUp(email: String, password: String) async throws -> NeonAuthUser? {
        let body = try await post("sign-up/email", ["email": email, "password": password, "name": ""], storeSession: true)
        guard stored != nil else { return nil }
        return try await finishSignIn(body)
    }

    func signIn(email: String, password: String) async throws -> NeonAuthUser {
        let body = try await post("sign-in/email", ["email": email, "password": password], storeSession: true)
        return try await finishSignIn(body)
    }

    private func finishSignIn(_ data: Data) async throws -> NeonAuthUser {
        guard stored != nil else { throw NeonAuthError.invalidResponse }
        guard let body = try? JSONDecoder().decode(SignInBody.self, from: data),
              let id = UUID(uuidString: body.user.id)
        else {
            await endSessionLocally(notify: false)
            throw NeonAuthError.invalidResponse
        }
        let user = NeonAuthUser(id: id, email: body.user.email)
        stored?.user = user
        if let stored { keychain.save(stored) }
        // Prove the session can mint a token before the UI treats the user as signed in.
        _ = try await validAccessToken(forceRefresh: true)
        return user
    }

    /// Revokes the session server-side when possible; always clears it locally (offline sign-out works).
    func signOut() async {
        loadIfNeeded()
        if let stored, let base = MoveMarkBackendConfig.neonAuthURL {
            var request = URLRequest(url: base.appendingPathComponent("sign-out"))
            request.httpMethod = "POST"
            request.setValue(stored.cookieHeader, forHTTPHeaderField: "Cookie")
            request.setValue(Self.origin(of: base), forHTTPHeaderField: "Origin")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = Data("{}".utf8)
            _ = try? await http.data(for: request)
        }
        await endSessionLocally(notify: false)
    }

    /// Forgets the session on this device (account deleted, session rejected, or sign-out).
    func endSessionLocally(notify: Bool) async {
        refreshTask?.cancel()
        refreshTask = nil
        accessToken = nil
        stored = nil
        loadedFromKeychain = true
        keychain.delete()
        if notify {
            await MainActor.run { NotificationCenter.default.post(name: .moveMarkSessionExpired, object: nil) }
        }
    }

    // MARK: - Password reset

    /// Emails a reset link. Answers the same whether or not the address has an account.
    func requestPasswordReset(email: String) async throws {
        var body = ["email": email]
        if let redirect = MoveMarkBackendConfig.passwordResetURL { body["redirectTo"] = redirect.absoluteString }
        _ = try await post("request-password-reset", body, storeSession: false)
    }

    /// Sets a new password from the token in a reset link. Neon Auth revokes the account's other sessions.
    func resetPassword(token: String, newPassword: String) async throws {
        _ = try await post("reset-password", ["token": token, "newPassword": newPassword], storeSession: false)
    }

    // MARK: - HTTP

    private func post(_ path: String, _ fields: [String: String], storeSession: Bool) async throws -> Data {
        guard let base = MoveMarkBackendConfig.neonAuthURL else { throw NeonAuthError.notConfigured }
        let url = base.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.origin(of: base), forHTTPHeaderField: "Origin")
        request.httpBody = try JSONEncoder().encode(fields)
        let (data, response) = try await http.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw NeonAuthError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let err = try? JSONDecoder().decode(ErrorBody.self, from: data)
            neonAuthLog.notice("\(path, privacy: .public) failed HTTP \(http.statusCode) code=\(err?.code ?? "-", privacy: .public)")
            throw NeonAuthError.rejected(code: http.statusCode == 429 ? "RATE_LIMITED" : err?.code, message: err?.message ?? "")
        }
        if storeSession {
            accessToken = nil
            loadedFromKeychain = true
            stored = Self.sessionCookie(from: http, url: url).map {
                NeonAuthKeychain.Stored(cookieName: $0.name, cookieValue: $0.value, user: nil)
            }
        }
        return data
    }

    private func loadIfNeeded() {
        guard !loadedFromKeychain else { return }
        loadedFromKeychain = true
        stored = keychain.load()
        // A cookie without a user means sign-in never finished; don't resurrect it.
        if stored?.user == nil { stored = nil; keychain.delete() }
    }

    private static func sessionCookie(from response: HTTPURLResponse, url: URL) -> HTTPCookie? {
        let headers = response.allHeaderFields.reduce(into: [String: String]()) { result, pair in
            if let key = pair.key as? String, let value = pair.value as? String { result[key] = value }
        }
        return HTTPCookie.cookies(withResponseHeaderFields: headers, for: url)
            .first { $0.name.hasSuffix("session_token") && !$0.value.isEmpty }
    }

    private static func origin(of url: URL) -> String {
        var components = URLComponents()
        components.scheme = url.scheme
        components.host = url.host
        components.port = url.port
        return components.string ?? ""
    }

    /// Seconds between `iat` and `exp`; the signature is the server's business, not the client's.
    private static func lifetime(ofJWT token: String) -> TimeInterval? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var payload = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload),
              let claims = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let iat = (claims["iat"] as? NSNumber)?.doubleValue,
              let exp = (claims["exp"] as? NSNumber)?.doubleValue,
              exp > iat
        else { return nil }
        return exp - iat
    }

    private struct TokenBody: Decodable { let token: String }
    private struct SignInBody: Decodable {
        struct User: Decodable { let id: String; let email: String }
        let user: User
    }
    private struct ErrorBody: Decodable { let code: String?; let message: String? }
}

/// The session cookie and user, as one Keychain item available only on this device after first unlock.
private struct NeonAuthKeychain: Sendable {
    struct Stored: Codable, Sendable {
        let cookieName: String
        let cookieValue: String
        var user: NeonAuthUser?

        var cookieHeader: String { "\(cookieName)=\(cookieValue)" }
    }

    let service: String
    private let account = "session"

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    func load() -> Stored? {
        var q = query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(Stored.self, from: data)
    }

    func save(_ stored: Stored) {
        guard let data = try? JSONEncoder().encode(stored) else { return }
        SecItemDelete(query as CFDictionary)
        var q = query
        q[kSecValueData as String] = data
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(q as CFDictionary, nil)
        if status != errSecSuccess {
            neonAuthLog.error("keychain save failed status=\(status)")
        }
    }

    func delete() {
        SecItemDelete(query as CFDictionary)
    }
}
