//
//  PendingEvidenceSync.swift
//  movemork
//
//  MoveMark — sends a room's photos from ``PendingEvidenceStore`` to the server so that a kill at any
//  moment loses nothing and duplicates nothing. Everything that will exist on the server is written to
//  this iPhone first:
//
//  1. The entry id is chosen on the phone and written to the manifest before the entry is created; the
//     create is idempotent (an existing row with that id is reused). A kill right after the create leaves
//     the id behind, so the next attempt completes that entry, or ``reconcile(_:)`` removes it when it
//     holds no photo and nothing is left to send.
//  2. Each photo's upload ticket is written before its bytes are sent (and again once finalized). A kill
//     mid-upload leaves the ticket behind; the next attempt releases it first (`abandon`): `kept` means its
//     row committed (the photo is saved), `deleted` means it is safe to upload again.
//  3. Each photo keeps one `evidence_files` row id for every attempt, so a second insert can only conflict.
//  4. A photo leaves the phone only when its row is confirmed — by the insert, by `abandon` answering
//     `kept`, or by the entry's rows on the server listing its id.
//
//  Remaining gap, server side: a ticket issued in the instant between the API's answer and the manifest
//  write is unknown to the phone. Its objects stay unreferenced until the API expires the ticket (24 h);
//  there is no server-side sweeper for expired tickets yet.
//

import Foundation

/// The server side of a sync (MoveMark API + Data API in the app; a fake in tests).
protocol PendingEvidenceBackend {
    /// Creates the entry with this id, or reuses the row if it exists. Sets its notes, condition and tags.
    /// - Returns: true when the tags couldn't be written (the entry and photos are still fine).
    func ensureEntry(id: UUID, key: PendingEvidenceKey, title: String, draft: PendingEvidenceDraft) async throws -> Bool
    /// The entry's `evidence_files` row ids; nil when the entry doesn't exist. Throws when the server can't be asked.
    func entryPhotoIds(entryId: UUID) async throws -> Set<UUID>?
    func deleteEntry(id: UUID) async throws
    /// Ticket → PUTs → finalize. `onTicket` runs before any byte is sent.
    func upload(_ source: MMEvidenceSource, key: PendingEvidenceKey,
                onTicket: @escaping (MoveMarkUpload) async -> Void) async throws -> MoveMarkUpload
    func insertPhoto(rowId: UUID, entryId: UUID, key: PendingEvidenceKey, upload: MoveMarkUpload) async throws
    func abandon(_ upload: MoveMarkUpload) async -> MoveMarkAbandonResult
}

struct PendingEvidenceSyncResult {
    enum Failure: Error {
        /// The server couldn't be reached to create or check the entry; nothing was sent.
        case unreachable(Error)
        /// The Add photos target no longer exists; its photos moved to the room's new-entry set.
        case entryMissing
    }

    var entryId: UUID?
    /// Photos confirmed by this run, in order.
    var saved: [EvidencePhoto] = []
    /// Photos an earlier, interrupted attempt had in fact saved (found on the server).
    var alreadySaved = 0
    /// What is still on this iPhone for the key, for the retry.
    var pending: [MMPendingEvidence] = []
    /// Entry totals across attempts (for "2 of 3 photos saved").
    var savedTotal = 0
    var requestedTotal = 0
    var insertFailures = 0
    var tagsFailed = false
    /// No photo could be saved, so the empty entry was removed again.
    var entryRemoved = false
    var failure: Failure?
    /// Photos the entry already had confirmed when this run started (the manifest may be gone by the end).
    var priorSaved = 0

    var isComplete: Bool { pending.isEmpty && failure == nil }

    var photoResult: MMEvidenceSaveResult {
        MMEvidenceSaveResult(saved: saved, pending: pending, insertFailures: insertFailures)
    }
}

struct PendingEvidenceSync {
    let store: PendingEvidenceStore
    let backend: PendingEvidenceBackend

