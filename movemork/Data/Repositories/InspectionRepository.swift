//
//  InspectionRepository.swift
//  movemork
//
//  MoveMark — Inspection, evidence, and photo data access.
//

import Foundation
import Supabase

struct InspectionRow: Codable, Identifiable {
    let id: UUID
    let propertyId: UUID
    let userId: UUID
    var inspectionType: String
    var scheduledDate: String?
    var completedAt: String?
    var overallNotes: String?
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case propertyId = "property_id"
        case userId = "user_id"
        case inspectionType = "inspection_type"
        case scheduledDate = "scheduled_date"
        case completedAt = "completed_at"
        case overallNotes = "overall_notes"
        case createdAt = "created_at"
    }
}

struct InspectionItemRow: Codable, Identifiable {
    let id: UUID
    let inspectionId: UUID
    let roomId: UUID
    var notes: String?
    var conditionRating: Int?
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case inspectionId = "inspection_id"
        case roomId = "room_id"
        case notes
        case conditionRating = "condition_rating"
        case createdAt = "created_at"
    }
}

struct EvidenceFileRow: Codable, Identifiable {
    let id: UUID
    let propertyId: UUID
    var inspectionItemId: UUID?
    var maintenanceIssueId: UUID?
    var filePath: String
    var fileType: String
    var capturedAt: String?
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case propertyId = "property_id"
        case inspectionItemId = "inspection_item_id"
        case maintenanceIssueId = "maintenance_issue_id"
        case filePath = "file_path"
        case fileType = "file_type"
        case capturedAt = "captured_at"
        case createdAt = "created_at"
    }
}

struct InspectionItemTagRow: Codable {
    let inspectionItemId: UUID
    let issueTagId: UUID

    enum CodingKeys: String, CodingKey {
        case inspectionItemId = "inspection_item_id"
        case issueTagId = "issue_tag_id"
    }
}

struct IssueTagRow: Codable, Identifiable {
    let id: UUID
    let name: String
}

struct InspectionRepository {

    /// DB check constraint expects snake_case values.
    private func normalizedInspectionType(_ raw: String) -> String {
        switch raw.lowercased() {
        case "move-in", "move_in", "movein":
            return "move_in"
        case "move-out", "move_out", "moveout":
            return "move_out"
        default:
            return raw
        }
    }

    func upsertInspection(propertyId: UUID, userId: UUID, type: String) async throws -> UUID {
        let row = InspectionRow(
            id: UUID(),
            propertyId: propertyId,
            userId: userId,
            inspectionType: normalizedInspectionType(type)
        )

        let result: InspectionRow = try await supabase
            .from("inspections")
            .upsert(row, onConflict: "property_id,user_id,inspection_type")
            .select()
            .single()
            .execute()
            .value

        return result.id
    }

    func insertInspectionItem(inspectionId: UUID, roomId: UUID, notes: String, conditionRating: Int) async throws -> UUID {
        let row = InspectionItemRow(
            id: UUID(),
            inspectionId: inspectionId,
            roomId: roomId,
            notes: notes,
            conditionRating: conditionRating
        )

        let result: InspectionItemRow = try await supabase
            .from("inspection_items")
            .insert(row)
            .select()
            .single()
            .execute()
            .value

        return result.id
    }

    func insertEvidenceFile(propertyId: UUID, inspectionItemId: UUID?, maintenanceIssueId: UUID?, filePath: String, fileType: String, capturedAt: Date) async throws {
        let row = EvidenceFileRow(
            id: UUID(),
            propertyId: propertyId,
            inspectionItemId: inspectionItemId,
            maintenanceIssueId: maintenanceIssueId,
            filePath: filePath,
            fileType: fileType,
            capturedAt: ISO8601DateFormatter().string(from: capturedAt)
        )

        try await supabase
            .from("evidence_files")
            .insert(row)
            .execute()
    }

    func fetchEvidenceFiles(propertyId: UUID) async throws -> [EvidenceFileRow] {
        try await supabase
            .from("evidence_files")
            .select()
            .eq("property_id", value: propertyId)
            .execute()
            .value
    }

    func insertItemTags(inspectionItemId: UUID, tagNames: [String]) async throws {
        guard !tagNames.isEmpty else { return }

        let tags: [IssueTagRow] = try await supabase
            .from("issue_tags")
            .select()
            .in("name", values: tagNames)
            .execute()
            .value

        let links = tags.map { tag in
            InspectionItemTagRow(inspectionItemId: inspectionItemId, issueTagId: tag.id)
        }

        if !links.isEmpty {
            try await supabase
                .from("inspection_item_tags")
                .insert(links)
                .execute()
        }
    }

    func deleteItemTagsForInspectionItem(inspectionItemId: UUID) async throws {
        try await supabase
            .from("inspection_item_tags")
            .delete()
            .eq("inspection_item_id", value: inspectionItemId)
            .execute()
    }

