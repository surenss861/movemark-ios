//
//  MaintenanceRepository.swift
//  movemork
//
//  MoveMark — Maintenance issue data access.
//  Attachment paths use `{userId}/{propertyId}/{issueId}/...` for `maintenance-media` RLS.
//

import Foundation
import Supabase

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

    func fetchIssues(propertyId: UUID) async throws -> [MaintenanceIssueRow] {
        try await supabase
            .from("maintenance_issues")
            .select()
            .eq("property_id", value: propertyId)
            .order("date_reported", ascending: false)
            .execute()
            .value
    }

    func insertIssue(_ row: MaintenanceIssueRow) async throws -> MaintenanceIssueRow {
        try await supabase
            .from("maintenance_issues")
            .insert(row)
            .select()
            .single()
            .execute()
            .value
    }

    func markResolved(id: UUID) async throws {
        let now = ISO8601DateFormatter().string(from: Date())
        try await supabase
            .from("maintenance_issues")
            .update(["status": "resolved", "updated_at": now])
            .eq("id", value: id)
            .execute()
    }

    func updateFollowUp(id: UUID, note: String) async throws {
        let now = ISO8601DateFormatter().string(from: Date())
        try await supabase
            .from("maintenance_issues")
            .update([
                "landlord_response": note,
                "follow_up_date": now,
                "updated_at": now
            ])
            .eq("id", value: id)
            .execute()
    }

    func uploadAttachment(data: Data, path: String) async throws -> String {
        try await supabase.storage
            .from("maintenance-media")
            .upload(path, data: data, options: FileOptions(contentType: "image/jpeg"))

        return path
    }
}
