//
//  MoveMarkStorageService.swift
//  movemork
//
//  MoveMark — evidence, maintenance and document files through the MoveMark API (Neon Object Storage).
//
//  The app never chooses a bucket or object key and never deletes an object directly:
//  - upload: ask the API for a ticket (it checks ownership and builds the key) → PUT the bytes to the
//    presigned URL with the signed headers → the caller records the returned path in its row.
//    If that row insert fails, the caller abandons the ticket; the API deletes the object only when no
//    row references it, so a row that committed behind a lost response keeps its file.
//  - download: presigned URLs are requested by **row id** and are temporary transport (1 hour). The
//    persistent identity of a file is its row id and stored path — never a URL.
//  - delete: by row id; the API removes the objects and the rows together.
//

import Foundation
import os

private let storageLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "movemork", category: "Storage")

/// One uploaded object as the API named it. `path`/`thumbnailPath` go into the row; `ticketId` is only
/// for ``MoveMarkStorageService/abandon(_:)``.
struct MoveMarkUpload: Sendable, Equatable {
    let ticketId: String
    let bucket: String
    let path: String
    /// Nil when no thumbnail was requested or its (best-effort) upload failed.
    let thumbnailPath: String?
}

struct MoveMarkDownloadURLs: Sendable {
    let url: URL
    let thumbnailURL: URL?
}

enum MoveMarkStorageError: LocalizedError {
    case notConfigured
    case notFound
    case rejected(status: Int, code: String?, message: String)
    case uploadFailed(status: Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "This build is not configured to reach MoveMark’s servers."
        case .notFound: return "That file isn’t available."
        case .rejected(let status, let code, let message):
            if status == 413 || code == "too_large" { return "This file is too large to upload." }
            if code == "unsupported_type" { return "This file type isn’t supported." }
            return message.isEmpty ? "Couldn’t save the file. Try again." : message
        case .uploadFailed: return "Couldn’t upload the file. Check your connection and try again."
        case .invalidResponse: return "Couldn’t reach MoveMark. Try again."
        }
    }
}

struct MoveMarkStorageService: Sendable {
    static let shared = MoveMarkStorageService()

    enum DownloadKind: String { case evidence, document }