    /// Bucket used for inspection/evidence photos (move-in and move-out).
    private static let evidenceStorageBucket = "inspection-media"

    /// Removes a file from evidence storage. No-op if path is empty.
    private func removeEvidenceFileFromStorage(path: String) async throws {
        guard !path.isEmpty else { return }
        try await supabase.storage
            .from(Self.evidenceStorageBucket)
            .remove(paths: [path])
    }

    /// Deletes evidence file rows for an inspection item and removes each file from storage first.
    func deleteEvidenceFilesForInspectionItem(inspectionItemId: UUID) async throws {
        let rows: [EvidenceFileRow] = try await supabase
            .from("evidence_files")
            .select()
            .eq("inspection_item_id", value: inspectionItemId)
            .execute()
            .value
        for row in rows {
            try? await removeEvidenceFileFromStorage(path: row.filePath)
        }
        try await supabase
            .from("evidence_files")
            .delete()
            .eq("inspection_item_id", value: inspectionItemId)
            .execute()
    }

    func deleteInspectionItem(id: UUID) async throws {
        try await deleteEvidenceFilesForInspectionItem(inspectionItemId: id)
        try await deleteItemTagsForInspectionItem(inspectionItemId: id)
        try await supabase
            .from("inspection_items")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    func updateInspectionItem(id: UUID, notes: String?, conditionRating: Int?) async throws {
        struct Patch: Encodable {
            let notes: String?
            let condition_rating: Int?
            enum CodingKeys: String, CodingKey { case notes; case condition_rating }
        }
        let patch = Patch(notes: notes, condition_rating: conditionRating)
        try await supabase
            .from("inspection_items")
            .update(patch)
            .eq("id", value: id)
            .execute()
    }

    func fetchInspections(propertyId: UUID) async throws -> [InspectionRow] {
        try await supabase
            .from("inspections")
            .select()
            .eq("property_id", value: propertyId)
            .execute()
            .value
    }

    func fetchAllInspectionItems(inspectionIds: [UUID]) async throws -> [InspectionItemRow] {
        guard !inspectionIds.isEmpty else { return [] }
        return try await supabase
            .from("inspection_items")
            .select()
            .in("inspection_id", values: inspectionIds)
            .execute()
            .value
    }

    func fetchEvidenceFilesByItems(itemIds: [UUID]) async throws -> [EvidenceFileRow] {
        guard !itemIds.isEmpty else { return [] }
        return try await supabase
            .from("evidence_files")
            .select()
            .in("inspection_item_id", values: itemIds)
            .execute()
            .value
    }

    /// Returns tag names per inspection item id for building evidence entries.
    func fetchItemTagNames(inspectionItemIds: [UUID]) async throws -> [UUID: [String]] {
        guard !inspectionItemIds.isEmpty else { return [:] }
        let links: [InspectionItemTagRow] = try await supabase
            .from("inspection_item_tags")
            .select()
            .in("inspection_item_id", values: inspectionItemIds)
            .execute()
            .value
        let tagIds = Set(links.map(\.issueTagId))
        guard !tagIds.isEmpty else { return [:] }
        let tags: [IssueTagRow] = try await supabase
            .from("issue_tags")
            .select()
            .in("id", values: Array(tagIds))
            .execute()
            .value
        let tagNameById = Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0.name) })
        var result: [UUID: [String]] = [:]
        for link in links {
            if let name = tagNameById[link.issueTagId] {
                result[link.inspectionItemId, default: []].append(name)
            }
        }
        return result
    }

    func fetchEvidenceFilesByMaintenanceIssue(issueId: UUID) async throws -> [EvidenceFileRow] {
        try await supabase
            .from("evidence_files")
            .select()
            .eq("maintenance_issue_id", value: issueId)
            .execute()
            .value
    }

    func uploadPhoto(data: Data, path: String) async throws -> String {
        try await supabase.storage
            .from("inspection-media")
            .upload(path, data: data, options: FileOptions(contentType: "image/jpeg"))

        return path
    }

    func signedURL(bucket: String, path: String) async throws -> URL {
        try await supabase.storage
            .from(bucket)
            .createSignedURL(path: path, expiresIn: 3600)
    }

    /// Appends photos to an existing inspection item (move-in or move-out). Uploads to storage and inserts evidence_files.
    func appendPhotosToInspectionItem(inspectionItemId: UUID, roomId: UUID, propertyId: UUID, userId: UUID, isMoveOut: Bool, photos: [Data]) async throws {
        let folder = isMoveOut ? "move-out" : "move-in"
        for photoData in photos {
            let path = "\(userId)/\(propertyId)/\(folder)/\(roomId)/\(UUID()).jpg"
            _ = try await uploadPhoto(data: photoData, path: path)
            try await insertEvidenceFile(
                propertyId: propertyId,
                inspectionItemId: inspectionItemId,
                maintenanceIssueId: nil,
                filePath: path,
                fileType: "image/jpeg",
                capturedAt: Date()
            )
        }
    }
}
