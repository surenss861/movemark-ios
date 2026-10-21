//
//  MoveMarkSignedURLCache.swift
//  movemork
//
//  In-memory cache of presigned download URLs (signed by the MoveMark API for 1h). Entries expire well
//  before the signature so a URL is never handed out close to dying; supports targeted invalidation
//  after uploads or on image load failure. URLs are transport only — never persist them.
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

    /// Records a URL minted alongside another one (an original and its thumbnail are signed together).
    func store(bucket: String, path: String, url: URL) {
        entries[storageKey(bucket: bucket, path: path)] = Entry(url: url, expiresAt: Date().addingTimeInterval(ttlSeconds))
    }

    func invalidate(bucket: String, path: String) {
        entries.removeValue(forKey: storageKey(bucket: bucket, path: path))
    }

    /// Invalidates any cached row whose storage path contains `fragment` (e.g. property UUID after uploads).
    /// Case-insensitive: callers pass `uuidString` (uppercase) while new keys are lowercase.
    func invalidateKeys(containing fragment: String) {
        let needle = fragment.lowercased()
        for key in entries.keys where key.lowercased().contains(needle) {
            entries.removeValue(forKey: key)
        }
    }

    func removeAll() {
        entries.removeAll()
    }
}