    /// Presigned URLs carry their own signature: no cookies, no auth header.
    private static let objectSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.timeoutIntervalForRequest = 120
        return URLSession(configuration: config)
    }()

    // MARK: Upload

    func uploadEvidencePhoto(_ data: Data, thumbnail: Data?, propertyId: UUID, roomId: UUID, isMoveOut: Bool) async throws -> MoveMarkUpload {
        try await upload(fields: [
            "kind": "evidence",
            "propertyId": propertyId.uuidString.lowercased(),
            "roomId": roomId.uuidString.lowercased(),
            "phase": isMoveOut ? "move_out" : "move_in",
        ], data: data, contentType: "image/jpeg", thumbnail: thumbnail)
    }

    func uploadMaintenancePhoto(_ data: Data, thumbnail: Data?, propertyId: UUID, issueId: UUID) async throws -> MoveMarkUpload {
        try await upload(fields: [
            "kind": "maintenance",
            "propertyId": propertyId.uuidString.lowercased(),
            "issueId": issueId.uuidString.lowercased(),
        ], data: data, contentType: "image/jpeg", thumbnail: thumbnail)
    }

    func uploadDocument(_ data: Data, contentType: String, thumbnail: Data?, propertyId: UUID, documentType: String) async throws -> MoveMarkUpload {
        try await upload(fields: [
            "kind": "document",
            "propertyId": propertyId.uuidString.lowercased(),
            "documentType": documentType,
        ], data: data, contentType: contentType, thumbnail: thumbnail)
    }

    private struct Ticket: Decodable {
        struct Part: Decodable {
            let path: String
            let url: String
            let headers: [String: String]
        }
        let uploadTicketId: String
        let bucket: String
        let path: String
        let url: String
        let headers: [String: String]
        let thumbnail: Part?
    }

    private func upload(fields: [String: String], data: Data, contentType: String, thumbnail: Data?) async throws -> MoveMarkUpload {
        var body: [String: Any] = fields
        body["contentType"] = contentType
        body["size"] = data.count
        if let thumbnail { body["thumbnailSize"] = thumbnail.count }
        let ticket: Ticket = try await api("POST", "api/storage/uploads", json: body)

        do {
            try await put(data, to: ticket.url, headers: ticket.headers)
        } catch {
            // Nothing references a half-finished upload yet; release the ticket so no orphan stays behind.
            await abandon(MoveMarkUpload(ticketId: ticket.uploadTicketId, bucket: ticket.bucket, path: ticket.path, thumbnailPath: nil))
            throw error
        }

        // The thumbnail is best-effort: grids fall back to the full photo when it's missing.
        var thumbnailPath: String?
        if let thumbnail, let part = ticket.thumbnail {
            do {
                try await put(thumbnail, to: part.url, headers: part.headers)
                thumbnailPath = part.path
            } catch {
                storageLog.error("thumbnail PUT failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        return MoveMarkUpload(ticketId: ticket.uploadTicketId, bucket: ticket.bucket, path: ticket.path, thumbnailPath: thumbnailPath)
    }

    private func put(_ data: Data, to urlString: String, headers: [String: String]) async throws {
        guard let url = URL(string: urlString) else { throw MoveMarkStorageError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
        let (_, response) = try await Self.objectSession.upload(for: request, from: data)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw MoveMarkStorageError.uploadFailed(status: status) }
    }

    /// Call when the row insert for `upload` failed. Safe to call when unsure whether it committed:
    /// the API keeps any object a row references. Best-effort — a failure only leaves an unreferenced
    /// object, which account deletion still removes.
    func abandon(_ upload: MoveMarkUpload) async {
        struct Result: Decodable { let status: String }
        do {
            let result: Result = try await api("POST", "api/storage/uploads/\(upload.ticketId)/abandon", json: nil)
            storageLog.info("abandoned upload ticket status=\(result.status, privacy: .public)")
        } catch {
            storageLog.error("abandon failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: Download

    /// Fresh presigned URLs for rows the caller owns, keyed by row id. A row the caller can't see makes the
    /// whole request fail (`notFound`), so ask for one row at a time when partial results matter.
    func downloadURLs(_ kind: DownloadKind, ids: [UUID]) async throws -> [UUID: MoveMarkDownloadURLs] {
        struct Body: Decodable {
            struct Item: Decodable { let id: UUID; let url: String; let thumbnailUrl: String? }
            let items: [Item]
        }
        var result: [UUID: MoveMarkDownloadURLs] = [:]
        for batch in Self.batches(of: ids) {
            let body: Body = try await api("POST", "api/storage/downloads",
                                           json: ["kind": kind.rawValue, "ids": batch.map { $0.uuidString.lowercased() }])
            for item in body.items {
                guard let url = URL(string: item.url) else { continue }
                result[item.id] = MoveMarkDownloadURLs(url: url, thumbnailURL: item.thumbnailUrl.flatMap(URL.init(string:)))
            }
        }
        return result
    }

    // MARK: Delete

    /// Deletes rows and their files server-side. Rows already gone are not an error, so a retry after a
    /// lost response is safe.
    func deleteEvidence(ids: [UUID]) async throws { try await delete("api/storage/evidence", ids: ids) }

    func deleteDocuments(ids: [UUID]) async throws { try await delete("api/storage/documents", ids: ids) }

    private func delete(_ path: String, ids: [UUID]) async throws {
        for batch in Self.batches(of: Array(Set(ids))) {
            do {
                try await apiNoContent("DELETE", path, json: ["ids": batch.map { $0.uuidString.lowercased() }])
            } catch MoveMarkStorageError.notFound where batch.count > 1 {
                // The API is all-or-nothing per request; one already-deleted row hides the rest. Go one by one.
                for id in batch {
                    do { try await apiNoContent("DELETE", path, json: ["ids": [id.uuidString.lowercased()]]) }
                    catch MoveMarkStorageError.notFound { continue }
                }
            } catch MoveMarkStorageError.notFound {
                continue
            }
        }
    }

    // MARK: HTTP

    private static func batches(of ids: [UUID]) -> [[UUID]] {
        stride(from: 0, to: ids.count, by: 100).map { Array(ids[$0..<min($0 + 100, ids.count)]) }
    }

    private func request(_ method: String, _ path: String, json: Any?) throws -> URLRequest {
        guard let base = MoveMarkBackendConfig.apiBaseURL else { throw MoveMarkStorageError.notConfigured }
        var url = base
        for component in path.split(separator: "/") { url.appendPathComponent(String(component)) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let json {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: json)
        }
        return request
    }

    private func send(_ method: String, _ path: String, json: Any?) async throws -> Data {
        let (data, response) = try await MoveMarkAuthenticatedTransport.shared.data(for: try request(method, path, json: json))
        guard let http = response as? HTTPURLResponse else { throw MoveMarkStorageError.invalidResponse }
        if http.statusCode == 404 { throw MoveMarkStorageError.notFound }
        guard (200..<300).contains(http.statusCode) else {
            struct Err: Decodable { let error: String?; let code: String? }
            let err = try? JSONDecoder().decode(Err.self, from: data)
            throw MoveMarkStorageError.rejected(status: http.statusCode, code: err?.code, message: err?.error ?? "")
        }
        return data
    }

    private func api<T: Decodable>(_ method: String, _ path: String, json: Any?) async throws -> T {
        let data = try await send(method, path, json: json)
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw MoveMarkStorageError.invalidResponse }
    }

    private func apiNoContent(_ method: String, _ path: String, json: Any?) async throws {
        _ = try await send(method, path, json: json)
    }
}
