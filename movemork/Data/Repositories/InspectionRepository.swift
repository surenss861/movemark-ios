//
//  InspectionRepository.swift
//  movemork
//
//  MoveMark — Inspection, evidence, and photo data access.
//  Evidence uploads use `{userId}/{propertyId}/move-in|move-out/{roomId}/...` under `inspection-media`.
//  Storage RLS matches `auth.uid()` to the first path segment **case-insensitively** (Swift UUID strings are often uppercase).
//

import Foundation
import os
import Supabase

private let inspectionRepoPhotoLog = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "movemork",
    category: "InspectionRepositoryPhotos"
)

/// Full row for reads (`select`). Do not use for `upsert` — only send columns that exist on `public.inspections`.
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

/// Insert-only payload for `inspections`. Do not send a random `id` on conflict updates — that breaks `inspection_items.inspection_id` FKs.
private struct InspectionInsertRow: Encodable {
    let id: UUID
    let propertyId: UUID
    let userId: UUID
    let inspectionType: String

    enum CodingKeys: String, CodingKey {
        case id
        case propertyId = "property_id"
        case userId = "user_id"
        case inspectionType = "inspection_type"
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

    /// Returns the stable `inspections.id` for `(property_id, user_id, inspection_type)`.
    /// Select-then-insert avoids upserting a new random `id` onto an existing row, which violates `inspection_items_inspection_id_fkey`.
    func upsertInspection(propertyId: UUID, userId: UUID, type: String) async throws -> UUID {
        let normalizedType = normalizedInspectionType(type)

        let existing: [InspectionRow] = try await supabase
            .from("inspections")
            .select()
            .eq("property_id", value: propertyId)
            .eq("user_id", value: userId)
            .eq("inspection_type", value: normalizedType)
            .limit(1)
            .execute()
            .value

        if let id = existing.first?.id {
            #if DEBUG
            print("upsertInspection reuse existing id:", id)
            #endif
            return id
        }

        #if DEBUG
        print("upsertInspection inserting new row type=\(normalizedType) propertyId=\(propertyId)")
        #endif

        let newId = UUID()
        let inserted: InspectionRow = try await supabase
            .from("inspections")
            .insert(
                InspectionInsertRow(
                    id: newId,
                    propertyId: propertyId,
                    userId: userId,
                    inspectionType: normalizedType
                )
            )
            .select()
            .single()
            .execute()
            .value

        #if DEBUG
        print("upsertInspection inserted new id:", inserted.id)
        #endif

        return inserted.id
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

    @discardableResult
    func insertEvidenceFile(propertyId: UUID, inspectionItemId: UUID?, maintenanceIssueId: UUID?, filePath: String, fileType: String, capturedAt: Date) async throws -> UUID {
        let row = EvidenceFileRow(
            id: UUID(),
            propertyId: propertyId,
            inspectionItemId: inspectionItemId,
            maintenanceIssueId: maintenanceIssueId,
            filePath: filePath,
            fileType: fileType,
            capturedAt: ISO8601DateFormatter().string(from: capturedAt)
        )

        let inserted: EvidenceFileRow = try await supabase
            .from("evidence_files")
            .insert(row)
            .select()
            .single()
            .execute()
            .value
        return inserted.id
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

    /// Best-effort removal when storage upload succeeded but `evidence_files` insert failed (avoids orphan objects).
    func removeOrphanInspectionUpload(path: String) async {
        guard !path.isEmpty else { return }
        _ = try? await supabase.storage
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
        try await MoveMarkSignedURLCache.shared.url(bucket: bucket, path: path) {
            try await supabase.storage
                .from(bucket)
                .createSignedURL(path: path, expiresIn: 86400)
        }
    }

    /// Appends photos to an existing inspection item (move-in or move-out). Uploads to storage and inserts evidence_files.
    func appendPhotosToInspectionItem(inspectionItemId: UUID, roomId: UUID, propertyId: UUID, userId: UUID, isMoveOut: Bool, photos: [Data]) async throws -> [EvidencePhoto] {
        let folder = isMoveOut ? "move-out" : "move-in"
        var added: [EvidencePhoto] = []
        added.reserveCapacity(photos.count)
        inspectionRepoPhotoLog.info(
            "appendPhotos start item=\(inspectionItemId.uuidString, privacy: .public) room=\(roomId.uuidString, privacy: .public) count=\(photos.count) folder=\(folder, privacy: .public)"
        )
        for (index, photoData) in photos.enumerated() {
            let path = "\(userId)/\(propertyId)/\(folder)/\(roomId)/\(UUID()).jpg"
            inspectionRepoPhotoLog.debug("append \(index + 1)/\(photos.count) bytes=\(photoData.count) path=\(path, privacy: .public)")
            do {
                _ = try await uploadPhoto(data: photoData, path: path)
                inspectionRepoPhotoLog.debug("append upload OK path=\(path, privacy: .public)")
            } catch {
                inspectionRepoPhotoLog.error(
                    "append uploadPhoto FAILED path=\(path, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
                )
                throw error
            }
            do {
                let fileId = try await insertEvidenceFile(
                    propertyId: propertyId,
                    inspectionItemId: inspectionItemId,
                    maintenanceIssueId: nil,
                    filePath: path,
                    fileType: "image",
                    capturedAt: Date()
                )
                added.append(EvidencePhoto(id: fileId, filePath: path))
                inspectionRepoPhotoLog.debug("append insertEvidenceFile OK fileId=\(fileId.uuidString, privacy: .public)")
            } catch {
                await removeOrphanInspectionUpload(path: path)
                inspectionRepoPhotoLog.error(
                    "append insertEvidenceFile FAILED path=\(path, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
                )
                throw error
            }
        }
        inspectionRepoPhotoLog.info("appendPhotos done item=\(inspectionItemId.uuidString, privacy: .public) added=\(added.count)")
        await MoveMarkSignedURLCache.shared.invalidateKeys(containing: propertyId.uuidString)
        return added
    }
}
