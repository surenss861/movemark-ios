//
//  PropertyStore+Mutations.swift
//  movemork
//
//  Create, update, delete, refresh after user actions.
//

import Foundation
import os

/// Unified Logging for room proof uploads (visible in Console.app / `log stream` for TestFlight builds).
private let inspectionPhotoPipelineLog = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "movemork",
    category: "InspectionPhotoPipeline"
)

extension PropertyStore {
    private enum MutationError: LocalizedError {
        case invalidRoomName
        case duplicateRoomName
        /// Inspection item was inserted but no `evidence_files` row linked (avoid metadata-only rows).
        case noProofPhotosLinked(isMoveOut: Bool)

        var errorDescription: String? {
            switch self {
            case .invalidRoomName:
                return "Enter a room name."
            case .duplicateRoomName:
                return "A room with this name already exists."
            case .noProofPhotosLinked(let moveOut):
                return moveOut
                    ? "Couldn’t save move-out proof photos right now. Try again."
                    : "Couldn’t save proof photos right now. Try again."
            }
        }
    }

    private struct PhotoPipelineResult {
        let savedPhotos: [EvidencePhoto]
        let failedCount: Int

        var hasAnySuccess: Bool { !savedPhotos.isEmpty }
        var hadAnyFailure: Bool { failedCount > 0 }
    }

    /// Uploads each JPEG and inserts `evidence_files`; continues on per-photo failure. Orphan storage is removed when insert fails after upload.
    private func saveInspectionPhotos(
        photos: [Data],
        userId: UUID,
        propertyId: UUID,
        roomId: UUID,
        inspectionItemId: UUID,
        folder: String
    ) async -> PhotoPipelineResult {
        var savedPhotos: [EvidencePhoto] = []
        savedPhotos.reserveCapacity(photos.count)
        var failedCount = 0
        inspectionPhotoPipelineLog.info(
            "Pipeline start property=\(propertyId.uuidString, privacy: .public) room=\(roomId.uuidString, privacy: .public) item=\(inspectionItemId.uuidString, privacy: .public) folder=\(folder, privacy: .public) photoCount=\(photos.count)"
        )
        for (index, photoData) in photos.enumerated() {
            let path = "\(userId)/\(propertyId)/\(folder)/\(roomId)/\(UUID()).jpg"
            inspectionPhotoPipelineLog.debug(
                "Photo \(index + 1)/\(photos.count) bytes=\(photoData.count) path=\(path, privacy: .public)"
            )
            do {
                _ = try await inspectionRepo.uploadPhoto(data: photoData, path: path)
                inspectionPhotoPipelineLog.debug("uploadPhoto OK path=\(path, privacy: .public)")
            } catch {
                failedCount += 1
                inspectionPhotoPipelineLog.error(
                    "uploadPhoto FAILED path=\(path, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
                )
                #if DEBUG
                print("MoveMark: uploadPhoto failed", path, error)
                #endif
                continue
            }
            do {
                let fileId = try await inspectionRepo.insertEvidenceFile(
                    propertyId: propertyId,
                    inspectionItemId: inspectionItemId,
                    maintenanceIssueId: nil,
                    filePath: path,
                    fileType: "image",
                    capturedAt: Date()
                )
                savedPhotos.append(EvidencePhoto(id: fileId, filePath: path))
                inspectionPhotoPipelineLog.debug(
                    "insertEvidenceFile OK fileId=\(fileId.uuidString, privacy: .public) path=\(path, privacy: .public)"
                )
            } catch {
                failedCount += 1
                await inspectionRepo.removeOrphanInspectionUpload(path: path)
                inspectionPhotoPipelineLog.error(
                    "insertEvidenceFile FAILED path=\(path, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
                )
                #if DEBUG
                print("MoveMark: insertEvidenceFile failed after upload", path, error)
                #endif
            }
        }
        inspectionPhotoPipelineLog.info(
            "Pipeline end item=\(inspectionItemId.uuidString, privacy: .public) savedCount=\(savedPhotos.count) failedAttempts=\(failedCount)"
        )
        return PhotoPipelineResult(savedPhotos: savedPhotos, failedCount: failedCount)
    }

    /// Refreshes vault document types for the current property (e.g. after upload). Call after adding a document.
    /// - Returns: `false` if the metadata refresh failed (upload may still have succeeded).
    @discardableResult
    func refreshDocuments(propertyId: UUID) async -> Bool {
        guard currentProperty?.id == propertyId else { return true }
        do {
            let rows = try await documentRepo.fetchDocuments(propertyId: propertyId)
            let vaultDocTypes = Array(Set(rows.map(\.documentType)))
            if var prop = currentProperty {
                prop.vaultDocuments = vaultDocTypes
                currentProperty = prop
            }
            return true
        } catch {
            return false
        }
    }

