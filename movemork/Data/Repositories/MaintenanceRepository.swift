//
//  MaintenanceRepository.swift
//  movemork
//
//  MoveMark — Maintenance issue data access.
//  Attachments go to `maintenance-media` under keys the MoveMark API builds (`{userId}/{propertyId}/{issueId}/{uuid}.jpg`).
//

import Foundation
import PostgREST

/// Fixed categories for maintenance issues; raw values match DB.
enum MaintenanceCategory: String, CaseIterable {
    case waterDamage = "Water damage"
    case heatingCooling = "Heating / cooling"
    case pest = "Pest"
    case appliance = "Appliance"
    case structural = "Structural"
    case plumbing = "Plumbing"
    case electrical = "Electrical"
    case other = "Other"
}

struct MaintenanceIssueRow: Codable, Identifiable {
    let id: UUID
    let propertyId: UUID
    let userId: UUID
    var title: String
    var description: String?
    var category: String?
    var status: String
    var dateDiscovered: String?
    var dateReported: String?
    var reportMethod: String?
    var landlordResponse: String?
    var followUpDate: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case propertyId = "property_id"
        case userId = "user_id"
        case title
        case description
        case category
        case status
        case dateDiscovered = "date_discovered"
        case dateReported = "date_reported"
        case reportMethod = "report_method"
        case landlordResponse = "landlord_response"
        case followUpDate = "follow_up_date"
        case updatedAt = "updated_at"
    }
}

struct MaintenanceRepository {

    /// Capped so a long-tenured account (years of logged issues) can't grow this into an unbounded fetch; ordered so the cap keeps the most recent issues.
    func fetchIssues(propertyId: UUID) async throws -> [MaintenanceIssueRow] {
        try await dataAPI
            .from("maintenance_issues")
            .select()
            .eq("property_id", value: propertyId)
            .order("date_reported", ascending: false)
            .limit(200)
            .execute()
            .value
    }

    /// Single-row lookup by id (e.g. deep link / path-based navigation) — avoids fetching the whole issue list just to find one.
    func fetchIssue(id: UUID) async throws -> MaintenanceIssueRow? {
        let rows: [MaintenanceIssueRow] = try await dataAPI
            .from("maintenance_issues")
            .select()
            .eq("id", value: id)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    func insertIssue(_ row: MaintenanceIssueRow) async throws -> MaintenanceIssueRow {
        try await dataAPI
            .from("maintenance_issues")
            .insert(row)
            .select()
            .single()
            .execute()
            .value
    }

    func markResolved(id: UUID) async throws {
        let now = ISO8601DateFormatter().string(from: Date())
        try await dataAPI
            .from("maintenance_issues")
            .update(["status": "resolved", "updated_at": now])
            .eq("id", value: id)
            .execute()
    }

    func updateFollowUp(id: UUID, note: String) async throws {
        let now = ISO8601DateFormatter().string(from: Date())
        try await dataAPI
            .from("maintenance_issues")
            .update([
                "landlord_response": note,
                "follow_up_date": now,
                "updated_at": now
            ])
            .eq("id", value: id)
            .execute()
    }

    /// Uploads one piece of maintenance evidence (immutable source + derivative + thumbnail), verified and finalized.
    func uploadAttachment(_ source: MMEvidenceSource, propertyId: UUID, issueId: UUID) async throws -> MoveMarkUpload {
        let upload = try await MoveMarkStorageService.shared.uploadMaintenanceEvidence(source, propertyId: propertyId, issueId: issueId)
        await MoveMarkSignedURLCache.shared.invalidateKeys(containing: propertyId.uuidString)
        return upload
    }

    /// Releases an upload whose `evidence_files` insert failed (keeps it if a row references it after all).
    func abandonUpload(_ upload: MoveMarkUpload) async {
        await MoveMarkStorageService.shared.abandon(upload)
    }

    /// Deletes a maintenance issue row (e.g. when photo pipeline produced zero linked evidence after user attached photos).
    func deleteIssue(id: UUID) async throws {
        try await dataAPI
            .from("maintenance_issues")
            .delete()
            .eq("id", value: id)
            .execute()
    }
}
