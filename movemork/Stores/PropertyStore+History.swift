//
//  PropertyStore+History.swift
//  movemork
//
//  Older evidence on demand. Snapshot v2 loads each room's newest entries and each entry's first photos;
//  these load the rest through keyset pages (newest-first entries, capture-order photos), so a rental with
//  years of proof never has to come down in one response — and none of it is ever hidden or capped.
//

import Foundation
import PostgREST

/// One row of `get_vault_summaries()`.
nonisolated struct VaultSummary: Decodable, Sendable {
    nonisolated struct LatestEvidence: Decodable, Sendable {
        let id: UUID
        let filePath: String
        let thumbnailPath: String?
        let maintenanceIssueId: UUID?

        enum CodingKeys: String, CodingKey {
            case id
            case filePath = "file_path"
            case thumbnailPath = "thumbnail_path"
            case maintenanceIssueId = "maintenance_issue_id"
        }
    }

    let propertyId: UUID
    let roomsTotal: Int
    let roomsDocumented: Int
    let latestEvidence: LatestEvidence?

    enum CodingKeys: String, CodingKey {
        case propertyId = "property_id"
        case roomsTotal = "rooms_total"
        case roomsDocumented = "rooms_documented"
        case latestEvidence = "latest_evidence"
    }
}

nonisolated private struct RoomEntriesPageParams: Encodable, Sendable {
    let p_room_id: UUID
    let p_inspection_type: String
    let p_before_created_at: String?
    let p_before_id: UUID?
    let p_limit: Int
}

nonisolated private struct EntryPhotosPageParams: Encodable, Sendable {
    let p_inspection_item_id: UUID
    let p_after_created_at: String?
    let p_after_id: UUID?
    let p_limit: Int
}

extension PropertyStore {
    /// Appends the next page of older entries for a room and stage, and moves them out of the room's
    /// unloaded remainder (so totals stay exactly what the server counted).
    @discardableResult
    func loadOlderEntries(roomID: UUID, moveOut: Bool, pageSize: Int = 30) async throws -> Bool {
        guard let room = currentProperty?.rooms.first(where: { $0.id == roomID }),
              room.hasOlderEntries(moveOut: moveOut) else { return false }
        let loaded = moveOut ? room.moveOutEvidence : room.evidence
        // Cursor: the oldest loaded entry, by the server's exact created_at (a parsed Date drops microseconds).
        // Entries saved in this session have no server timestamp yet; they are the newest, never the cursor.
        let oldest = loaded.filter { $0.serverCreatedAt != nil }
            .min { ($0.serverCreatedAt ?? "", $0.id.uuidString.lowercased()) < ($1.serverCreatedAt ?? "", $1.id.uuidString.lowercased()) }
        let page: RoomEntriesPage = try await dataAPI
            .rpc("get_room_entries_page", params: RoomEntriesPageParams(
                p_room_id: roomID,
                p_inspection_type: moveOut ? "move_out" : "move_in",
                p_before_created_at: oldest?.serverCreatedAt,
                p_before_id: oldest?.serverCreatedAt == nil ? nil : oldest?.id,
                p_limit: pageSize))
            .execute()
            .value

        let parts = Self.entryParts(page.entries)
        let older = page.inspectionItems.map { Self.evidenceRecord($0, parts: parts, stage: moveOut ? .moveOut : .moveIn) }
        guard var prop = currentProperty, let rIdx = prop.rooms.firstIndex(where: { $0.id == roomID }) else { return false }
        var target = prop.rooms[rIdx]
        let known = Set((moveOut ? target.moveOutEvidence : target.evidence).map(\.id))
        let fresh = older.filter { !known.contains($0.id) }
        let added = RoomRecord(name: "", evidence: fresh).moveInTotals
        var rest = (moveOut ? target.moveOutUnloaded : target.moveInUnloaded) ?? RoomRecord.StageTotals()
        rest.entries = max(rest.entries - added.entries, 0)
        rest.photos = max(rest.photos - added.photos, 0)
        rest.notedEntries = max(rest.notedEntries - added.notedEntries, 0)
        rest.issueTags = max(rest.issueTags - added.issueTags, 0)
        let remaining: RoomRecord.StageTotals? = page.hasMore && rest.entries > 0 ? rest : nil
        if moveOut {
            target.moveOutEvidence += fresh
            target.moveOutUnloaded = remaining
        } else {
            target.evidence += fresh
            target.moveInUnloaded = remaining
        }
        prop.rooms[rIdx] = target
        currentProperty = prop
        return page.hasMore
    }

    /// Loads every remaining photo of one entry (capture order), page by page.
    func loadAllPhotos(entryId: UUID, roomID: UUID, moveOut: Bool, pageSize: Int = 200) async throws {
        func entry() -> EvidenceRecord? {
            currentProperty?.rooms.first(where: { $0.id == roomID })
                .flatMap { (moveOut ? $0.moveOutEvidence : $0.evidence).first(where: { $0.id == entryId }) }
        }
        guard var photos = entry()?.photos, let total = entry()?.photoCount, photos.count < total else { return }
        var hasMore = true
        while hasMore && photos.count < total {
            let last = photos.last
            let page: EntryPhotosPage = try await dataAPI
                .rpc("get_entry_photos_page", params: EntryPhotosPageParams(
                    p_inspection_item_id: entryId,
                    p_after_created_at: last?.serverCreatedAt,
                    p_after_id: last?.serverCreatedAt == nil ? nil : last?.id,
                    p_limit: pageSize))
                .execute()
                .value
            let known = Set(photos.map(\.id))
            let fresh = page.evidenceFiles.map(Self.evidencePhoto).filter { !known.contains($0.id) }
            MoveMarkStoredFileURLs.remember(fresh)
            photos += fresh
            hasMore = page.hasMore && !page.evidenceFiles.isEmpty
        }
        guard var prop = currentProperty, let rIdx = prop.rooms.firstIndex(where: { $0.id == roomID }) else { return }
        if moveOut, let eIdx = prop.rooms[rIdx].moveOutEvidence.firstIndex(where: { $0.id == entryId }) {
            prop.rooms[rIdx].moveOutEvidence[eIdx].photos = photos
        } else if let eIdx = prop.rooms[rIdx].evidence.firstIndex(where: { $0.id == entryId }) {
            prop.rooms[rIdx].evidence[eIdx].photos = photos
        }
        currentProperty = prop
    }
}
