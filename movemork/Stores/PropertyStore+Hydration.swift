//
//  PropertyStore+Hydration.swift
//  movemork
//
//  Build PropertyRecord from backend rows; date/condition/notes helpers.
//

import Foundation
import Supabase

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

extension PropertyStore {

    /// Shared `yyyy-MM-dd` parser; `PropertyStore` is `@MainActor`, so this is not accessed concurrently across threads.
    static let dbDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Fetches the full property snapshot (rooms, inspections, items, evidence, tags, documents, maintenance) in one round trip via `get_property_snapshot`.
    func fetchPropertySnapshot(propertyId: UUID) async throws -> PropertySnapshot {
        try await supabase
            .rpc("get_property_snapshot", params: ["p_property_id": propertyId])
            .execute()
            .value
    }

    /// Loads rooms, docs, inspections, maintenance for one property and returns (PropertyRecord, maintenance log).
    /// Single round trip via `get_property_snapshot`; all grouping/parsing below is unchanged from the old per-table fetch path.
    func hydrateProperty(_ row: PropertyRow, userId: UUID) async throws -> (PropertyRecord, [MaintenanceRecord]) {
        let snapshot = try await fetchPropertySnapshot(propertyId: row.id)

        let rooms = snapshot.rooms
        let inspections = snapshot.inspections
        let docRows = snapshot.documents
        let issues = snapshot.maintenanceIssues
        let propertyEvidenceFiles = snapshot.evidenceFiles

        var maintenancePhotoCountByIssue: [UUID: Int] = [:]
        for file in propertyEvidenceFiles {
            if let mid = file.maintenanceIssueId {
                maintenancePhotoCountByIssue[mid, default: 0] += 1
            }
        }

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

        let moveInItemIds = Set(moveInItems.map(\.id))
        let moveOutItemIds = Set(moveOutItems.map(\.id))

        let moveInFiles = snapshot.evidenceFiles.filter { file in
            guard let itemId = file.inspectionItemId else { return false }
            return moveInItemIds.contains(itemId)
        }
        let moveOutFiles = snapshot.evidenceFiles.filter { file in
            guard let itemId = file.inspectionItemId else { return false }
            return moveOutItemIds.contains(itemId)
        }

        // Tags are flattened across the whole property; indexing by move-in/move-out item ids below
        // naturally scopes each side since item id sets don't overlap.
        var tagNamesByItem: [UUID: [String]] = [:]
        for entry in snapshot.itemTags {
            tagNamesByItem[entry.inspectionItemId, default: []].append(entry.name)
        }

        let moveInFilesSorted = moveInFiles.sorted {
            ($0.createdAt ?? $0.capturedAt ?? "") < ($1.createdAt ?? $1.capturedAt ?? "")
        }
        let moveOutFilesSorted = moveOutFiles.sorted {
            ($0.createdAt ?? $0.capturedAt ?? "") < ($1.createdAt ?? $1.capturedAt ?? "")
        }

        var moveInPhotosByItem: [UUID: [EvidencePhoto]] = [:]
        for file in moveInFilesSorted {
            guard let itemId = file.inspectionItemId else { continue }
            moveInPhotosByItem[itemId, default: []].append(EvidencePhoto(id: file.id, filePath: file.filePath, thumbnailPath: file.thumbnailPath))
        }
        var moveOutPhotosByItem: [UUID: [EvidencePhoto]] = [:]
        for file in moveOutFilesSorted {
            guard let itemId = file.inspectionItemId else { continue }
            moveOutPhotosByItem[itemId, default: []].append(EvidencePhoto(id: file.id, filePath: file.filePath, thumbnailPath: file.thumbnailPath))
        }

        let isoDate = ISO8601DateFormatter()
        let roomRecords = rooms.map { roomRow -> RoomRecord in
            var record = RoomRecord(id: roomRow.id, name: roomRow.name)
            let moveInForRoom = moveInItems.filter { $0.roomId == roomRow.id }
                .sorted { ($0.createdAt ?? "") > ($1.createdAt ?? "") }
            record.evidence = PropertyStore.dedupeEvidenceEntriesPreservingOrder(
                moveInForRoom.map { item in
                    let (title, notes) = Self.parseInspectionNotes(item.notes, defaultTitle: "Move-in capture")
                    let photos = moveInPhotosByItem[item.id] ?? []
                    return EvidenceRecord(
                        id: item.id,
                        title: title,
                        notes: notes,
                        issueTags: tagNamesByItem[item.id] ?? [],
                        condition: Self.conditionFromInt(item.conditionRating),
                        createdAt: isoDate.date(from: item.createdAt ?? "") ?? Date(),
                        photoCount: photos.count,
                        photos: photos,
                        stage: .moveIn
                    )
                }
            )
            let moveOutForRoom = moveOutItems.filter { $0.roomId == roomRow.id }
                .sorted { ($0.createdAt ?? "") > ($1.createdAt ?? "") }
            record.moveOutEvidence = PropertyStore.dedupeEvidenceEntriesPreservingOrder(
                moveOutForRoom.map { item in
                    let (title, notes) = Self.parseInspectionNotes(item.notes, defaultTitle: "Move-out capture")
                    let photos = moveOutPhotosByItem[item.id] ?? []
                    return EvidenceRecord(
                        id: item.id,
                        title: title,
                        notes: notes,
                        issueTags: tagNamesByItem[item.id] ?? [],
                        condition: Self.conditionFromInt(item.conditionRating),
                        createdAt: isoDate.date(from: item.createdAt ?? "") ?? Date(),
                        photoCount: photos.count,
                        photos: photos,
                        stage: .moveOut
                    )
                }
            )
            return record
        }

        let dateFormatter = ISO8601DateFormatter()
        let vaultDocTypes = Array(Set(docRows.map(\.documentType)))

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
                photoCount: maintenancePhotoCountByIssue[issueRow.id] ?? 0
            )
        }
        return (record, maintenance)
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
