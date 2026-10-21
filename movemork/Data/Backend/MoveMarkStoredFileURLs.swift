//
//  MoveMarkStoredFileURLs.swift
//  movemork
//
//  MoveMark — temporary download URLs for files the UI knows by their stored path.
//
//  Screens hold a file's stored path (from its row); the API signs by row id. This resolves the path to
//  its row through the Data API (RLS: only the caller's rows), asks the API for that row's URLs, and caches
//  them briefly. The URL is transport only — the path and row id stay the file's identity.
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

    private struct FileRef: Decodable {
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
            let quoted = "\"" + path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
            let refs: [FileRef] = try await dataAPI
                .from(table)
                .select("id,file_path,thumbnail_path")
                .or("file_path.eq.\(quoted),thumbnail_path.eq.\(quoted)")
                .limit(1)
                .execute()
                .value
            guard let ref = refs.first,
                  let urls = try await MoveMarkStorageService.shared.downloadURLs(kind, ids: [ref.id])[ref.id]
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
