//
//  MoveMarkSignedURLCache.swift
//  movemork
//
//  In-memory signed URL cache (Supabase createSignedURL ~1h). Refreshes entries before expiry to avoid
//  silent 403s; supports targeted invalidation after uploads or on image load failure.
//

import Foundation

actor MoveMarkSignedURLCache {
    static let shared = MoveMarkSignedURLCache()

    private struct Entry {
        let url: URL
        let expiresAt: Date
    }

    /// Slightly under one hour so the next request mints a fresh URL before the token dies.
    private let ttlSeconds: TimeInterval = 50 * 60
    /// Don’t reuse a URL in its last 2 minutes.
    private let reuseSkewSeconds: TimeInterval = 120

    private var entries: [String: Entry] = [:]

    private func storageKey(bucket: String, path: String) -> String {
        "\(bucket)\u{2060}|\(path)"
    }

    func url(bucket: String, path: String, factory: @escaping () async throws -> URL) async throws -> URL {
        let key = storageKey(bucket: bucket, path: path)
        let now = Date()
        if let e = entries[key], e.expiresAt > now.addingTimeInterval(reuseSkewSeconds) {
            return e.url
        }
        let u = try await factory()
        entries[key] = Entry(url: u, expiresAt: now.addingTimeInterval(ttlSeconds))
        return u
    }

    func invalidate(bucket: String, path: String) {
        entries.removeValue(forKey: storageKey(bucket: bucket, path: path))
    }

    /// Invalidates any cached row whose storage path contains `fragment` (e.g. property UUID after uploads).
    func invalidateKeys(containing fragment: String) {
        for key in entries.keys where key.contains(fragment) {
            entries.removeValue(forKey: key)
        }
    }

    func removeAll() {
        entries.removeAll()
    }
}