    // MARK: Sync

    /// Sends everything pending for `key`. Safe to call again at any point (after a failure, a relaunch, a
    /// kill mid-way): it settles what an earlier attempt left before sending anything new.
    func sync(_ key: PendingEvidenceKey) async -> PendingEvidenceSyncResult {
        var result = PendingEvidenceSyncResult()
        await store.settleInterrupted(key)
        await releaseQueued(key)
        guard let manifest = await store.manifest(for: key), !manifest.items.isEmpty else {
            return await finish(result, key)
        }
        result.priorSaved = manifest.savedCount
        let hadEntry = manifest.entryId != nil || key.appendTo != nil
        guard let entryId = try? await store.beginEntry(key) else {
            result.failure = .unreachable(CocoaError(.fileWriteUnknown))
            return await finish(result, key)
        }
        result.entryId = entryId

        // An earlier attempt may have got further than this iPhone recorded.
        if hadEntry {
            do {
                if let onServer = try await backend.entryPhotoIds(entryId: entryId) {
                    let saved = Set(manifest.items.map(\.id)).intersection(onServer)
                    if !saved.isEmpty {
                        await store.confirm(saved, in: key)
                        result.alreadySaved = saved.count
                    }
                } else if key.appendTo != nil {
                    try? await store.rehomeToNewEntry(key)
                    result.failure = .entryMissing
                    return await finish(result, key)
                }
            } catch {
                await store.markFailed(manifest.items.map(\.id), in: key)
                result.failure = .unreachable(error)
                return await finish(result, key)
            }
        }
        guard let current = await store.manifest(for: key), !current.items.isEmpty else {
            return await finish(result, key)
        }

        if key.appendTo == nil {
            let title = current.draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? current.roomName : current.draft.title
            do {
                result.tagsFailed = try await backend.ensureEntry(id: entryId, key: key, title: title, draft: current.draft)
            } catch {
                await store.markFailed(current.items.map(\.id), in: key)
                result.failure = .unreachable(error)
                return await finish(result, key)
            }
        }

        await store.markUploading(current.items.map(\.id), in: key)
        for item in current.items {
            if let photo = await send(item, entryId: entryId, key: key, result: &result) {
                result.saved.append(photo)
            }
        }

        // Nothing of this new entry saved and nothing outstanding: remove the empty entry again (the next
        // attempt recreates it under the same id). Only when the server confirms it holds no photo.
        if key.appendTo == nil, result.saved.isEmpty, result.alreadySaved == 0,
           let left = await store.manifest(for: key), left.savedCount == 0,
           left.items.allSatisfy({ $0.unresolved == nil }),
           (try? await backend.entryPhotoIds(entryId: entryId))?.isEmpty == true,
           (try? await backend.deleteEntry(id: entryId)) != nil {
            result.entryRemoved = true
        }
        return await finish(result, key)
    }

    /// One photo: settle an earlier upload, upload (ticket recorded first), insert, confirm.
    private func send(_ item: PendingEvidenceItem, entryId: UUID, key: PendingEvidenceKey,
                      result: inout PendingEvidenceSyncResult) async -> EvidencePhoto? {
        if let earlier = item.unresolved {
            switch await backend.abandon(earlier.moveMarkUpload) {
            case .kept:   // its row committed last time; only the response (or the app) was lost
                await store.confirm([item.id], in: key)
                return Self.photo(item.id, earlier.moveMarkUpload)
            case .deleted:
                await store.setUnresolved(nil, for: item.id, in: key)
            case .failed:  // still unknown: uploading again could duplicate it
                await store.markFailed([item.id], in: key)
                return nil
            }
        }
        guard let source = await store.source(for: item, in: key) else {
            await store.markFailed([item.id], in: key)
            return nil
        }

        let store = store
        let upload: MoveMarkUpload
        do {
            upload = try await backend.upload(source, key: key) { ticket in
                await store.setUnresolved(PendingEvidenceUpload(ticket), for: item.id, in: key)
            }
        } catch {
            // The storage service released the ticket unless it says otherwise.
            await store.setUnresolved((error as? MoveMarkUploadFailure)?.unreleased.map(PendingEvidenceUpload.init),
                                      for: item.id, in: key)
            await store.markFailed([item.id], in: key)
            return nil
        }
        await store.setUnresolved(PendingEvidenceUpload(upload), for: item.id, in: key)

        do {
            try await backend.insertPhoto(rowId: item.id, entryId: entryId, key: key, upload: upload)
            await store.confirm([item.id], in: key)
            return Self.photo(item.id, upload)
        } catch {
            result.insertFailures += 1
            switch await backend.abandon(upload) {
            case .kept:
                await store.confirm([item.id], in: key)
                return Self.photo(item.id, upload)
            case .deleted:
                await store.setUnresolved(nil, for: item.id, in: key)
                await store.markFailed([item.id], in: key)
            case .failed:
                await store.markFailed([item.id], in: key)
            }
            return nil
        }
    }

