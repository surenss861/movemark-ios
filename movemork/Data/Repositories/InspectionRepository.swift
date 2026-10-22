//
//  InspectionRepository.swift
//  movemork
//
//  MoveMark — Inspection, evidence, and photo data access.
//  Evidence files live in `inspection-media` under keys the MoveMark API builds
//  (`{userId}/{propertyId}/move-in|move-out/{roomId}/{uuid}.jpg`, lowercase); the app records the returned
//  path in `evidence_files` and never chooses or deletes keys itself. Older rows may hold uppercase ids.
//

import Foundation
import os
import PostgREST
import UIKit

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
    /// Small (~320px) JPEG uploaded alongside `filePath` at capture time; `nil` for rows captured before this existed (fall back to `filePath`).
    var thumbnailPath: String? = nil
    var fileType: String
    /// From the source's own metadata when it has any (declared, not verified); else upload time.
    var capturedAt: String?
    /// When MoveMark received it — set by the database, never by the app.
    var createdAt: String?
    /// The immutable source object. Its hash, size, type and dimensions are filled in by the database
    /// from the finalized upload ticket; the app never sends them.
    var sourcePath: String? = nil
    var sourceSha256: String? = nil

    enum CodingKeys: String, CodingKey {
        case id
        case propertyId = "property_id"
        case inspectionItemId = "inspection_item_id"
        case maintenanceIssueId = "maintenance_issue_id"
        case filePath = "file_path"
        case thumbnailPath = "thumbnail_path"
        case fileType = "file_type"
        case capturedAt = "captured_at"
        case createdAt = "created_at"
        case sourcePath = "source_path"
        case sourceSha256 = "source_sha256"
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

    private func findInspection(propertyId: UUID, userId: UUID, normalizedType: String) async throws -> InspectionRow? {
        let existing: [InspectionRow] = try await dataAPI
            .from("inspections")
            .select()
            .eq("property_id", value: propertyId)
            .eq("user_id", value: userId)
            .eq("inspection_type", value: normalizedType)
            .limit(1)
            .execute()
            .value
        return existing.first
    }

    /// Returns the stable `inspections.id` for `(property_id, user_id, inspection_type)`.
    /// Select-then-insert avoids upserting a new random `id` onto an existing row, which violates `inspection_items_inspection_id_fkey`.
    func upsertInspection(propertyId: UUID, userId: UUID, type: String) async throws -> UUID {
        let normalizedType = normalizedInspectionType(type)

        if let id = try await findInspection(propertyId: propertyId, userId: userId, normalizedType: normalizedType)?.id {
            #if DEBUG
            print("upsertInspection reuse existing id:", id)
            #endif
            return id
        }

        #if DEBUG
        print("upsertInspection inserting new row type=\(normalizedType) propertyId=\(propertyId)")
        #endif

        let newId = UUID()
        do {
            let inserted: InspectionRow = try await dataAPI
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
        } catch {
            // A concurrent call (second device, retried request) may have inserted the same
            // (property_id, user_id, inspection_type) row between our select and insert; the DB's
            // unique index rejects ours. Re-select the winner instead of surfacing a spurious
            // error or (worse) creating a duplicate inspections row.
            if let winner = try await findInspection(propertyId: propertyId, userId: userId, normalizedType: normalizedType)?.id {
                #if DEBUG
                print("upsertInspection lost race, reusing winner id:", winner)
                #endif
                return winner
            }
            throw error
        }
    }

    func insertInspectionItem(inspectionId: UUID, roomId: UUID, notes: String, conditionRating: Int) async throws -> UUID {
        let row = InspectionItemRow(
            id: UUID(),
            inspectionId: inspectionId,
            roomId: roomId,
            notes: notes,
            conditionRating: conditionRating
        )

        let result: InspectionItemRow = try await dataAPI
            .from("inspection_items")
            .insert(row)
            .select()
            .single()
            .execute()
            .value

        return result.id
    }

    @discardableResult
    func insertEvidenceFile(id: UUID = UUID(), propertyId: UUID, inspectionItemId: UUID?, maintenanceIssueId: UUID?, filePath: String, thumbnailPath: String? = nil, sourcePath: String? = nil, fileType: String, capturedAt: Date) async throws -> UUID {
        let row = EvidenceFileRow(
            id: id,
            propertyId: propertyId,
            inspectionItemId: inspectionItemId,
            maintenanceIssueId: maintenanceIssueId,
            filePath: filePath,
            thumbnailPath: thumbnailPath,
            fileType: fileType,
            capturedAt: ISO8601DateFormatter().string(from: capturedAt),
            sourcePath: sourcePath
        )

        let inserted: EvidenceFileRow = try await dataAPI
            .from("evidence_files")
            .insert(row)
            .select()
            .single()
            .execute()
            .value
        return inserted.id
    }

    func fetchEvidenceFiles(propertyId: UUID) async throws -> [EvidenceFileRow] {
        try await dataAPI
            .from("evidence_files")
            .select()
            .eq("property_id", value: propertyId)
            .execute()
            .value
    }

    /// Single most-recent evidence file for a property (e.g. vault card hero preview) — avoids fetching every evidence row just to use `.first`.
    func fetchFirstEvidenceFile(propertyId: UUID) async throws -> EvidenceFileRow? {
        let rows: [EvidenceFileRow] = try await dataAPI
            .from("evidence_files")
            .select()
            .eq("property_id", value: propertyId)
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    func insertItemTags(inspectionItemId: UUID, tagNames: [String]) async throws {
        guard !tagNames.isEmpty else { return }

        let tags: [IssueTagRow] = try await dataAPI
            .from("issue_tags")
            .select()
            .in("name", values: tagNames)
            .execute()
            .value

        let links = tags.map { tag in
            InspectionItemTagRow(inspectionItemId: inspectionItemId, issueTagId: tag.id)
        }

        if !links.isEmpty {
            try await dataAPI
                .from("inspection_item_tags")
                .insert(links)
                .execute()
        }
    }

    func deleteItemTagsForInspectionItem(inspectionItemId: UUID) async throws {
        try await dataAPI
            .from("inspection_item_tags")
            .delete()
            .eq("inspection_item_id", value: inspectionItemId)
            .execute()
    }

    /// Releases an upload whose `evidence_files` insert failed. Safe even if the insert actually committed:
    /// the API keeps any object a row references.
    func abandonUpload(_ upload: MoveMarkUpload) async {
        await MoveMarkStorageService.shared.abandon(upload)
    }

    /// Deletes evidence rows for an inspection item together with their files (server-side, by row id).
    func deleteEvidenceFilesForInspectionItem(inspectionItemId: UUID) async throws {
        let rows: [EvidenceFileRow] = try await dataAPI
            .from("evidence_files")
            .select()
            .eq("inspection_item_id", value: inspectionItemId)
            .execute()
            .value
        try await MoveMarkStorageService.shared.deleteEvidence(ids: rows.map(\.id))
    }

    func deleteInspectionItem(id: UUID) async throws {
        try await deleteEvidenceFilesForInspectionItem(inspectionItemId: id)
        try await deleteItemTagsForInspectionItem(inspectionItemId: id)
        try await dataAPI
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
        try await dataAPI
            .from("inspection_items")
            .update(patch)
            .eq("id", value: id)
            .execute()
    }

    func fetchInspections(propertyId: UUID) async throws -> [InspectionRow] {
        try await dataAPI
            .from("inspections")
            .select()
            .eq("property_id", value: propertyId)
            .execute()
            .value
    }

    func fetchAllInspectionItems(inspectionIds: [UUID]) async throws -> [InspectionItemRow] {
        guard !inspectionIds.isEmpty else { return [] }
        return try await dataAPI
            .from("inspection_items")
            .select()
            .in("inspection_id", values: inspectionIds)
            .execute()
            .value
    }

    func fetchEvidenceFilesByItems(itemIds: [UUID]) async throws -> [EvidenceFileRow] {
        guard !itemIds.isEmpty else { return [] }
        return try await dataAPI
            .from("evidence_files")
            .select()
            .in("inspection_item_id", values: itemIds)
            .execute()
            .value
    }

    /// Returns tag names per inspection item id for building evidence entries.
    func fetchItemTagNames(inspectionItemIds: [UUID]) async throws -> [UUID: [String]] {
        guard !inspectionItemIds.isEmpty else { return [:] }
        let links: [InspectionItemTagRow] = try await dataAPI
            .from("inspection_item_tags")
            .select()
            .in("inspection_item_id", values: inspectionItemIds)
            .execute()
            .value
        let tagIds = Set(links.map(\.issueTagId))
        guard !tagIds.isEmpty else { return [:] }
        let tags: [IssueTagRow] = try await dataAPI
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
        try await dataAPI
            .from("evidence_files")
            .select()
            .eq("maintenance_issue_id", value: issueId)
            .execute()
            .value
    }

    /// Uploads one piece of room evidence: the immutable source, its working derivative and thumbnail,
    /// verified and finalized by the API. Insert the row with the returned paths.
    func uploadEvidence(_ source: MMEvidenceSource, propertyId: UUID, roomId: UUID, isMoveOut: Bool) async throws -> MoveMarkUpload {
        try await MoveMarkStorageService.shared.uploadEvidence(source, propertyId: propertyId, roomId: roomId, isMoveOut: isMoveOut)
    }

    /// Temporary download URL for a stored evidence path (original or thumbnail).
    func signedURL(bucket: String, path: String) async throws -> URL {
        try await MoveMarkStoredFileURLs.evidenceURL(bucket: bucket, path: path)
    }

    /// Upload → row pipeline for photos of one inspection item (new entry or append). See ``MMEvidenceSaver``.
    func evidenceSaver(inspectionItemId: UUID, roomId: UUID, propertyId: UUID, isMoveOut: Bool) -> MMEvidenceSaver {
        MMEvidenceSaver(
            upload: { source in
                try await MoveMarkStorageService.shared.uploadEvidence(source, propertyId: propertyId, roomId: roomId, isMoveOut: isMoveOut)
            },
            insert: { rowId, upload in
                try await InspectionRepository().insertEvidenceFile(
                    id: rowId,
                    propertyId: propertyId,
                    inspectionItemId: inspectionItemId,
                    maintenanceIssueId: nil,
                    filePath: upload.path,
                    thumbnailPath: upload.thumbnailPath,
                    sourcePath: upload.sourcePath,
                    fileType: "image",
                    capturedAt: upload.capturedAt ?? Date()
                )
            },
            abandon: { await MoveMarkStorageService.shared.abandon($0) }
        )
    }

    /// Adds photos to an existing inspection item (move-in or move-out), photo by photo. Photos that
    /// didn't make it come back as `pending`; the ones that did are never re-sent.
    func appendPhotosToInspectionItem(inspectionItemId: UUID, roomId: UUID, propertyId: UUID, isMoveOut: Bool, photos: [MMPendingEvidence]) async -> MMEvidenceSaveResult {
        inspectionRepoPhotoLog.info(
            "appendPhotos start item=\(inspectionItemId.uuidString, privacy: .public) room=\(roomId.uuidString, privacy: .public) count=\(photos.count)"
        )
        let result = await evidenceSaver(inspectionItemId: inspectionItemId, roomId: roomId, propertyId: propertyId, isMoveOut: isMoveOut)
            .save(photos)
        inspectionRepoPhotoLog.info(
            "appendPhotos done item=\(inspectionItemId.uuidString, privacy: .public) saved=\(result.saved.count) pending=\(result.pending.count) unresolved=\(result.pending.filter { $0.unresolved != nil }.count)"
        )
        if !result.saved.isEmpty {
            await MoveMarkSignedURLCache.shared.invalidateKeys(containing: propertyId.uuidString)
        }
        return result
    }
}
