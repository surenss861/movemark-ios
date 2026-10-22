//
//  PropertyStore+Hydration.swift
//  movemork
//
//  Build PropertyRecord from backend rows; date/condition/notes helpers.
//

import Foundation
import OSLog
import PostgREST

/// Decoded shape of `public.get_property_snapshot(p_property_id)` — one round trip replacing the
/// ~11 sequential/parallel `.select()` calls `hydrateProperty` used to make. Every array element reuses
/// the same Codable row structs the old per-table fetches decoded, since the RPC returns `to_jsonb(row)`
/// for each table with identical snake_case columns.
struct PropertySnapshot: Decodable {
    /// Row for the entity flattening `inspection_item_tags` joined to `issue_tags`, matching the RPC's `item_tags` array.
    struct ItemTagEntry: Decodable {
        let inspectionItemId: UUID
        let name: String

        enum CodingKeys: String, CodingKey {
            case inspectionItemId = "inspection_item_id"
            case name
        }
    }

    let property: PropertyRow?
    let rooms: [RoomRow]
    let inspections: [InspectionRow]
    let inspectionItems: [InspectionItemRow]
    let evidenceFiles: [EvidenceFileRow]
    let itemTags: [ItemTagEntry]
    let documents: [PropertyDocumentRow]
    let maintenanceIssues: [MaintenanceIssueRow]

    enum CodingKeys: String, CodingKey {
        case property
        case rooms
        case inspections
        case inspectionItems = "inspection_items"
        case evidenceFiles = "evidence_files"
        case itemTags = "item_tags"
        case documents
        case maintenanceIssues = "maintenance_issues"
    }
}

/// Decoded shape of `public.get_property_snapshot_v2` (migration 0990): all rooms with true per-stage totals,
/// the newest entries per room and stage with their true photo counts and first photos, newest documents and
/// maintenance with totals. Older entries and remaining photos load through the page functions.
struct PropertySnapshotV2: Decodable {
    struct StageStats: Decodable {
        let entries: Int
        let photos: Int
        let entriesWithNotes: Int
        let issueTags: Int
        let latestAt: String?

        enum CodingKeys: String, CodingKey {
            case entries, photos
            case entriesWithNotes = "entries_with_notes"
            case issueTags = "issue_tags"
            case latestAt = "latest_at"
        }
    }

    /// A `rooms` row plus its `stats` object (keyed by inspection type).
    struct RoomWithStats: Decodable {
        let row: RoomRow
        let stats: [String: StageStats]

        private enum Keys: String, CodingKey { case stats }

        init(from decoder: Decoder) throws {
            row = try RoomRow(from: decoder)
            stats = try decoder.container(keyedBy: Keys.self).decodeIfPresent([String: StageStats].self, forKey: .stats) ?? [:]
        }
    }

    /// The entries payload shared by the snapshot and `get_room_entries_page`.
    struct Entries: Decodable {
        let photoCounts: [String: Int]
        let evidenceFiles: [EvidenceFileRow]
        let itemTags: [PropertySnapshot.ItemTagEntry]

        enum CodingKeys: String, CodingKey {
            case photoCounts = "photo_counts"
            case evidenceFiles = "evidence_files"
            case itemTags = "item_tags"
        }
    }

    let property: PropertyRow?
    let rooms: [RoomWithStats]
    let inspections: [InspectionRow]
    let inspectionItems: [InspectionItemRow]
    let entries: Entries
    let documents: [PropertyDocumentRow]
    let documentTypes: [String]
    let maintenanceIssues: [MaintenanceIssueRow]
    let maintenancePhotoCounts: [String: Int]

    enum CodingKeys: String, CodingKey {
        case property, rooms, inspections, entries, documents
        case inspectionItems = "inspection_items"
        case documentTypes = "document_types"
        case maintenanceIssues = "maintenance_issues"
        case maintenancePhotoCounts = "maintenance_photo_counts"
    }
}

/// One page of `get_room_entries_page`.
struct RoomEntriesPage: Decodable {
    let inspectionItems: [InspectionItemRow]
    let entries: PropertySnapshotV2.Entries
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case entries
        case inspectionItems = "inspection_items"
        case hasMore = "has_more"
    }
}

/// One page of `get_entry_photos_page`.
struct EntryPhotosPage: Decodable {
    let evidenceFiles: [EvidenceFileRow]
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case evidenceFiles = "evidence_files"
        case hasMore = "has_more"
    }
}

