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

/// `landlord_response` as a log: entries separated by a blank line, each new one prefixed "Oct 27: ". Older free text
/// (written before entries were dated) reads as one undated entry.
enum MaintenanceFollowUpLog {
    struct Entry { let day: String?; let text: String }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM d"
        return f
    }()

    static func appending(_ note: String, on date: Date, to existing: String?) -> String {
        let entry = "\(dayFormatter.string(from: date)): \(note.trimmingCharacters(in: .whitespacesAndNewlines))"
        let previous = existing?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return previous.isEmpty ? entry : "\(previous)\n\n\(entry)"
    }

    /// Splits on blank lines; a paragraph without a day prefix belongs to the entry before it.
    static func entries(_ response: String?) -> [Entry] {
        let raw = response?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty else { return [] }
        var result: [Entry] = []
        for block in raw.components(separatedBy: "\n\n") {
            let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if let match = trimmed.firstMatch(of: #/^([A-Z][a-z]{2} \d{1,2}): /#) {
                result.append(Entry(day: String(match.1), text: String(trimmed[match.range.upperBound...])))
            } else if let last = result.popLast() {
                result.append(Entry(day: last.day, text: "\(last.text)\n\n\(trimmed)"))
            } else {
                result.append(Entry(day: nil, text: trimmed))
            }
        }
        return result
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
            .order("created_at", ascending: false)
            .order("id", ascending: false)
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

    /// Idempotent by id: a retry whose first insert landed (but whose response was lost) returns the saved row
    /// instead of failing on the duplicate key or creating a second case.
    func insertIssue(_ row: MaintenanceIssueRow) async throws -> MaintenanceIssueRow {
        do {
            return try await dataAPI
                .from("maintenance_issues")
                .insert(row)
                .select()
                .single()
                .execute()
                .value
        } catch let error as PostgrestError where error.code == "23505" {
            if let existing = try await fetchIssue(id: row.id) { return existing }
            throw error
        }
    }

    func markResolved(id: UUID) async throws {
        let now = ISO8601DateFormatter().string(from: Date())
        try await dataAPI
            .from("maintenance_issues")
            .update(["status": "resolved", "updated_at": now])
            .eq("id", value: id)
            .execute()
    }

    /// Appends a dated follow-up to `landlord_response` (one text column), read fresh so an earlier entry is never
    /// overwritten. Returns the stored response.
    func updateFollowUp(id: UUID, note: String, fallbackExisting: String?) async throws -> String {
        let date = Date()
        let now = ISO8601DateFormatter().string(from: date)
        let current = try await fetchIssue(id: id)
        let existing = current != nil ? current?.landlordResponse : fallbackExisting
        let response = MaintenanceFollowUpLog.appending(note, on: date, to: existing)
        try await dataAPI
            .from("maintenance_issues")
            .update([
                "landlord_response": response,
                "follow_up_date": now,
                "updated_at": now
            ])
            .eq("id", value: id)
            .execute()
        return response
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
