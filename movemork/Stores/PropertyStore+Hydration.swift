//
//  PropertyStore+Hydration.swift
//  movemork
//
//  Build PropertyRecord from backend rows; date/condition/notes helpers.
//

import Foundation

extension PropertyStore {

    static var dbDateFormatter: DateFormatter {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }

    /// Loads rooms, docs, inspections, maintenance for one property and returns (PropertyRecord, maintenance log).
    func hydrateProperty(_ row: PropertyRow, userId: UUID) async throws -> (PropertyRecord, [MaintenanceRecord]) {
        let rooms = try await propertyRepo.fetchRooms(propertyId: row.id)
        let inspections = try await inspectionRepo.fetchInspections(propertyId: row.id)
        // Support both legacy kebab-case and current snake_case values.
        let moveInIds = inspections.filter {
            let normalized = $0.inspectionType.lowercased()
            return normalized == "move_in" || normalized == "move-in" || normalized == "movein"
        }.map(\.id)
        let moveOutIds = inspections.filter {
            let normalized = $0.inspectionType.lowercased()
            return normalized == "move_out" || normalized == "move-out" || normalized == "moveout"
        }.map(\.id)

        let moveInItems = try await inspectionRepo.fetchAllInspectionItems(inspectionIds: moveInIds)
        let moveOutItems = try await inspectionRepo.fetchAllInspectionItems(inspectionIds: moveOutIds)

        let moveInFiles = try await inspectionRepo.fetchEvidenceFilesByItems(itemIds: moveInItems.map(\.id))
        let moveOutFiles = try await inspectionRepo.fetchEvidenceFilesByItems(itemIds: moveOutItems.map(\.id))

        let moveInTagNames = try await inspectionRepo.fetchItemTagNames(inspectionItemIds: moveInItems.map(\.id))
        let moveOutTagNames = try await inspectionRepo.fetchItemTagNames(inspectionItemIds: moveOutItems.map(\.id))

        var moveInPhotoCountByItem: [UUID: Int] = [:]
        for file in moveInFiles {
            if let itemId = file.inspectionItemId {
                moveInPhotoCountByItem[itemId, default: 0] += 1
            }
        }
        var moveOutPhotoCountByItem: [UUID: Int] = [:]
        for file in moveOutFiles {
            if let itemId = file.inspectionItemId {
                moveOutPhotoCountByItem[itemId, default: 0] += 1
            }
        }

        let isoDate = ISO8601DateFormatter()
        let roomRecords = rooms.map { roomRow -> RoomRecord in
            var record = RoomRecord(id: roomRow.id, name: roomRow.name)
            let moveInForRoom = moveInItems.filter { $0.roomId == roomRow.id }
                .sorted { ($0.createdAt ?? "") > ($1.createdAt ?? "") }
            record.evidence = moveInForRoom.map { item in
                let (title, notes) = Self.parseInspectionNotes(item.notes, defaultTitle: "Move-in capture")
                return EvidenceRecord(
                    id: item.id,
                    title: title,
                    notes: notes,
                    issueTags: moveInTagNames[item.id] ?? [],
                    condition: Self.conditionFromInt(item.conditionRating),
                    createdAt: isoDate.date(from: item.createdAt ?? "") ?? Date(),
                    photoCount: moveInPhotoCountByItem[item.id] ?? 0,
                    stage: .moveIn
                )
            }
            let moveOutForRoom = moveOutItems.filter { $0.roomId == roomRow.id }
                .sorted { ($0.createdAt ?? "") > ($1.createdAt ?? "") }
            record.moveOutEvidence = moveOutForRoom.map { item in
                let (title, notes) = Self.parseInspectionNotes(item.notes, defaultTitle: "Move-out capture")
                return EvidenceRecord(
                    id: item.id,
                    title: title,
                    notes: notes,
                    issueTags: moveOutTagNames[item.id] ?? [],
                    condition: Self.conditionFromInt(item.conditionRating),
                    createdAt: isoDate.date(from: item.createdAt ?? "") ?? Date(),
                    photoCount: moveOutPhotoCountByItem[item.id] ?? 0,
                    stage: .moveOut
                )
            }
            return record
        }

        let dateFormatter = ISO8601DateFormatter()
        let docRows = try await documentRepo.fetchDocuments(propertyId: row.id)
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

        let issues = try await maintenanceRepo.fetchIssues(propertyId: row.id)
        let maintenance = issues.map { issueRow in
            MaintenanceRecord(
                id: issueRow.id,
                title: issueRow.title,
                category: issueRow.category ?? "General",
                details: issueRow.description ?? "",
                status: issueRow.status == "resolved" ? .resolved : (issueRow.status == "follow_up" ? .followUp : .open),
                landlordResponse: "",
                photoCount: 0
            )
        }
        return (record, maintenance)
    }

    private static func conditionFromInt(_ value: Int?) -> RoomRecord.ConditionRating {
        switch value {
        case 5: return .excellent
        case 4: return .good
        case 3: return .fair
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
