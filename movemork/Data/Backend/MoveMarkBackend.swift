//
//  MoveMarkBackend.swift
//  movemork
//
//  MoveMark — backend endpoints and the Data API client (Neon).
//
//  Configure via `Config/Secrets.xcconfig` (gitignored; copy from Secrets.xcconfig.example), which sets
//  `NEON_AUTH_URL`, `NEON_DATA_API_URL` and (for non-production builds) `MOVEMARK_API_BASE_URL_OVERRIDE`
//  for Info.plist substitution. In .xcconfig, `https://…` is truncated at `//` (comment) unless split —
//  see the example file. The app never holds database or storage credentials: rows go through the Neon
//  Data API under row-level security with the user's own token, files through the MoveMark API.
//

import Foundation
import PostgREST

enum MoveMarkBackendConfig {
    private static func plistURL(_ key: String) -> URL? {
        let raw = (Bundle.main.object(forInfoDictionaryKey: key) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty, let url = URL(string: raw),
              let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
              let host = url.host, !host.isEmpty
        else { return nil }
        return url
    }

    /// Neon Auth base, e.g. `https://ep-….neonauth.<region>.aws.neon.tech/neondb/auth`.
    static let neonAuthURL: URL? = plistURL("NeonAuthURL")

    /// Neon Data API (PostgREST-compatible), e.g. `https://ep-….apirest.<region>.aws.neon.tech/neondb/rest/v1`.
    static let dataAPIURL: URL? = plistURL("NeonDataAPIURL")

    /// MoveMark API base. A non-empty override (dev builds pointing at a dev API) wins over the target setting.
    static let apiBaseURLString: String? = {
        for key in ["MoveMarkAPIBaseURLOverride", "MoveMarkAPIBaseURL"] {
            if let url = plistURL(key) { return url.absoluteString }
        }
        return nil
    }()

    static var apiBaseURL: URL? { apiBaseURLString.flatMap(URL.init(string:)) }

    /// `false` when any endpoint is missing, empty, or not a usable HTTP(S) URL with a host
    /// (catches a truncated `https:` from .xcconfig). UI gates on this instead of crashing at launch.
    static var isConfigured: Bool { neonAuthURL != nil && dataAPIURL != nil && apiBaseURL != nil }
}

/// Placeholder when unconfigured; every request is gated on `MoveMarkBackendConfig.isConfigured` first.
private let dataAPIPlaceholderURL = URL(string: "https://invalid.movemark.app")!

/// Row access for every repository. Requests carry the signed-in user's Neon Auth token (refreshed and
/// retried centrally by ``MoveMarkAuthenticatedTransport``); RLS decides which rows they can touch.
let dataAPI = PostgrestClient(
    url: MoveMarkBackendConfig.dataAPIURL ?? dataAPIPlaceholderURL,
    fetch: { request in try await MoveMarkAuthenticatedTransport.shared.data(for: request) }
)
