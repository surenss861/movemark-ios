//
//  EvidenceCaptureView+Save.swift
//  movemork
//
//  Save, delete, edit, append photos.
//

import SwiftUI

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

        guard !isUploading else { return }

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

        let evidence = EvidenceRecord(
            title: title.isEmpty ? roomName : title,
            notes: notes,
            issueTags: Array(selectedTags),
            condition: selectedCondition,
            photoCount: loadedImages.count,
            photos: [],
            stage: moveOutMode ? .moveOut : .moveIn
        )

        // One row id per photo for every attempt; previews follow the photos into a retry.
        let photos = loadedSources.map { MMPendingEvidence(source: $0) }
        let previews = Dictionary(uniqueKeysWithValues: zip(photos.map(\.id), loadedImages))

        Task { @MainActor in
            defer { isUploading = false }

            do {
                let outcome: PropertyMutationOutcome
                if moveOutMode {
                    let hadZeroMoveOutEvidenceBefore = (room?.moveOutEvidence.isEmpty == true)
                    outcome = try await propertyStore.addMoveOutEvidence(
                        to: roomID,
                        evidence: evidence,
                        photos: photos,
                        propertyId: property.id,
                        userId: userId
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
                        userId: userId
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
                loadedImages = []
                loadedSources = []

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
                // Nothing was saved and the entry was removed: the photos stay pending as they were.
                errorMessage = MoveMarkFlowMessage.proofSaveFailed(error)
                errorSource = .save
                MMHaptics.error()
            }
        }
    }

    /// Retries only the photos of `pendingRetry`, appending them to the entry that already holds the rest.
    private func retryPendingPhotos(propertyId: UUID, userId: UUID) {
        guard var retry = pendingRetry, !isUploading else { return }
        errorMessage = nil
        successMessage = nil
        isUploading = true
        Task { @MainActor in
            defer { isUploading = false }
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

    var statusLine: String { MMEvidenceSaveStatus.partial(saved: savedCount, requested: requestedCount) }
    var pendingPreviews: [UIImage] { pending.compactMap { previews[$0.id] } }
}
