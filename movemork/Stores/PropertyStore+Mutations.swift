//
//  PropertyStore+Mutations.swift
//  movemork
//
//  Create, update, delete, refresh after user actions.
//

import Foundation

extension PropertyStore {
    private enum MutationError: LocalizedError {
        case invalidRoomName
        case duplicateRoomName

        var errorDescription: String? {
            switch self {
            case .invalidRoomName:
                return "Enter a room name."
            case .duplicateRoomName:
                return "A room with this name already exists."
            }
        }
    }

    /// Refreshes vault document types for the current property (e.g. after upload). Call after adding a document.
    func refreshDocuments(propertyId: UUID) async {
        guard currentProperty?.id == propertyId else { return }
        do {
            let rows = try await documentRepo.fetchDocuments(propertyId: propertyId)
            let vaultDocTypes = Array(Set(rows.map(\.documentType)))
            if var prop = currentProperty {
                prop.vaultDocuments = vaultDocTypes
                currentProperty = prop
            }
        } catch {
            // Non-fatal; Vault may have already updated from local state
        }
    }

    /// Creates a property from the locked input contract, inserts default rooms, then refreshes store.
    func createProperty(input: CreatePropertyInput, userId: UUID) async throws {
        #if DEBUG
        print("🏪 PropertyStore.createProperty called")
        print("🏪 userId: \(userId.uuidString)")
        print("🏪 input.titleValue: \(input.titleValue), addressLine1: \(input.addressLine1)")
        #endif

        let iso = ISO8601DateFormatter()
        let dbDate = Self.dbDateFormatter
        let deposit = Double(input.depositAmount.trimmingCharacters(in: .whitespacesAndNewlines)).map { $0 >= 0 ? $0 : nil } ?? nil
        let rent = Double(input.rentAmount.trimmingCharacters(in: .whitespacesAndNewlines)).map { $0 >= 0 ? $0 : nil } ?? nil
        let countryVal = input.country.trimmingCharacters(in: .whitespacesAndNewlines)
        let row = PropertyRow(
            id: UUID(),
            userId: userId,
            title: input.titleValue,
            addressLine1: input.addressLine1.trimmingCharacters(in: .whitespacesAndNewlines),
            addressLine2: input.unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : input.unit.trimmingCharacters(in: .whitespacesAndNewlines),
            city: input.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unknown" : input.city.trimmingCharacters(in: .whitespacesAndNewlines),
            provinceState: input.region.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unknown" : input.region.trimmingCharacters(in: .whitespacesAndNewlines),
            postalCode: input.postalCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "00000" : input.postalCode.trimmingCharacters(in: .whitespacesAndNewlines),
            country: countryVal.isEmpty ? "CA" : countryVal,
            landlordName: input.landlordName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : input.landlordName.trimmingCharacters(in: .whitespacesAndNewlines),
            landlordEmail: input.landlordEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : input.landlordEmail.trimmingCharacters(in: .whitespacesAndNewlines),
            landlordPhone: input.landlordPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : input.landlordPhone.trimmingCharacters(in: .whitespacesAndNewlines),
            depositAmount: deposit,
            rentAmount: rent,
            moveInDate: dbDate.string(from: input.moveInDate),
            leaseStart: dbDate.string(from: input.leaseStartDate),
            leaseEnd: dbDate.string(from: input.leaseEndDate),
            createdAt: nil
        )

        let created = try await propertyRepo.createProperty(row)
        try await propertyRepo.insertDefaultRooms(propertyId: created.id, userId: userId)
        activePropertyId = created.id
        UserDefaults.standard.set(created.id.uuidString, forKey: Self.persistedActivePropertyIdKey(userId: userId))
        await fetchAll(userId: userId)
    }