    private func finish(_ result: PendingEvidenceSyncResult, _ key: PendingEvidenceKey) async -> PendingEvidenceSyncResult {
        var result = result
        let manifest = await store.manifest(for: key)
        let items = manifest?.items ?? []
        var pending: [MMPendingEvidence] = []
        for item in items {
            guard let source = await store.source(for: item, in: key) else { continue }
            pending.append(MMPendingEvidence(source: source, id: item.id, unresolved: item.unresolved?.moveMarkUpload))
        }
        result.pending = pending
        result.savedTotal = max(manifest?.savedCount ?? 0, result.priorSaved + result.alreadySaved + result.saved.count)
        result.requestedTotal = max(manifest?.requestedCount ?? 0, result.savedTotal + pending.count)
        if result.entryId == nil { result.entryId = manifest?.entryId }
        return result
    }

    // MARK: Reconcile

    enum ReconcileOutcome: Equatable {
        /// Nothing pending or to settle.
        case nothing
        /// The server couldn't be asked; everything stays as it was.
        case unknown
        /// Checked: `alreadySaved` photos were in fact saved; `remaining` still need sending.
        case checked(alreadySaved: Int, remaining: Int)
        /// The Add photos target is gone; its photos are now the room's new-entry set.
        case rehomed
    }

    /// Settles what an earlier visit or an interrupted save left, without sending any photo: releases
    /// queued uploads, confirms photos whose rows exist, removes an entry that ended up empty with nothing
    /// left to send. Run when a room opens and at launch for every room with leftovers.
    @discardableResult
    func reconcile(_ key: PendingEvidenceKey) async -> ReconcileOutcome {
        await store.settleInterrupted(key)
        await releaseQueued(key)
        guard let manifest = await store.manifest(for: key) else { return .nothing }
        guard let entryId = manifest.entryId else {
            return manifest.items.isEmpty ? .nothing : .checked(alreadySaved: 0, remaining: manifest.items.count)
        }
        let onServer: Set<UUID>?
        do {
            onServer = try await backend.entryPhotoIds(entryId: entryId)
        } catch {
            return .unknown
        }
        guard let onServer else {
            if key.appendTo != nil, !manifest.items.isEmpty {
                try? await store.rehomeToNewEntry(key)
                return .rehomed
            }
            // Never created (or emptied and removed): a later save recreates it under the same id.
            if manifest.items.isEmpty { await store.entrySettled(key, savedOnServer: 0) }
            return .checked(alreadySaved: 0, remaining: manifest.items.count)
        }
        let saved = Set(manifest.items.map(\.id)).intersection(onServer)
        if !saved.isEmpty { await store.confirm(saved, in: key) }
        let remaining = manifest.items.count - saved.count
        if remaining == 0, key.appendTo == nil {
            if onServer.isEmpty {
                // Created, then the app stopped (or the renter discarded the photos) before any photo landed.
                guard (try? await backend.deleteEntry(id: entryId)) != nil else { return .unknown }
            }
            await store.entrySettled(key, savedOnServer: onServer.count)
        }
        return .checked(alreadySaved: saved.count, remaining: remaining)
    }

