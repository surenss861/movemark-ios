//
//  ExportRepository.swift
//  movemork
//
//  MoveMark — Export record and file storage access.
//  PDFs upload to `exports` under `{userId}/{propertyId}/...` (matches storage RLS). Formal packet rows may store HTTPS URLs instead.
//

import Foundation
import Supabase

struct ExportRow: Codable, Identifiable {
    let id: UUID
    let disputeId: UUID?
    let propertyId: UUID
    let userId: UUID
    var exportType: String
    var filePath: String?
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case disputeId = "dispute_id"
        case propertyId = "property_id"
        case userId = "user_id"
        case exportType = "export_type"
        case filePath = "file_path"
        case createdAt = "created_at"
    }
}

struct ExportRepository {

    /// Capped so a long-tenured account can't grow this into an unbounded fetch; ordered so the cap keeps the most recent exports.
    /// (Not currently called — `ExportHistoryView` reads exports via `ExportAPIClient`/movemark-api instead — but capped for whenever this direct path is used.)
    func fetchExports(propertyId: UUID) async throws -> [ExportRow] {
        try await supabase
            .from("exports")
            .select()
            .eq("property_id", value: propertyId)
            .order("created_at", ascending: false)
            .limit(300)
            .execute()
            .value
    }

    func uploadExport(data: Data, path: String) async throws -> String {
        try await supabase.storage
            .from("exports")
            .upload(path, data: data, options: FileOptions(contentType: "application/pdf"))
        return path
    }

    func insertExport(_ row: ExportRow) async throws {
        try await supabase
            .from("exports")
            .insert(row)
            .execute()
    }

    func signedURL(filePath: String) async throws -> URL {
        try await MoveMarkSignedURLCache.shared.url(bucket: "exports", path: filePath) {
            try await supabase.storage
                .from("exports")
                .createSignedURL(path: filePath, expiresIn: 3600)
        }
    }

    /// Verifies that an export row's file_path points to a usable file.
    /// - Returns: `.ready` if path is valid and (for storage paths) signed URL succeeds; otherwise a specific failure.
    func verify(filePath: String?) async -> ExportVerificationStatus {
        let path = filePath?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if path.isEmpty {
            return .missingPath
        }

        let lower = path.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            return URL(string: path) != nil ? .ready : .invalidURL
        }

        do {
            _ = try await signedURL(filePath: path)
            return .ready
        } catch {
            return .verificationFailed(MoveMarkFlowMessage.exportFileVerificationFailed(error))
        }
    }
}