    /// Updates the property in DB and refreshes store (properties list + active property).
    func updateProperty(propertyId: UUID, input: CreatePropertyInput, userId: UUID) async throws {
        let dbDate = Self.dbDateFormatter
        let deposit = Double(input.depositAmount.trimmingCharacters(in: .whitespacesAndNewlines)).map { $0 >= 0 ? $0 : nil } ?? nil
        let rent = Double(input.rentAmount.trimmingCharacters(in: .whitespacesAndNewlines)).map { $0 >= 0 ? $0 : nil } ?? nil
        let countryVal = input.country.trimmingCharacters(in: .whitespacesAndNewlines)
        let row = PropertyRow(
            id: propertyId,
            userId: userId,
            title: input.titleValue,
            addressLine1: input.addressLine1.trimmingCharacters(in: .whitespacesAndNewlines),
            addressLine2: input.unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : input.unit.trimmingCharacters(in: .whitespacesAndNewlines),
            city: input.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unknown" : input.city.trimmingCharacters(in: .whitespacesAndNewlines),
            provinceState: input.region.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unknown" : input.region.trimmingCharacters(in: .whitespacesAndNewlines),
            postalCode: input.postalCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "00000" : input.postalCode.trimmingCharacters(in: .whitespacesAndNewlines),
            country: countryVal.isEmpty ? "CA" : countryVal,
            landlordName: input.landlordName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : input.landlordName.trimmingCharacters(in: .whitespacesAndNewlines),
            landlordEmail: input.landlordEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : input.landlordEmail.trimmingCharacters(in: .whitespacesAndNewlines),
            landlordPhone: input.landlordPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : input.landlordPhone.trimmingCharacters(in: .whitespacesAndNewlines),
            depositAmount: deposit,
            rentAmount: rent,
            moveInDate: dbDate.string(from: input.moveInDate),
            leaseStart: dbDate.string(from: input.leaseStartDate),
            leaseEnd: dbDate.string(from: input.leaseEndDate),
            createdAt: nil
        )
        try await propertyRepo.updateProperty(row)
        await fetchAll(userId: userId)
    }

