//
//  ExportRepository.swift
//  movemork
//
//  MoveMark — Export records. PDFs are written by the MoveMark worker and downloaded through
//  `GET /api/exports/{id}/download` (see `ExportAPIClient`); the app never touches the `exports` bucket.
//

import Foundation
import PostgREST

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
        try await dataAPI
            .from("exports")
            .select()
            .eq("property_id", value: propertyId)
            .order("created_at", ascending: false)
            .limit(300)
            .execute()
            .value
    }
}
