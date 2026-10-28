//
//  EvidenceCaptureView+Save.swift
//  movemork
//
//  Save, delete, edit, append photos.
//

import SwiftUI
import UIKit

extension EvidenceCaptureView {
    func saveEvidence() {
        // Notices raised here are save errors (`errorSource = .save`): their "Try again" runs this again.
        guard let property = propertyStore.currentProperty else {
            errorMessage = MoveMarkFlowMessage.noActiveProperty
            errorSource = .save
            return
        }

        guard let userId = sessionManager.userId else {
            errorMessage = MoveMarkFlowMessage.signInRequired
            errorSource = .save
            return
        }

        guard !isUploading, !isCheckingSaved else { return }

        if loadedImages.isEmpty {
            if pendingRetry != nil {
                retryPendingPhotos(propertyId: property.id, userId: userId)
                return
            }
            errorMessage = "Add at least one photo before saving."
            errorSource = .none
            MMHaptics.warning()
            return
        }

        errorMessage = nil
        successMessage = nil
        isUploading = true
        uploadingCount = loadedSources.count

        let evidence = EvidenceRecord(
            title: title.isEmpty ? roomName : title,
            notes: notes,
            issueTags: Array(selectedTags),
            condition: selectedCondition,
            photoCount: loadedImages.count,
            photos: [],
            stage: moveOutMode ? .moveOut : .moveIn
        )

        // One row id per photo for every attempt (the id it got at capture, also its file on this iPhone);
        // previews follow the photos into a retry.
        let photos = loadedSources
        let previews = Dictionary(uniqueKeysWithValues: zip(photos.map(\.id), loadedImages))
        let key = pendingKey
        let ids = photos.map(\.id)
        let draft = currentDraft
        let center = pendingCenter
        // Lets a short save finish if the renter leaves the app; if iOS stops it anyway, the photos are
        // still on this iPhone (marked uploading → failed at the next launch) and retryable.
        let background = EvidenceBackgroundTask(name: "Save room evidence")

        Task { @MainActor in
            defer {
                isUploading = false
                background.end()
            }
            if let key {
                await center.perform(key.userId) { await $0.markUploading(ids, in: key, draft: draft) }.value
            }
            // Recorded the moment the entry exists, so a save cut off mid-way still knows where its photos went.
            let onEntryCreated: (UUID) async -> Void = { entryId in
                guard let key else { return }
                await center.perform(key.userId) {
                    await $0.setEntry(entryId, savedCount: 0, requestedCount: ids.count, in: key)
                }.value
            }

            do {
                let outcome: PropertyMutationOutcome
                if moveOutMode {
                    let hadZeroMoveOutEvidenceBefore = (room?.moveOutEvidence.isEmpty == true)
                    outcome = try await propertyStore.addMoveOutEvidence(
                        to: roomID,
                        evidence: evidence,
                        photos: photos,
                        propertyId: property.id,
                        userId: userId,
                        onEntryCreated: onEntryCreated
                    )
                    if hadZeroMoveOutEvidenceBefore, outcome.photoResult?.saved.isEmpty == false {
                        propertyStore.pendingVaultFeedback = .moveOutRoomCompleted(roomName: roomName)
                    }
                } else {
                    outcome = try await propertyStore.addEvidence(
                        to: roomID,
                        evidence: evidence,
                        photos: photos,
                        propertyId: property.id,
                        userId: userId,
                        onEntryCreated: onEntryCreated
                    )

                    let isNowDocumented = isRoomCurrentlyDocumented
                    if wasDocumentedOnLoad == false && isNowDocumented == true {
                        propertyStore.pendingVaultFeedback = .roomCompleted(roomName: roomName)
                        wasDocumentedOnLoad = true
                    }
                }

                let result = outcome.photoResult ?? MMEvidenceSaveResult()
                errorMessage = nil
                propertyStore.invalidateVaultSummaries()
                // Confirmed rows leave this iPhone; the rest stay, failed, tied to the entry for their retry.
                if let key {
                    recordSaveResult(result, entryId: outcome.entryId, savedSoFar: result.saved.count,
                                     requested: result.requestedCount, key: key)
                }

                MoveMarkAnalytics.track(
                    .photoAdded,
                    properties: [
                        "count": "\(result.saved.count)",
                        "move_out": moveOutMode ? "1" : "0",
                    ]
                )
                if !evidence.issueTags.isEmpty {
                    MoveMarkAnalytics.track(
                        .issueTagged,
                        properties: ["count": "\(evidence.issueTags.count)"]
                    )
                }
                if !evidence.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    MoveMarkAnalytics.track(.noteAdded)
                }

                // The entry exists now: the form is done with either way. Photos that didn't make it move
                // into the retry state (and out of the picker selection, so they can't be re-added twice).
                title = ""
                notes = ""
                selectedTags = []
                selectedCondition = .good
                selectedItems = []
                pickerItemIDs = []
                loadedImages = []
                loadedSources = []
                uploadFailed = false

                guard result.isComplete else {
                    if let entryId = outcome.entryId {
                        pendingRetry = EvidenceRetryState(
                            entryId: entryId,
                            pending: result.pending,
                            previews: previews,
                            savedCount: result.saved.count,
                            requestedCount: result.requestedCount,
                            issueCount: evidence.issueTags.count,
                            outcomeHints: outcome
                        )
                        if !result.saved.isEmpty {
                            presentReceipt(photoCount: result.saved.count, pendingCount: result.pending.count,
                                           issueCount: evidence.issueTags.count, photo: result.saved.first)
                        }
                    } else {
                        errorMessage = MMEvidenceSaveStatus.partial(saved: result.saved.count, requested: result.requestedCount)
                        errorSource = .none   // no entry to append to: nothing a retry could resend
                    }
                    MMHaptics.warning()
                    return
                }
                presentSaveSuccess(photoCount: result.saved.count, issueCount: evidence.issueTags.count, outcome: outcome)
            } catch {
                #if DEBUG
                print("ROOM SAVE FAILED:", error.localizedDescription)
                #endif
                // Nothing was saved and the entry was removed: the photos stay pending as they were (on this
                // iPhone too, marked failed and no longer tied to an entry).
                uploadFailed = true
                if let key {
                    center.perform(key.userId) { store in
                        await store.setEntry(nil, savedCount: 0, requestedCount: 0, in: key)
                        await store.markFailed(ids, in: key)
                    }
                }
                errorMessage = MoveMarkFlowMessage.proofSaveFailed(error)
                errorSource = .save
                MMHaptics.error()
            }
        }
    }

    /// Retries only the photos of `pendingRetry`, appending them to the entry that already holds the rest.
    private func retryPendingPhotos(propertyId: UUID, userId: UUID) {
        guard pendingRetry != nil, !isUploading, !isCheckingSaved else { return }
        errorMessage = nil
        successMessage = nil
        let key = pendingKey
        let center = pendingCenter
        Task { @MainActor in
            // Restored after a relaunch: first ask which photos already made it.
            guard await reconcileRestoredRetry() else {
                saveEvidence()   // the entry is gone: the photos were returned to the form as a new entry
                return
            }
            guard var retry = pendingRetry, !isUploading else { return }
            isUploading = true
            uploadingCount = retry.pending.count
            let background = EvidenceBackgroundTask(name: "Retry room evidence")
            defer {
                isUploading = false
                background.end()
            }
            if let key {
                let ids = retry.pending.map(\.id)
                await center.perform(key.userId) { await $0.markUploading(ids, in: key) }.value
            }
            let outcome = await propertyStore.appendPhotosToEvidence(
                entryId: retry.entryId,
                roomId: roomID,
                photos: retry.pending,
                propertyId: propertyId,
                userId: userId,
                isMoveOut: moveOutMode
            )
            let result = outcome.photoResult ?? MMEvidenceSaveResult()
            if !result.saved.isEmpty { propertyStore.invalidateVaultSummaries() }
            retry.savedCount += result.saved.count
            retry.pending = result.pending
            if let key {
                recordSaveResult(result, entryId: retry.entryId, savedSoFar: retry.savedCount,
                                 requested: retry.requestedCount, key: key)
            }
            guard retry.pending.isEmpty else {
                pendingRetry = retry
                MMHaptics.warning()
                if !result.saved.isEmpty {
                    presentReceipt(photoCount: retry.savedCount, pendingCount: retry.pending.count, issueCount: retry.issueCount,
                                   photo: result.saved.first)
                }
                return
            }
            pendingRetry = nil
            var merged = outcome
            merged.tagInsertFailed = retry.outcomeHints.tagInsertFailed
            presentSaveSuccess(photoCount: retry.savedCount, issueCount: retry.issueCount, outcome: merged)
        }
    }

    /// Mirrors a save's result on this iPhone: confirmed photos are removed (the server has their rows);
    /// the rest are marked failed, keep any unresolved upload, and stay tied to the entry for their retry.
    private func recordSaveResult(_ result: MMEvidenceSaveResult, entryId: UUID?, savedSoFar: Int, requested: Int,
                                  key: PendingEvidenceKey) {
        let saved = result.saved.map(\.id)
        let failed = result.pending.map(\.id)
        let unresolved = Dictionary(uniqueKeysWithValues: result.pending.compactMap { item in
            item.unresolved.map { (item.id, PendingEvidenceUpload($0)) }
        })
        pendingCenter.perform(key.userId) { store in
            await store.remove(saved, from: key)
            guard !failed.isEmpty else { return }
            await store.markFailed(failed, unresolved: unresolved, in: key)
            await store.setEntry(entryId, savedCount: savedSoFar, requestedCount: requested, in: key)
        }
    }

    /// A restored partial save turned out to be complete on the server.
    func showSyncToast(savedCount: Int) {
        showToast(.success, savedCount == 1 ? "1 photo saved" : "\(savedCount) photos saved")
    }

    /// Full success: only reached when every photo the user asked to save is confirmed saved.
    private func presentSaveSuccess(photoCount: Int, issueCount: Int, outcome: PropertyMutationOutcome) {
        if let onFirstProofSaved, let property = propertyStore.currentProperty {
            onFirstProofSaved(
                FirstRunSavedSummary(
                    propertyId: property.id,
                    roomName: roomName,
                    photoCount: photoCount,
                    issueCount: issueCount,
                    savedAt: Date()
                )
            )
            MMHaptics.success()
            return
        }

        var hints = ""
        if outcome.hydrationRefreshFailed { hints += MoveMarkFlowMessage.proofHydrationHint }
        if outcome.tagInsertFailed { hints += MoveMarkFlowMessage.tagInsertFailedHint }
        if !hints.isEmpty { successMessage = hints.trimmingCharacters(in: .whitespaces) }
        presentReceipt(photoCount: photoCount, pendingCount: 0, issueCount: issueCount,
                       photo: outcome.photoResult?.saved.first)
    }

    /// The receipt after a save: what the backend confirmed, and the one next step.
    /// `photo` is one the save just confirmed (the receipt's image); nil shows no image, never another room's.
    private func presentReceipt(photoCount: Int, pendingCount: Int, issueCount: Int, photo: EvidencePhoto?) {
        let property = propertyStore.currentProperty
        // Photo totals, as on the comparison screen: a room with only empty entries still needs proof.
        let nextRoom = property?.rooms.first { room in
            room.id != roomID && (moveOutMode ? room.moveOutPhotoTotal : room.moveInPhotoTotal) == 0
        }
        let next: SavedRoomReceipt.Next
        if pendingCount > 0 {
            next = .retry
        } else if let nextRoom, onOpenRoom != nil {
            next = .room(nextRoom.id)
        } else if nextRoom == nil, onOpenReport != nil {
            next = .report
        } else {
            next = .done
        }
        MMHaptics.success()
        if let photo { MoveMarkStoredFileURLs.remember([photo]) }   // so the room's resolver can sign it
        savedReceipt = SavedRoomReceipt(
            propertyId: property?.id,
            roomName: roomName,
            phaseLabel: moveOutMode ? "Move-out" : "Move-in",
            photoCount: photoCount,
            pendingCount: pendingCount,
            issueCount: issueCount,
            savedAt: Date(),
            next: next,
            photoPath: photo.map { $0.thumbnailPath ?? $0.filePath }
        )
    }

    func handleReceiptAction(_ action: SavedRoomReceipt.Action, receipt: SavedRoomReceipt) {
        switch action {
        case .primary:
            switch receipt.next {
            case .room(let id): onOpenRoom?(id)
            case .report: onOpenReport?()
            case .retry: saveEvidence()   // with nothing new selected, this retries the pending photos
            case .done: break
            }
        case .viewEvidence:
            break                        // back to this room's evidence
        case .addMore:
            presentCameraIfAllowed()
        }
    }

    /// The result shows as the proof toast at the top (the row may be anywhere on the page). A failure also
    /// leaves a notice whose "Try again" retries this delete.
    func deleteEntry(_ entryId: UUID) async {
        guard !isDeleting else { return }
        guard let property = propertyStore.currentProperty else {
            showError(MoveMarkFlowMessage.noActiveProperty, source: .delete(entryId))
            return
        }

        guard let userId = sessionManager.userId else {
            showError(MoveMarkFlowMessage.signInRequired, source: .delete(entryId))
            return
        }

        isDeleting = true
        defer { isDeleting = false }
        do {
            let outcome = try await propertyStore.deleteEvidence(
                entryId: entryId,
                propertyId: property.id,
                userId: userId
            )
            propertyStore.invalidateVaultSummaries()
            if case .delete = errorSource { errorMessage = nil; errorSource = .none }
            showToast(.success, "Entry removed", hint: outcome.hydrationRefreshFailed)
        } catch {
            let msg = MoveMarkFlowMessage.proofDeleteFailed(error)
            errorMessage = msg
            errorSource = .delete(entryId)
            showToast(.danger, msg)
        }
    }

    /// - Returns: `nil` on success, user-facing message on failure (shown in the edit sheet, next to Save).
    @discardableResult
    func saveEditedEvidence(
        entryId: UUID,
        title: String,
        notes: String,
        tags: [String],
        condition: RoomRecord.ConditionRating
    ) async -> String? {
        guard let property = propertyStore.currentProperty else {
            MMHaptics.error()
            return MoveMarkFlowMessage.noActiveProperty
        }

        guard let userId = sessionManager.userId else {
            MMHaptics.error()
            return MoveMarkFlowMessage.signInRequired
        }

        do {
            let outcome = try await propertyStore.updateEvidence(
                entryId: entryId,
                title: title,
                notes: notes,
                tags: tags,
                condition: condition,
                propertyId: property.id,
                userId: userId
            )
            propertyStore.invalidateVaultSummaries()
            showToast(.success, "Entry updated", hint: outcome.hydrationRefreshFailed)
            return nil
        } catch {
            MMHaptics.error()
            return MoveMarkFlowMessage.proofUpdateFailed(error)
        }
    }

    /// Appends to an existing entry. Returns the photos that still need a retry (empty when all were
    /// saved) and a message for the sheet; the saved ones are never sent again. Success shows the proof toast.
    func appendPhotos(to entryId: UUID, photos: [MMPendingEvidence]) async -> (pending: [MMPendingEvidence], message: String?) {
        guard !photos.isEmpty else {
            MMHaptics.warning()
            return (photos, "Choose at least one photo to add.")
        }

        guard let property = propertyStore.currentProperty else {
            MMHaptics.error()
            return (photos, MoveMarkFlowMessage.noActiveProperty)
        }

        guard let userId = sessionManager.userId else {
            MMHaptics.error()
            return (photos, MoveMarkFlowMessage.signInRequired)
        }

        let outcome = await propertyStore.appendPhotosToEvidence(
            entryId: entryId,
            roomId: roomID,
            photos: photos,
            propertyId: property.id,
            userId: userId,
            isMoveOut: moveOutMode
        )
        let result = outcome.photoResult ?? MMEvidenceSaveResult(pending: photos)
        if !result.saved.isEmpty { propertyStore.invalidateVaultSummaries() }
        guard result.isComplete else {
            MMHaptics.warning()
            return (result.pending, MMEvidenceSaveStatus.partial(saved: result.saved.count, requested: result.requestedCount))
        }
        showToast(.success, result.saved.count == 1 ? "1 photo added" : "\(result.saved.count) photos added",
                  hint: outcome.hydrationRefreshFailed)
        return ([], nil)
    }

    /// A notice in the room body; `source` decides what its "Try again" does.
    func showError(_ message: String, source: EvidenceErrorSource) {
        errorMessage = message
        errorSource = source
        MMHaptics.error()
    }

    /// Delete / edit / append feedback: the room's proof toast (it plays the haptic).
    private func showToast(_ kind: MMProofToastMessage.Kind, _ title: String, hint: Bool = false) {
        let detail = hint ? MoveMarkFlowMessage.proofHydrationHint.trimmingCharacters(in: .whitespaces) : nil
        MMProofToastPresenter.show(
            MMProofToastMessage(kind: kind, title: title, message: detail),
            message: $proofToast,
            isVisible: $proofToastVisible
        )
    }
}

