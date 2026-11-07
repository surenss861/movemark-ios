//
//  MoveMarkAuthenticatedTransport.swift
//  movemork
//
//  MoveMark — every authenticated request (Data API and MoveMark API) leaves through here.
//
//  Normal path: attach a valid Neon Auth access token (``NeonAuthClient`` refreshes it proactively).
//  Backstop: when the server rejects the token itself (stale after sleep, clock skew, early expiry),
//  refresh exactly once — shared by every request that held the same token — and retry the original
//  request exactly once. A second rejection is returned to the caller unchanged; nothing loops.
//
//  Only a *known* authentication rejection triggers the backstop (see ``isAuthRejection``). RLS 403s,
//  validation errors and every other 4xx pass straight through.
//
//  Never use this for presigned storage URLs: those carry their own signature, and an extra
//  Authorization header makes Object Storage reject the request.
//

import Foundation

/// The token operations the transport needs (``NeonAuthClient`` in the app; a fake in tests).
protocol AccessTokenProviding: Sendable {
    func validAccessToken(forceRefresh: Bool) async throws -> String
    func refreshedAccessToken(replacing rejected: String) async throws -> String
}

extension NeonAuthClient: AccessTokenProviding {}

final class MoveMarkAuthenticatedTransport: Sendable {
    static let shared = MoveMarkAuthenticatedTransport()

    private let tokens: any AccessTokenProviding
    private let session: URLSession
    private let origins: AuthOrigins

    init(tokens: any AccessTokenProviding = NeonAuthClient.shared, session: URLSession? = nil, origins: AuthOrigins = .configured) {
        self.tokens = tokens
        self.origins = origins
        self.session = session ?? {
            let config = URLSessionConfiguration.default
            config.httpCookieStorage = nil
            config.httpShouldSetCookies = false
            return URLSession(configuration: config)
        }()
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let token = try await tokens.validAccessToken(forceRefresh: false)
        let (data, response) = try await send(request, token: token)
        guard Self.isAuthRejection(data: data, response: response, origins: origins) else { return (data, response) }

        let fresh = try await tokens.refreshedAccessToken(replacing: token)
        return try await send(request, token: fresh)
    }

    private func send(_ request: URLRequest, token: String) async throws -> (Data, URLResponse) {
        var authorized = request
        authorized.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return try await session.data(for: authorized)
    }

    // MARK: - What counts as "the server rejected the token"

    /// Neon Data API messages for a presented token it won't accept, as observed on the dev branch
    /// (2026-10-20). The Data API answers these with HTTP 400 and `"code": null` — not 401 — so the
    /// message is the only discriminator. A request *without* a token ("missing authentication
    /// credentials") is a client bug, not a stale token, and is deliberately not listed.
    static let dataAPITokenRejectionPrefixes = [
        "JWT token has expired",  // validly signed, past `exp`
        "signature error",        // not verifiable with the current keys (e.g. after key rotation)
    ]

    /// Which host speaks which rejection dialect. Rules apply only to their own origin, so a lookalike
    /// body from any other server never triggers a refresh.
    struct AuthOrigins: Sendable {
        let dataAPIHost: String?
        let apiHost: String?

        static var configured: AuthOrigins {
            AuthOrigins(dataAPIHost: MoveMarkBackendConfig.dataAPIURL?.host?.lowercased(),
                        apiHost: MoveMarkBackendConfig.apiBaseURL?.host?.lowercased())
        }
    }

    /// The MoveMark API's HTTP 401, or the Neon Data API's HTTP 400 whose structured body is one of the
    /// token-rejection messages above — each only from its own origin. Everything else is not an auth
    /// rejection: ordinary 400s, RLS/authorization 403s, ownership 404s, validation 422s, 5xx.
    static func isAuthRejection(data: Data, response: URLResponse, origins: AuthOrigins) -> Bool {
        guard let http = response as? HTTPURLResponse, let host = http.url?.host?.lowercased() else { return false }
        if http.statusCode == 401 { return host == origins.apiHost }
        guard http.statusCode == 400, host == origins.dataAPIHost else { return false }
        struct DataAPIError: Decodable { let message: String?; let code: String? }
        guard let body = try? JSONDecoder().decode(DataAPIError.self, from: data),
              body.code == nil,  // PostgREST errors carry a code (PGRST…/SQLSTATE); Neon's token gate doesn't
              let message = body.message
        else { return false }
        return dataAPITokenRejectionPrefixes.contains { message.hasPrefix($0) }
    }
}