extension PropertyStore {
    fileprivate static let hydrationSignposter = OSSignposter(
        subsystem: Bundle.main.bundleIdentifier ?? "MoveMark",
        category: "PropertyHydration"
    )
    fileprivate static let hydrationLog = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "MoveMark",
        category: "PropertyHydration"
    )


    /// Shared `yyyy-MM-dd` parser; `PropertyStore` is `@MainActor`, so this is not accessed concurrently across threads.
    static let dbDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Fetches the bounded property snapshot (rooms with totals, newest entries and their first photos,
    /// documents, maintenance) in one round trip via `get_property_snapshot_v2`.
    func fetchPropertySnapshot(propertyId: UUID) async throws -> PropertySnapshotV2 {
        try await dataAPI
            .rpc("get_property_snapshot_v2", params: ["p_property_id": propertyId])
            .execute()
            .value
    }

    /// Loads rooms, docs, inspections, maintenance for one property and returns (PropertyRecord, maintenance log).
    /// Single round trip via `get_property_snapshot`; all grouping/parsing below is unchanged from the old per-table fetch path.
    func hydrateProperty(_ row: PropertyRow, userId: UUID) async throws -> (PropertyRecord, [MaintenanceRecord]) {
        // Paired with the snapshot-cache signposts so one Instruments trace shows local read and
        // remote refresh on the same timeline. Instrumentation only — no behaviour change.
        let hydrationState = Self.hydrationSignposter.beginInterval("remote_hydration")
        let hydrationClock = ContinuousClock()
        let hydrationStart = hydrationClock.now
        defer {
            Self.hydrationSignposter.endInterval("remote_hydration", hydrationState)
            let ms = Int(hydrationStart.duration(to: hydrationClock.now) / .milliseconds(1))
            Self.hydrationLog.debug("remote_hydration \(ms, privacy: .public)ms")
        }

        let snapshot = try await fetchPropertySnapshot(propertyId: row.id)

        let rooms = snapshot.rooms
        let inspections = snapshot.inspections
        let issues = snapshot.maintenanceIssues

        // Support both legacy kebab-case and current snake_case values.
        let moveInIds = Set(inspections.filter {
            let normalized = $0.inspectionType.lowercased()
            return normalized == "move_in" || normalized == "move-in" || normalized == "movein"
        }.map(\.id))
        let moveOutIds = Set(inspections.filter {
            let normalized = $0.inspectionType.lowercased()
            return normalized == "move_out" || normalized == "move-out" || normalized == "moveout"
        }.map(\.id))

        let moveInItems = snapshot.inspectionItems.filter { moveInIds.contains($0.inspectionId) }
        let moveOutItems = snapshot.inspectionItems.filter { moveOutIds.contains($0.inspectionId) }

        let entryParts = Self.entryParts(snapshot.entries)
        for document in snapshot.documents {
            MoveMarkStoredFileURLs.remember(rowId: document.id, filePath: document.filePath, thumbnailPath: document.thumbnailPath)
        }

        let roomRecords = rooms.map { roomRow -> RoomRecord in
            var record = RoomRecord(id: roomRow.row.id, name: roomRow.row.name)
            let moveInForRoom = moveInItems.filter { $0.roomId == roomRow.row.id }
                .sorted { ($0.createdAt ?? "") > ($1.createdAt ?? "") }
            record.evidence = PropertyStore.dedupeEvidenceEntriesPreservingOrder(
                moveInForRoom.map { Self.evidenceRecord($0, parts: entryParts, stage: .moveIn) }
            )
            let moveOutForRoom = moveOutItems.filter { $0.roomId == roomRow.row.id }
                .sorted { ($0.createdAt ?? "") > ($1.createdAt ?? "") }
            record.moveOutEvidence = PropertyStore.dedupeEvidenceEntriesPreservingOrder(
                moveOutForRoom.map { Self.evidenceRecord($0, parts: entryParts, stage: .moveOut) }
            )
            // Server totals minus what is loaded = what loads on demand.
            record.moveInUnloaded = Self.unloaded(roomRow.stats["move_in"], loaded: record.evidence)
            record.moveOutUnloaded = Self.unloaded(roomRow.stats["move_out"], loaded: record.moveOutEvidence)
            return record
        }

        let dateFormatter = ISO8601DateFormatter()
        // All document types present (the document rows themselves are bounded to the newest 100).
        let vaultDocTypes = snapshot.documentTypes

        let moveInParsed = row.moveInDate.flatMap { Self.dbDateFormatter.date(from: $0) }
            ?? row.moveInDate.flatMap { dateFormatter.date(from: $0) }
        let leaseStartParsed = row.leaseStart.flatMap { Self.dbDateFormatter.date(from: $0) }
        let leaseEndParsed = row.leaseEnd.flatMap { Self.dbDateFormatter.date(from: $0) }
            ?? row.leaseEnd.flatMap { dateFormatter.date(from: $0) }

        let record = PropertyRecord(
            id: row.id,
            title: row.title,
            addressLine1: row.addressLine1,
            addressLine2: row.addressLine2 ?? "",
            city: row.city,
            provinceState: row.provinceState,
            postalCode: row.postalCode,
            landlordName: row.landlordName ?? "",
            landlordEmail: row.landlordEmail ?? "",
            landlordPhone: row.landlordPhone ?? "",
            moveInDate: moveInParsed ?? Date(),
            leaseStartDate: leaseStartParsed,
            leaseEndDate: leaseEndParsed ?? Calendar.current.date(byAdding: .year, value: 1, to: moveInParsed ?? Date()) ?? Date(),
            depositAmount: row.depositAmount.map { String(format: "$%.2f", $0) } ?? "",
            rentAmount: row.rentAmount.map { String(format: "$%.2f", $0) } ?? "",
            country: row.country,
            rooms: roomRecords,
            vaultDocuments: vaultDocTypes
        )

        let maintenance = issues.map { issueRow in
            MaintenanceRecord(
                id: issueRow.id,
                title: issueRow.title,
                category: issueRow.category ?? "General",
                details: issueRow.description ?? "",
                status: issueRow.status == "resolved" ? .resolved : (issueRow.status == "follow_up" ? .followUp : .open),
                landlordResponse: issueRow.landlordResponse ?? "",
                photoCount: snapshot.maintenancePhotoCounts[issueRow.id.uuidString.lowercased()] ?? 0
            )
        }
        return (record, maintenance)
    }

    /// Photos (capture order) and tags of the loaded entries, plus each entry's true photo count.
    struct EntryParts {
        var photosByItem: [UUID: [EvidencePhoto]] = [:]
        var tagsByItem: [UUID: [String]] = [:]
        var photoCountByItem: [String: Int] = [:]
    }

    static func entryParts(_ entries: PropertySnapshotV2.Entries) -> EntryParts {
        var parts = EntryParts(photoCountByItem: entries.photoCounts)
        for file in entries.evidenceFiles {  // already in capture order (created_at, id)
            guard let itemId = file.inspectionItemId else { continue }
            parts.photosByItem[itemId, default: []].append(Self.evidencePhoto(file))
        }
        MoveMarkStoredFileURLs.remember(parts.photosByItem.values.flatMap { $0 })
        for tag in entries.itemTags {
            parts.tagsByItem[tag.inspectionItemId, default: []].append(tag.name)
        }
        return parts
    }

    static func evidencePhoto(_ file: EvidenceFileRow) -> EvidencePhoto {
        EvidencePhoto(id: file.id, filePath: file.filePath, thumbnailPath: file.thumbnailPath, serverCreatedAt: file.createdAt)
    }

    static func evidenceRecord(_ item: InspectionItemRow, parts: EntryParts, stage: EvidenceRecord.Stage) -> EvidenceRecord {
        let (title, notes) = parseInspectionNotes(item.notes, defaultTitle: stage == .moveOut ? "Move-out capture" : "Move-in capture")
        let photos = parts.photosByItem[item.id] ?? []
        var record = EvidenceRecord(
            id: item.id,
            title: title,
            notes: notes,
            issueTags: parts.tagsByItem[item.id] ?? [],
            condition: conditionFromInt(item.conditionRating),
            createdAt: serverDate(item.createdAt) ?? Date(),
            photoCount: parts.photoCountByItem[item.id.uuidString.lowercased()] ?? photos.count,
            photos: photos,
            stage: stage
        )
        record.serverCreatedAt = item.createdAt
        return record
    }

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoPlain = ISO8601DateFormatter()

    /// Postgres timestamptz as JSON (`2026-10-22T09:15:01.24133+00:00`). A plain ISO8601DateFormatter can't
    /// read the fraction, so the fraction is normalized to milliseconds first.
    static func serverDate(_ raw: String?) -> Date? {
        guard var text = raw, !text.isEmpty else { return nil }
        if let dot = text.firstIndex(of: "."),
           let zone = text[dot...].firstIndex(where: { $0 == "+" || $0 == "-" || $0 == "Z" }) {
            let fraction = text[text.index(after: dot)..<zone]
            text = String(text[..<dot]) + "." + String((fraction + "000").prefix(3)) + String(text[zone...])
        }
        return isoFractional.date(from: text) ?? isoPlain.date(from: text)
    }

    /// What the server counted for a room/stage beyond the loaded entries; nil when everything is loaded.
    static func unloaded(_ stats: PropertySnapshotV2.StageStats?, loaded: [EvidenceRecord]) -> RoomRecord.StageTotals? {
        guard let stats else { return nil }
        let have = RoomRecord(name: "", evidence: loaded).moveInTotals
        let rest = RoomRecord.StageTotals(
            entries: max(stats.entries - have.entries, 0),
            photos: max(stats.photos - have.photos, 0),
            notedEntries: max(stats.entriesWithNotes - have.notedEntries, 0),
            issueTags: max(stats.issueTags - have.issueTags, 0),
            latestAt: nil  // the newest entries are always the loaded ones
        )
        return rest.entries == 0 ? nil : rest
    }

    private static func conditionFromInt(_ value: Int?) -> RoomRecord.ConditionRating {
        switch value {
        case 5: return .excellent
        case 4: return .good
        case 3: return .fair
        case 2: return .belowFair
        case 1: return .poor
        default: return .good
        }
    }

    /// Parses inspection item notes stored as "title\nnotes" (from addEvidence).
    private static func parseInspectionNotes(_ notes: String?, defaultTitle: String) -> (title: String, notes: String) {
        let raw = notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if raw.isEmpty { return (defaultTitle, "") }
        if let idx = raw.firstIndex(of: "\n") {
            let title = String(raw[..<idx]).trimmingCharacters(in: .whitespacesAndNewlines)
            let rest = String(raw[raw.index(after: idx)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return (title.isEmpty ? defaultTitle : title, rest)
        }
        return (raw, "")
    }
}