/// Where the room's current notice came from, so "Try again" repeats the right thing.
enum EvidenceErrorSource {
    case none
    case save
    case delete(UUID)
    case history(() async throws -> Void)
}

/// Photos of a just-saved entry that didn't make it. Retried on their own — never together with the
/// photos already saved — until every requested photo is confirmed; only then is the save a success.
struct EvidenceRetryState {
    let entryId: UUID
    var pending: [MMPendingEvidence]
    /// Display-only previews by pending photo id.
    let previews: [UUID: UIImage]
    var savedCount: Int
    let requestedCount: Int
    let issueCount: Int
    /// The first attempt's outcome (tag insert result) for the eventual success message.
    let outcomeHints: PropertyMutationOutcome
    /// Restored from this iPhone after a relaunch: which photos already have rows isn't known yet.
    var needsServerCheck: Bool = false

    var statusLine: String { MMEvidenceSaveStatus.partial(saved: savedCount, requested: requestedCount) }
    var pendingPreviews: [UIImage] { pending.compactMap { previews[$0.id] } }
}

/// A background-task assertion around a save: lets a short upload finish when the renter leaves the app.
/// On expiry it just ends; the photos stay on this iPhone and the interrupted save is retryable.
final class EvidenceBackgroundTask {
    private var identifier: UIBackgroundTaskIdentifier = .invalid

    init(name: String) {
        identifier = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            self?.end()
        }
    }

    func end() {
        guard identifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifier)
        identifier = .invalid
    }
}