    /// Reconciles every room of `userId` that has something on this iPhone.
    func reconcileAll(userId: UUID) async {
        for manifest in await store.manifests(userId: userId) {
            await reconcile(manifest.key)
        }
    }

    /// Releases uploads of photos the renter dropped while their outcome was unknown.
    private func releaseQueued(_ key: PendingEvidenceKey) async {
        guard let queued = await store.manifest(for: key)?.cleanup, !queued.isEmpty else { return }
        for upload in queued where await backend.abandon(upload.moveMarkUpload) != .failed {
            await store.dropCleanup(upload, in: key)
        }
    }

    private static func photo(_ id: UUID, _ upload: MoveMarkUpload) -> EvidencePhoto {
        EvidencePhoto(id: id, filePath: upload.path, thumbnailPath: upload.thumbnailPath)
    }
}

// MARK: - Live backend

/// The app's backend: MoveMark API storage tickets + the Data API rows.
struct LivePendingEvidenceBackend: PendingEvidenceBackend {
    private var repo: InspectionRepository { InspectionRepository() }

    func ensureEntry(id: UUID, key: PendingEvidenceKey, title: String, draft: PendingEvidenceDraft) async throws -> Bool {
        let inspectionId = try await repo.upsertInspection(propertyId: key.propertyId, userId: key.userId,
                                                           type: key.stage == .moveOut ? "move_out" : "move_in")
        try await repo.ensureInspectionItem(id: id, inspectionId: inspectionId, roomId: key.roomId,
                                            notes: "\(title)\n\(draft.notes)",
                                            conditionRating: Self.conditionValue(draft.condition))
        guard !draft.tags.isEmpty else { return false }
        do {
            // Replace, so a repeated create never duplicates tag links.
            try await repo.deleteItemTagsForInspectionItem(inspectionItemId: id)
            try await repo.insertItemTags(inspectionItemId: id, tagNames: draft.tags)
            return false
        } catch {
            return true
        }
    }

    func entryPhotoIds(entryId: UUID) async throws -> Set<UUID>? {
        try await repo.evidenceFileIds(inspectionItemId: entryId)
    }

    func deleteEntry(id: UUID) async throws {
        try await repo.deleteInspectionItem(id: id)
    }

    func upload(_ source: MMEvidenceSource, key: PendingEvidenceKey,
                onTicket: @escaping (MoveMarkUpload) async -> Void) async throws -> MoveMarkUpload {
        try await MoveMarkStorageService.shared.uploadEvidence(source, propertyId: key.propertyId, roomId: key.roomId,
                                                               isMoveOut: key.stage == .moveOut, onTicket: onTicket)
    }

    func insertPhoto(rowId: UUID, entryId: UUID, key: PendingEvidenceKey, upload: MoveMarkUpload) async throws {
        try await repo.insertEvidenceFile(
            id: rowId, propertyId: key.propertyId, inspectionItemId: entryId, maintenanceIssueId: nil,
            filePath: upload.path, thumbnailPath: upload.thumbnailPath, sourcePath: upload.sourcePath,
            fileType: "image", capturedAt: upload.capturedAt ?? Date()
        )
    }

    func abandon(_ upload: MoveMarkUpload) async -> MoveMarkAbandonResult {
        await MoveMarkStorageService.shared.abandon(upload)
    }

    /// `condition_rating`: poor 1 … excellent 5.
    static func conditionValue(_ raw: String) -> Int {
        switch RoomRecord.ConditionRating(rawValue: raw) ?? .good {
        case .excellent: return 5
        case .good: return 4
        case .fair: return 3
        case .belowFair: return 2
        case .poor: return 1
        }
    }
}
