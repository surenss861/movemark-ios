//
//  MoveMarkStoredFileURLs.swift
//  movemork
//
//  MoveMark — temporary download URLs for files the UI knows by their stored path.
//
//  The API signs by exact row id after checking the caller owns that row. Screens pass the row id they
//  already hold (every photo/document they show came from its row), so no lookup is needed; the path keys
//  the short-lived cache. Only a caller without the id falls back to resolving the path to its row (an exact
//  match on an indexed column, RLS-scoped). The URL is transport only — the row stays the file's identity.
//

import Foundation
import PostgREST

enum MoveMarkStoredFileURLs {
    /// `inspection-media` or `maintenance-media` path from an `evidence_files` row (original or thumbnail).
    static func evidenceURL(bucket: String, path: String) async throws -> URL {
        try await url(table: "evidence_files", kind: .evidence, bucket: bucket, path: path)
    }

    /// Path from a `property_documents` row (original or thumbnail).
    static func documentURL(bucket: String, path: String) async throws -> URL {
        try await url(table: "property_documents", kind: .document, bucket: bucket, path: path)
    }

    /// Rows the app has loaded (hydration, history pages, vault summary, maintenance, documents), so their
    /// paths sign by exact row id with no lookup.
    static func remember(rowId: UUID, filePath: String, thumbnailPath: String?) {
        knownRows.remember(FileRef(id: rowId, filePath: filePath, thumbnailPath: thumbnailPath))
    }

    static func remember(_ photos: [EvidencePhoto]) {
        for photo in photos { remember(rowId: photo.id, filePath: photo.filePath, thumbnailPath: photo.thumbnailPath) }
    }

    /// Path → row, filled by `remember`. Lock-protected so any context can read it synchronously.
    private final class KnownRows: @unchecked Sendable {
        private let lock = NSLock()
        private var byPath: [String: FileRef] = [:]

        func remember(_ ref: FileRef) {
            lock.lock(); defer { lock.unlock() }
            if let path = ref.filePath { byPath[path] = ref }
            if let thumbnail = ref.thumbnailPath { byPath[thumbnail] = ref }
        }

        func row(for path: String) -> FileRef? {
            lock.lock(); defer { lock.unlock() }
            return byPath[path]
        }
    }

    private static let knownRows = KnownRows()

    fileprivate struct FileRef: Decodable {
        let id: UUID
        let filePath: String?
        let thumbnailPath: String?

        enum CodingKeys: String, CodingKey {
            case id
            case filePath = "file_path"
            case thumbnailPath = "thumbnail_path"
        }
    }

    private static func url(
        table: String,
        kind: MoveMarkStorageService.DownloadKind,
        bucket: String,
        path: String
    ) async throws -> URL {
        guard !path.isEmpty else { throw MoveMarkStorageError.notFound }
        return try await MoveMarkSignedURLCache.shared.url(bucket: bucket, path: path) {
            let ref: FileRef
            if let known = knownRows.row(for: path) {
                ref = known  // exact row id; the API checks ownership
            } else {
                let quoted = "\"" + path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
                let refs: [FileRef] = try await dataAPI
                    .from(table)
                    .select("id,file_path,thumbnail_path")
                    .or("file_path.eq.\(quoted),thumbnail_path.eq.\(quoted)")
                    .limit(1)
                    .execute()
                    .value
                guard let first = refs.first else { throw MoveMarkStorageError.notFound }
                ref = first
            }
            guard let urls = try await MoveMarkStorageService.shared.downloadURLs(kind, ids: [ref.id])[ref.id]
            else { throw MoveMarkStorageError.notFound }

            // One request signs both; keep the sibling so the grid and the full-size viewer share it.
            if ref.thumbnailPath == path, let thumbnailURL = urls.thumbnailURL {
                if let original = ref.filePath {
                    await MoveMarkSignedURLCache.shared.store(bucket: bucket, path: original, url: urls.url)
                }
                return thumbnailURL
            }
            if let thumbnail = ref.thumbnailPath, let thumbnailURL = urls.thumbnailURL {
                await MoveMarkSignedURLCache.shared.store(bucket: bucket, path: thumbnail, url: thumbnailURL)
            }
            return urls.url
        }
    }
}