    /// After a confirmed `property_documents` insert, ensures `vaultDocuments` lists this type when a full refetch failed or lagged (keeps “View” / readiness in sync without relaunch).
    func ensureVaultDocumentTypePresent(propertyId: UUID, documentType: String) {
        guard var prop = currentProperty, prop.id == propertyId else { return }
        let keys = Set(DocumentRepository.documentTypeQueryKeys(documentType))
        if prop.vaultDocuments.contains(where: { keys.contains($0) }) { return }
        prop.vaultDocuments.append(DocumentRepository.normalizedDocumentType(documentType))
        currentProperty = prop
    }

    private func buildPropertyRow(id: UUID, input: CreatePropertyInput, userId: UUID, createdAt: String?) -> PropertyRow {
        let dbDate = Self.dbDateFormatter
        let deposit = Double(input.depositAmount.trimmingCharacters(in: .whitespacesAndNewlines)).map { $0 >= 0 ? $0 : nil } ?? nil
        let rent = Double(input.rentAmount.trimmingCharacters(in: .whitespacesAndNewlines)).map { $0 >= 0 ? $0 : nil } ?? nil
        let countryVal = input.country.trimmingCharacters(in: .whitespacesAndNewlines)
        return PropertyRow(
            id: id,
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
            createdAt: createdAt
        )
    }

    /// Creates a property from the locked input contract, inserts default rooms, then refreshes store.
    func createProperty(input: CreatePropertyInput, userId: UUID) async throws {
        #if DEBUG
        print("🏪 PropertyStore.createProperty called")
        print("🏪 userId: \(userId.uuidString)")
        print("🏪 input.titleValue: \(input.titleValue), addressLine1: \(input.addressLine1)")
        #endif

        let row = buildPropertyRow(id: UUID(), input: input, userId: userId, createdAt: nil)

        let created = try await propertyRepo.createProperty(row)
        try await propertyRepo.insertDefaultRooms(propertyId: created.id, userId: userId)
        activePropertyId = created.id
        UserDefaults.standard.set(created.id.uuidString, forKey: Self.persistedActivePropertyIdKey(userId: userId))
        await fetchAll(userId: userId)
    }

    /// Updates the property in DB and refreshes store (properties list + active property).
    func updateProperty(propertyId: UUID, input: CreatePropertyInput, userId: UUID) async throws {
        let row = buildPropertyRow(id: propertyId, input: input, userId: userId, createdAt: nil)
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

    func addEvidence(to roomID: UUID, evidence: EvidenceRecord, photos: [Data], propertyId: UUID, userId: UUID) async throws -> PropertyMutationOutcome {
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
        case .belowFair: conditionInt = 2
        case .poor: conditionInt = 1
        }

        let itemId = try await inspectionRepo.insertInspectionItem(
            inspectionId: inspectionId,
            roomId: roomID,
            notes: "\(evidence.title)\n\(evidence.notes)",
            conditionRating: conditionInt
        )

        let pipeline = await saveInspectionPhotos(
            photos: photos,
            userId: userId,
            propertyId: propertyId,
            roomId: roomID,
            inspectionItemId: itemId,
            folder: "move-in"
        )

        guard pipeline.hasAnySuccess else {
            inspectionPhotoPipelineLog.warning(
                "Zero evidence_files linked — deleting inspection_item=\(itemId.uuidString, privacy: .public) room=\(roomID.uuidString, privacy: .public) property=\(propertyId.uuidString, privacy: .public) moveIn"
            )
            try? await inspectionRepo.deleteInspectionItem(id: itemId)
            throw MutationError.noProofPhotosLinked(isMoveOut: false)
        }

        await MoveMarkSignedURLCache.shared.invalidateKeys(containing: propertyId.uuidString)

        // Tags are optional metadata; RLS/network failure here must not surface as “save failed” after item+photos persisted.
        if !evidence.issueTags.isEmpty {
            do {
                try await inspectionRepo.insertItemTags(inspectionItemId: itemId, tagNames: evidence.issueTags)
            } catch {
                #if DEBUG
                print("MoveMark: insertItemTags failed after move-in save (evidence already stored):", error)
                #endif
            }
        }

        applyOptimisticMoveInEvidence(
            roomID: roomID,
            itemId: itemId,
            evidence: evidence,
            savedPhotos: pipeline.savedPhotos,
            propertyId: propertyId
        )
        let ok = await refreshActivePropertyHydration(userId: userId)
        reconcileInspectionEvidencePhotos(
            itemId: itemId,
            roomID: roomID,
            propertyId: propertyId,
            isMoveOut: false,
            fallbackPhotos: pipeline.savedPhotos,
            minimumPhotoCount: pipeline.savedPhotos.count
        )
        #if DEBUG
        if pipeline.hadAnyFailure {
            print("MoveMark: addEvidence partially succeeded — some photos failed, but proof was saved.")
        }
        #endif
        return PropertyMutationOutcome(hydrationRefreshFailed: !ok)
    }