    func addRoom(named name: String, propertyId: UUID, userId: UUID) async throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw MutationError.invalidRoomName }

        if let existing = currentProperty?.rooms,
           existing.contains(where: { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(trimmed) == .orderedSame }) {
            throw MutationError.duplicateRoomName
        }

        let existingRooms = try await propertyRepo.fetchRooms(propertyId: propertyId)
        let sortOrder = (existingRooms.map(\.sortOrder).max() ?? -1) + 1

        let row = RoomRow(
            id: UUID(),
            propertyId: propertyId,
            name: trimmed,
            sortOrder: sortOrder
        )

        _ = try await propertyRepo.insertRoom(row)
        await fetchAll(userId: userId)
    }

    func addEvidence(to roomID: UUID, evidence: EvidenceRecord, photos: [Data], propertyId: UUID, userId: UUID) async throws {
        let inspectionId = try await inspectionRepo.upsertInspection(
            propertyId: propertyId,
            userId: userId,
            type: "move_in"
        )

        let conditionInt: Int
        switch evidence.condition {
        case .excellent: conditionInt = 5
        case .good: conditionInt = 4
        case .fair: conditionInt = 3
        case .poor: conditionInt = 1
        }

        let itemId = try await inspectionRepo.insertInspectionItem(
            inspectionId: inspectionId,
            roomId: roomID,
            notes: "\(evidence.title)\n\(evidence.notes)",
            conditionRating: conditionInt
        )

        for photoData in photos {
            let path = "\(userId)/\(propertyId)/move-in/\(roomID)/\(UUID()).jpg"
            _ = try await inspectionRepo.uploadPhoto(data: photoData, path: path)
            try await inspectionRepo.insertEvidenceFile(
                propertyId: propertyId,
                inspectionItemId: itemId,
                maintenanceIssueId: nil,
                filePath: path,
                fileType: "image",
                capturedAt: Date()
            )
        }

        if !evidence.issueTags.isEmpty {
            try? await inspectionRepo.insertItemTags(inspectionItemId: itemId, tagNames: evidence.issueTags)
        }

        applyOptimisticMoveInEvidence(
            roomID: roomID,
            itemId: itemId,
            evidence: evidence,
            photoCount: photos.count,
            propertyId: propertyId
        )
        await refreshActivePropertyHydration(userId: userId)
    }

    func addMoveOutEvidence(to roomID: UUID, evidence: EvidenceRecord, photos: [Data], propertyId: UUID, userId: UUID) async throws {
        let inspectionId = try await inspectionRepo.upsertInspection(
            propertyId: propertyId,
            userId: userId,
            type: "move_out"
        )

        let conditionInt: Int
        switch evidence.condition {
        case .excellent: conditionInt = 5
        case .good: conditionInt = 4
        case .fair: conditionInt = 3
        case .poor: conditionInt = 1
        }

        let itemId = try await inspectionRepo.insertInspectionItem(
            inspectionId: inspectionId,
            roomId: roomID,
            notes: "\(evidence.title)\n\(evidence.notes)",
            conditionRating: conditionInt
        )

        for photoData in photos {
            let path = "\(userId)/\(propertyId)/move-out/\(roomID)/\(UUID()).jpg"
            _ = try await inspectionRepo.uploadPhoto(data: photoData, path: path)
            try await inspectionRepo.insertEvidenceFile(
                propertyId: propertyId,
                inspectionItemId: itemId,
                maintenanceIssueId: nil,
                filePath: path,
                fileType: "image",
                capturedAt: Date()
            )
        }

        applyOptimisticMoveOutEvidence(
            roomID: roomID,
            itemId: itemId,
            evidence: evidence,
            photoCount: photos.count,
            propertyId: propertyId
        )
        await refreshActivePropertyHydration(userId: userId)
    }

    func deleteEvidence(entryId: UUID, propertyId: UUID, userId: UUID) async throws {
        try await inspectionRepo.deleteInspectionItem(id: entryId)
        applyOptimisticDeleteEvidence(entryId: entryId, propertyId: propertyId)
        await refreshActivePropertyHydration(userId: userId)
    }

    func updateEvidence(entryId: UUID, title: String, notes: String, tags: [String], condition: RoomRecord.ConditionRating, propertyId: UUID, userId: UUID) async throws {
        let conditionInt: Int
        switch condition {
        case .excellent: conditionInt = 5
        case .good: conditionInt = 4
        case .fair: conditionInt = 3
        case .poor: conditionInt = 1
        }
        let notesValue = "\(title)\n\(notes)"
        try await inspectionRepo.updateInspectionItem(id: entryId, notes: notesValue, conditionRating: conditionInt)
        try await inspectionRepo.deleteItemTagsForInspectionItem(inspectionItemId: entryId)
        if !tags.isEmpty {
            try? await inspectionRepo.insertItemTags(inspectionItemId: entryId, tagNames: tags)
        }
        await refreshActivePropertyHydration(userId: userId)
    }

    func appendPhotosToEvidence(entryId: UUID, roomId: UUID, photos: [Data], propertyId: UUID, userId: UUID, isMoveOut: Bool) async throws {
        try await inspectionRepo.appendPhotosToInspectionItem(
            inspectionItemId: entryId,
            roomId: roomId,
            propertyId: propertyId,
            userId: userId,
            isMoveOut: isMoveOut,
            photos: photos
        )
        applyOptimisticAppendPhotos(
            entryId: entryId,
            roomId: roomId,
            addedCount: photos.count,
            propertyId: propertyId
        )
        await refreshActivePropertyHydration(userId: userId)
    }

    @discardableResult
    func addMaintenance(_ record: MaintenanceRecord, photos: [Data], propertyId: UUID, userId: UUID) async throws -> MaintenanceIssueRow {
        let now = ISO8601DateFormatter().string(from: record.createdAt)
        let row = MaintenanceIssueRow(
            id: record.id,
            propertyId: propertyId,
            userId: userId,
            title: record.title,
            description: record.details.isEmpty ? nil : record.details,
            category: record.category,
            status: "open",
            dateDiscovered: now,
            dateReported: now,
            reportMethod: nil,
            landlordResponse: nil,
            followUpDate: nil,
            updatedAt: nil
        )

        let inserted = try await maintenanceRepo.insertIssue(row)

        for photoData in photos {
            let path = "\(userId)/\(propertyId)/\(inserted.id)/\(UUID()).jpg"
            _ = try await maintenanceRepo.uploadAttachment(data: photoData, path: path)
            try await inspectionRepo.insertEvidenceFile(
                propertyId: propertyId,
                inspectionItemId: nil,
                maintenanceIssueId: inserted.id,
                filePath: path,
                fileType: "image",
                capturedAt: Date()
            )
        }

        if currentProperty?.id == propertyId {
            let created = ISO8601DateFormatter().date(from: inserted.dateReported ?? inserted.dateDiscovered ?? "") ?? Date()
            let newEntry = MaintenanceRecord(
                id: inserted.id,
                title: inserted.title,
                category: inserted.category ?? "General",
                details: inserted.description ?? "",
                status: .open,
                createdAt: created,
                landlordResponse: "",
                photoCount: photos.count
            )
            maintenanceLog.insert(newEntry, at: 0)
        }
        await refreshMaintenance(propertyId: propertyId)
        return inserted
    }

    /// Refreshes maintenance log from DB (e.g. after creating or updating an issue).
    func refreshMaintenance(propertyId: UUID) async {
        guard currentProperty?.id == propertyId else { return }
        do {
            let rows = try await maintenanceRepo.fetchIssues(propertyId: propertyId)
            maintenanceLog = rows.map { row in
                MaintenanceRecord(
                    id: row.id,
                    title: row.title,
                    category: row.category ?? "General",
                    details: row.description ?? "",
                    status: row.status == "resolved" ? .resolved : (row.status == "follow_up" ? .followUp : .open),
                    createdAt: ISO8601DateFormatter().date(from: row.dateReported ?? row.dateDiscovered ?? "") ?? Date(),
                    landlordResponse: row.landlordResponse ?? "",
                    photoCount: 0
                )
            }
        } catch {
            // Non-fatal; list may have already refreshed in the view
        }
    }

    private func applyOptimisticMoveInEvidence(
        roomID: UUID,
        itemId: UUID,
        evidence: EvidenceRecord,
        photoCount: Int,
        propertyId: UUID
    ) {
        guard var prop = currentProperty, prop.id == propertyId,
              let rIdx = prop.rooms.firstIndex(where: { $0.id == roomID }) else { return }
        let newRec = EvidenceRecord(
            id: itemId,
            title: evidence.title,
            notes: evidence.notes,
            issueTags: evidence.issueTags,
            condition: evidence.condition,
            createdAt: Date(),
            photoCount: photoCount,
            photos: [],
            stage: .moveIn
        )
        prop.rooms[rIdx].evidence.insert(newRec, at: 0)
        currentProperty = prop
    }

    private func applyOptimisticMoveOutEvidence(
        roomID: UUID,
        itemId: UUID,
        evidence: EvidenceRecord,
        photoCount: Int,
        propertyId: UUID
    ) {
        guard var prop = currentProperty, prop.id == propertyId,
              let rIdx = prop.rooms.firstIndex(where: { $0.id == roomID }) else { return }
        let newRec = EvidenceRecord(
            id: itemId,
            title: evidence.title,
            notes: evidence.notes,
            issueTags: evidence.issueTags,
            condition: evidence.condition,
            createdAt: Date(),
            photoCount: photoCount,
            photos: [],
            stage: .moveOut
        )
        prop.rooms[rIdx].moveOutEvidence.insert(newRec, at: 0)
        currentProperty = prop
    }

    private func applyOptimisticAppendPhotos(
        entryId: UUID,
        roomId: UUID,
        addedCount: Int,
        propertyId: UUID
    ) {
        guard var prop = currentProperty, prop.id == propertyId,
              let rIdx = prop.rooms.firstIndex(where: { $0.id == roomId }) else { return }
        var room = prop.rooms[rIdx]
        if let eIdx = room.evidence.firstIndex(where: { $0.id == entryId }) {
            room.evidence[eIdx].photoCount += addedCount
            prop.rooms[rIdx] = room
            currentProperty = prop
            return
        }
        if let eIdx = room.moveOutEvidence.firstIndex(where: { $0.id == entryId }) {
            room.moveOutEvidence[eIdx].photoCount += addedCount
            prop.rooms[rIdx] = room
            currentProperty = prop
        }
    }

    private func applyOptimisticDeleteEvidence(entryId: UUID, propertyId: UUID) {
        guard var prop = currentProperty, prop.id == propertyId else { return }
        for i in prop.rooms.indices {
            prop.rooms[i].evidence.removeAll { $0.id == entryId }
            prop.rooms[i].moveOutEvidence.removeAll { $0.id == entryId }
        }
        currentProperty = prop
    }
}
