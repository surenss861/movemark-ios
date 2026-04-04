//
//  DisputeRepository.swift
//  movemork
//
//  MoveMark — Dispute, evidence links, and export data access.
//

import Foundation
import Supabase

struct DisputeRow: Codable, Identifiable {
    let id: UUID
    let propertyId: UUID
    let userId: UUID
    var title: String
    var disputeType: String
    var status: String
    var amountInQuestion: Double?
    var summary: String?
    var moveOutDate: String?
    var receivedItemized: Bool?
    var chargeDate: String?
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case propertyId = "property_id"
        case userId = "user_id"
        case title
        case disputeType = "dispute_type"
        case status
        case amountInQuestion = "amount_in_question"
        case summary
        case moveOutDate = "move_out_date"
        case receivedItemized = "received_itemized"
        case chargeDate = "charge_date"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct DisputeEvidenceLinkRow: Codable {
    let disputeId: UUID
    var evidenceFileId: UUID?
    var maintenanceIssueId: UUID?
    var propertyDocumentId: UUID?

    enum CodingKeys: String, CodingKey {
        case disputeId = "dispute_id"
        case evidenceFileId = "evidence_file_id"
        case maintenanceIssueId = "maintenance_issue_id"
        case propertyDocumentId = "property_document_id"
    }
}

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

struct DisputeRepository {

    func upsertDispute(_ row: DisputeRow) async throws -> UUID {
        let result: DisputeRow = try await supabase
            .from("disputes")
            .upsert(row)
            .select()
            .single()
            .execute()
            .value

        return result.id
    }

    /// Fetches the most recent draft dispute for the property and user, if any.
    func fetchDraft(propertyId: UUID, userId: UUID) async throws -> DisputeRow? {
        let rows: [DisputeRow] = try await supabase
            .from("disputes")
            .select()
            .eq("property_id", value: propertyId)
            .eq("user_id", value: userId)
            .eq("status", value: "draft")
            .order("updated_at", ascending: false)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    /// Fetches all evidence links for a dispute; returns grouped IDs for pre-selection.
    func fetchEvidenceLinks(disputeId: UUID) async throws -> (evidenceFileIds: [UUID], maintenanceIssueIds: [UUID], propertyDocumentIds: [UUID]) {
        let links: [DisputeEvidenceLinkRow] = try await supabase
            .from("dispute_evidence_links")
            .select()
            .eq("dispute_id", value: disputeId)
            .execute()
            .value

        var evidenceFileIds: [UUID] = []
        var maintenanceIssueIds: [UUID] = []
        var propertyDocumentIds: [UUID] = []

        for link in links {
            if let id = link.evidenceFileId { evidenceFileIds.append(id) }
            if let id = link.maintenanceIssueId { maintenanceIssueIds.append(id) }
            if let id = link.propertyDocumentId { propertyDocumentIds.append(id) }
        }
        return (evidenceFileIds, maintenanceIssueIds, propertyDocumentIds)
    }

    func insertEvidenceLinks(disputeId: UUID, evidenceFileIds: [UUID], maintenanceIssueIds: [UUID], documentIds: [UUID]) async throws {
        var links: [DisputeEvidenceLinkRow] = []

        for fileId in evidenceFileIds {
            links.append(DisputeEvidenceLinkRow(disputeId: disputeId, evidenceFileId: fileId))
        }
        for issueId in maintenanceIssueIds {
            links.append(DisputeEvidenceLinkRow(disputeId: disputeId, maintenanceIssueId: issueId))
        }
        for docId in documentIds {
            links.append(DisputeEvidenceLinkRow(disputeId: disputeId, propertyDocumentId: docId))
        }

        guard !links.isEmpty else { return }

        try await supabase
            .from("dispute_evidence_links")
            .insert(links)
            .execute()
    }

    /// Replaces all evidence links for a dispute: deletes existing, then inserts the given IDs.
    func replaceEvidenceLinks(
        disputeId: UUID,
        evidenceFileIds: [UUID],
        maintenanceIssueIds: [UUID],
        propertyDocumentIds: [UUID]
    ) async throws {
        try await supabase
            .from("dispute_evidence_links")
            .delete()
            .eq("dispute_id", value: disputeId)
            .execute()
        try await insertEvidenceLinks(
            disputeId: disputeId,
            evidenceFileIds: evidenceFileIds,
            maintenanceIssueIds: maintenanceIssueIds,
            documentIds: propertyDocumentIds
        )
    }

    func insertExportRecord(_ row: ExportRow) async throws {
        try await supabase
            .from("exports")
            .insert(row)
            .execute()
    }

    /// Short-lived URL for immediate share; `storagePath` is the `exports` bucket object key to store in `exports.file_path`.
    struct DisputePacketGenerationResult: Equatable {
        var shareURL: URL
        var storagePath: String
    }

    func callGenerateDisputePacket(disputeId: UUID, propertyId: UUID, jwt: String) async throws -> DisputePacketGenerationResult {
        struct RequestBody: Codable {
            let disputeId: UUID
            let propertyId: UUID

            enum CodingKeys: String, CodingKey {
                case disputeId = "dispute_id"
                case propertyId = "property_id"
            }
        }

        struct ResponseBody: Codable {
            let signedUrl: String
            let filePath: String

            enum CodingKeys: String, CodingKey {
                case signedUrl = "signed_url"
                case filePath = "file_path"
            }
        }

        let data: Data = try await supabase.functions.invoke(
            "generate-dispute-packet",
            options: FunctionInvokeOptions(
                body: RequestBody(disputeId: disputeId, propertyId: propertyId)
            )
        )

        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        guard let url = URL(string: decoded.signedUrl) else {
            throw URLError(.badURL)
        }
        let path = decoded.filePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            throw URLError(.badServerResponse)
        }
        return DisputePacketGenerationResult(shareURL: url, storagePath: path)
    }
}