    func addMoveOutEvidence(to roomID: UUID, evidence: EvidenceRecord, photos: [Data], propertyId: UUID, userId: UUID) async throws -> PropertyMutationOutcome {
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
        case .belowFair: conditionInt = 2
        case .poor: conditionInt = 1
        }

        let itemId = try await inspectionRepo.insertInspectionItem(
            inspectionId: inspectionId,
            roomId: roomID,
            notes: "\(evidence.title)\n\(evidence.notes)",
            conditionRating: conditionInt
        )

        let pipeline = await saveInspectionPhotos(
            photos: photos,
            userId: userId,
            propertyId: propertyId,
            roomId: roomID,
            inspectionItemId: itemId,
            folder: "move-out"
        )

        guard pipeline.hasAnySuccess else {
            inspectionPhotoPipelineLog.warning(
                "Zero evidence_files linked — deleting inspection_item=\(itemId.uuidString, privacy: .public) room=\(roomID.uuidString, privacy: .public) property=\(propertyId.uuidString, privacy: .public) moveOut"
            )
            try? await inspectionRepo.deleteInspectionItem(id: itemId)
            throw MutationError.noProofPhotosLinked(isMoveOut: true)
        }

        await MoveMarkSignedURLCache.shared.invalidateKeys(containing: propertyId.uuidString)

        if !evidence.issueTags.isEmpty {
            do {
                try await inspectionRepo.insertItemTags(inspectionItemId: itemId, tagNames: evidence.issueTags)
            } catch {
                #if DEBUG
                print("MoveMark: insertItemTags failed after move-out save (evidence already stored):", error)
                #endif
            }
        }

        applyOptimisticMoveOutEvidence(
            roomID: roomID,
            itemId: itemId,
            evidence: evidence,
            savedPhotos: pipeline.savedPhotos,
            propertyId: propertyId
        )
        let ok = await refreshActivePropertyHydration(userId: userId)
        reconcileInspectionEvidencePhotos(
            itemId: itemId,
            roomID: roomID,
            propertyId: propertyId,
            isMoveOut: true,
            fallbackPhotos: pipeline.savedPhotos,
            minimumPhotoCount: pipeline.savedPhotos.count
        )
        #if DEBUG
        if pipeline.hadAnyFailure {
            print("MoveMark: addMoveOutEvidence partially succeeded — some photos failed, but proof was saved.")
        }
        #endif
        return PropertyMutationOutcome(hydrationRefreshFailed: !ok)
    }

    func deleteEvidence(entryId: UUID, propertyId: UUID, userId: UUID) async throws -> PropertyMutationOutcome {
        try await inspectionRepo.deleteInspectionItem(id: entryId)
        await MoveMarkSignedURLCache.shared.invalidateKeys(containing: propertyId.uuidString)
        applyOptimisticDeleteEvidence(entryId: entryId, propertyId: propertyId)
        let ok = await refreshActivePropertyHydration(userId: userId)
        return PropertyMutationOutcome(hydrationRefreshFailed: !ok)
    }

    func updateEvidence(entryId: UUID, title: String, notes: String, tags: [String], condition: RoomRecord.ConditionRating, propertyId: UUID, userId: UUID) async throws -> PropertyMutationOutcome {
        let conditionInt: Int
        switch condition {
        case .excellent: conditionInt = 5
        case .good: conditionInt = 4
        case .fair: conditionInt = 3
        case .belowFair: conditionInt = 2
        case .poor: conditionInt = 1
        }
        let notesValue = "\(title)\n\(notes)"
        try await inspectionRepo.updateInspectionItem(id: entryId, notes: notesValue, conditionRating: conditionInt)
        try await inspectionRepo.deleteItemTagsForInspectionItem(inspectionItemId: entryId)
        if !tags.isEmpty {
            try await inspectionRepo.insertItemTags(inspectionItemId: entryId, tagNames: tags)
        }
        let ok = await refreshActivePropertyHydration(userId: userId)
        return PropertyMutationOutcome(hydrationRefreshFailed: !ok)
    }

    func appendPhotosToEvidence(entryId: UUID, roomId: UUID, photos: [Data], propertyId: UUID, userId: UUID, isMoveOut: Bool) async throws -> PropertyMutationOutcome {
        let priorTotal: Int = {
            guard let prop = currentProperty, prop.id == propertyId,
                  let room = prop.rooms.first(where: { $0.id == roomId }) else { return 0 }
            let list = isMoveOut ? room.moveOutEvidence : room.evidence
            return list.first(where: { $0.id == entryId })?.photoCount ?? 0
        }()
        let expectedTotal = priorTotal + photos.count

        let addedPhotos = try await inspectionRepo.appendPhotosToInspectionItem(
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
        let ok = await refreshActivePropertyHydration(userId: userId)
        reconcileInspectionEvidencePhotos(
            itemId: entryId,
            roomID: roomId,
            propertyId: propertyId,
            isMoveOut: isMoveOut,
            fallbackPhotos: addedPhotos,
            minimumPhotoCount: expectedTotal
        )
        return PropertyMutationOutcome(hydrationRefreshFailed: !ok)
    }

    @discardableResult
    func addMaintenance(_ record: MaintenanceRecord, photos: [Data], propertyId: UUID, userId: UUID) async throws -> MaintenanceSubmitOutcome {
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
        let listOK = await refreshMaintenance(propertyId: propertyId)
        return MaintenanceSubmitOutcome(inserted: inserted, listRefreshFailed: !listOK)
    }

    /// Refreshes maintenance log from DB (e.g. after creating or updating an issue).
    /// - Returns: `false` if the fetch failed; does **not** clear existing `maintenanceLog` so post-save state isn’t wiped.
    @discardableResult
    func refreshMaintenance(propertyId: UUID) async -> Bool {
        guard currentProperty?.id == propertyId else { return true }
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
            return true
        } catch {
            return false
        }
    }

    private func applyOptimisticMoveInEvidence(
        roomID: UUID,
        itemId: UUID,
        evidence: EvidenceRecord,
        savedPhotos: [EvidencePhoto],
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
            photoCount: savedPhotos.count,
            photos: savedPhotos,
            stage: .moveIn
        )
        prop.rooms[rIdx].evidence.insert(newRec, at: 0)
        prop.rooms[rIdx].evidence = Self.dedupeEvidenceEntriesPreservingOrder(prop.rooms[rIdx].evidence)
        currentProperty = prop
    }

    private func applyOptimisticMoveOutEvidence(
        roomID: UUID,
        itemId: UUID,
        evidence: EvidenceRecord,
        savedPhotos: [EvidencePhoto],
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
            photoCount: savedPhotos.count,
            photos: savedPhotos,
            stage: .moveOut
        )
        prop.rooms[rIdx].moveOutEvidence.insert(newRec, at: 0)
        prop.rooms[rIdx].moveOutEvidence = Self.dedupeEvidenceEntriesPreservingOrder(prop.rooms[rIdx].moveOutEvidence)
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

    /// If hydration returns fewer `evidence_files` than we just wrote (transient read lag or refresh failure), merge known `(id, path)` so thumbnails and counts match reality without relaunch.
    private func reconcileInspectionEvidencePhotos(
        itemId: UUID,
        roomID: UUID,
        propertyId: UUID,
        isMoveOut: Bool,
        fallbackPhotos: [EvidencePhoto],
        minimumPhotoCount: Int
    ) {
        guard var prop = currentProperty, prop.id == propertyId,
              let rIdx = prop.rooms.firstIndex(where: { $0.id == roomID }) else { return }
        var room = prop.rooms[rIdx]
        if isMoveOut {
            if let eIdx = room.moveOutEvidence.firstIndex(where: { $0.id == itemId }) {
                room.moveOutEvidence[eIdx] = Self.mergedEvidenceWithFallbackPhotos(
                    room.moveOutEvidence[eIdx],
                    fallbackPhotos: fallbackPhotos,
                    minimumPhotoCount: minimumPhotoCount
                )
            } else if !fallbackPhotos.isEmpty {
                // Hydration can briefly omit a just-inserted item; still attach known-good file refs from this save.
                let synthetic = Self.syntheticEvidenceRecord(
                    itemId: itemId,
                    fallbackPhotos: fallbackPhotos,
                    minimumPhotoCount: minimumPhotoCount,
                    stage: .moveOut
                )
                room.moveOutEvidence.insert(synthetic, at: 0)
            }
        } else {
            if let eIdx = room.evidence.firstIndex(where: { $0.id == itemId }) {
                room.evidence[eIdx] = Self.mergedEvidenceWithFallbackPhotos(
                    room.evidence[eIdx],
                    fallbackPhotos: fallbackPhotos,
                    minimumPhotoCount: minimumPhotoCount
                )
            } else if !fallbackPhotos.isEmpty {
                let synthetic = Self.syntheticEvidenceRecord(
                    itemId: itemId,
                    fallbackPhotos: fallbackPhotos,
                    minimumPhotoCount: minimumPhotoCount,
                    stage: .moveIn
                )
                room.evidence.insert(synthetic, at: 0)
            }
        }
        room.evidence = Self.dedupeEvidenceEntriesPreservingOrder(room.evidence)
        room.moveOutEvidence = Self.dedupeEvidenceEntriesPreservingOrder(room.moveOutEvidence)
        prop.rooms[rIdx] = room
        currentProperty = prop
    }

    /// Merges `fallbackPhotos` from the save pipeline into the hydrated entry so thumbnails/count stay truthful when reads lag or counts disagree.
    private static func mergedEvidenceWithFallbackPhotos(
        _ entry: EvidenceRecord,
        fallbackPhotos: [EvidencePhoto],
        minimumPhotoCount: Int
    ) -> EvidenceRecord {
        var entry = entry
        guard !fallbackPhotos.isEmpty else {
            entry.photoCount = max(entry.photoCount, entry.photos.count, minimumPhotoCount)
            return entry
        }
        var seenPaths = Set(entry.photos.map(\.filePath))
        var merged = entry.photos
        for p in fallbackPhotos where !seenPaths.contains(p.filePath) {
            merged.append(p)
            seenPaths.insert(p.filePath)
        }
        entry.photos = merged
        entry.photoCount = max(entry.photoCount, merged.count, minimumPhotoCount)
        return entry
    }

    private static func syntheticEvidenceRecord(
        itemId: UUID,
        fallbackPhotos: [EvidencePhoto],
        minimumPhotoCount: Int,
        stage: EvidenceRecord.Stage
    ) -> EvidenceRecord {
        let title = stage == .moveOut ? "Move-out capture" : "Move-in capture"
        let count = max(fallbackPhotos.count, minimumPhotoCount)
        return EvidenceRecord(
            id: itemId,
            title: title,
            notes: "",
            issueTags: [],
            condition: .good,
            createdAt: Date(),
            photoCount: count,
            photos: fallbackPhotos,
            stage: stage
        )
    }

    /// Merges duplicate ``EvidenceRecord``s with the same inspection item id (e.g. synthetic fallback row + hydrated row).
    static func dedupeEvidenceEntriesPreservingOrder(_ entries: [EvidenceRecord]) -> [EvidenceRecord] {
        guard entries.count > 1 else { return entries }
        var merged: [EvidenceRecord] = []
        var slotById: [UUID: Int] = [:]
        for entry in entries {
            if let slot = slotById[entry.id] {
                merged[slot] = mergeEvidenceRecordsWithSameId(merged[slot], entry)
            } else {
                slotById[entry.id] = merged.count
                merged.append(entry)
            }
        }
        return merged
    }

    private static func mergeEvidenceRecordsWithSameId(_ a: EvidenceRecord, _ b: EvidenceRecord) -> EvidenceRecord {
        var seen = Set<String>()
        var photos: [EvidencePhoto] = []
        for p in a.photos + b.photos where !seen.contains(p.filePath) {
            photos.append(p)
            seen.insert(p.filePath)
        }
        let defaultMoveIn = "Move-in capture"
        let defaultMoveOut = "Move-out capture"
        func isPlaceholderTitle(_ t: String) -> Bool { t == defaultMoveIn || t == defaultMoveOut }
        let title: String = {
            if !isPlaceholderTitle(a.title) { return a.title }
            if !isPlaceholderTitle(b.title) { return b.title }
            return a.title.count >= b.title.count ? a.title : b.title
        }()
        let notes = a.notes.count >= b.notes.count ? a.notes : b.notes
        let tags = Array(Set(a.issueTags + b.issueTags)).sorted()
        let createdAt = min(a.createdAt, b.createdAt)
        let pc = max(a.photoCount, b.photoCount, photos.count)
        return EvidenceRecord(
            id: a.id,
            title: title,
            notes: notes,
            issueTags: tags,
            condition: a.condition,
            createdAt: createdAt,
            photoCount: pc,
            photos: photos,
            stage: a.stage
        )
    }
}
