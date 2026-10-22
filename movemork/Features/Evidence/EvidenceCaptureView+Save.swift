//
//  EvidenceCaptureView+Save.swift
//  movemork
//
//  Save, delete, edit, append photos.
//

import SwiftUI

extension EvidenceCaptureView {
    func saveEvidence() {
        guard let property = propertyStore.currentProperty else {
            errorMessage = MoveMarkFlowMessage.noActiveProperty
            return
        }

        guard let userId = sessionManager.userId else {
            errorMessage = MoveMarkFlowMessage.signInRequired
            return
        }

        guard !isUploading else { return }

        if loadedImages.isEmpty {
            if pendingRetry != nil {
                retryPendingPhotos(propertyId: property.id, userId: userId)
                return
            }
            errorMessage = "Add at least one photo before saving."
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
                    } else {
                        errorMessage = MMEvidenceSaveStatus.partial(saved: result.saved.count, requested: result.requestedCount)
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
            retry.savedCount += result.saved.count
            retry.pending = result.pending
            guard retry.pending.isEmpty else {
                pendingRetry = retry
                MMHaptics.warning()
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

        var msg = moveOutMode
            ? "Move-out proof saved. Thumbnails may take a moment to appear."
            : "Proof saved. Thumbnails may take a moment to appear."
        if outcome.hydrationRefreshFailed {
            msg += MoveMarkFlowMessage.proofHydrationHint
        }
        if outcome.tagInsertFailed {
            msg += MoveMarkFlowMessage.tagInsertFailedHint
        }
        successMessage = msg

        MMProofToastPresenter.show(
            .proofSaved(moveOut: moveOutMode),
            message: $proofToast,
            isVisible: $proofToastVisible
        )

        withAnimation(MMMotion.fastFade) {
            didJustSave = true
        }
        proofScanlineTrigger += 1

        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            await MainActor.run {
                withAnimation(MMMotion.fastFade) {
                    didJustSave = false
                }
            }
        }
    }

    func deleteEntry(_ entryId: UUID) async {
        guard let property = propertyStore.currentProperty else {
            errorMessage = MoveMarkFlowMessage.noActiveProperty
            return
        }

        guard let userId = sessionManager.userId else {
            errorMessage = MoveMarkFlowMessage.signInRequired
            return
        }

        do {
            let outcome = try await propertyStore.deleteEvidence(
                entryId: entryId,
                propertyId: property.id,
                userId: userId
            )
            errorMessage = nil
            var msg = "Entry removed."
            if outcome.hydrationRefreshFailed { msg += MoveMarkFlowMessage.proofHydrationHint }
            successMessage = msg
            MMHaptics.success()
        } catch {
            errorMessage = MoveMarkFlowMessage.proofDeleteFailed(error)
            MMHaptics.error()
        }
    }

    /// - Returns: `nil` on success, user-facing message on failure (also sets `errorMessage`).
    @discardableResult
    func saveEditedEvidence(
        entryId: UUID,
        title: String,
        notes: String,
        tags: [String],
        condition: RoomRecord.ConditionRating
    ) async -> String? {
        guard let property = propertyStore.currentProperty else {
            let msg = MoveMarkFlowMessage.noActiveProperty
            errorMessage = msg
            MMHaptics.error()
            return msg
        }

        guard let userId = sessionManager.userId else {
            let msg = MoveMarkFlowMessage.signInRequired
            errorMessage = msg
            MMHaptics.error()
            return msg
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
            errorMessage = nil
            var msg = "Entry updated."
            if outcome.hydrationRefreshFailed { msg += MoveMarkFlowMessage.proofHydrationHint }
            successMessage = msg
            MMHaptics.success()
            return nil
        } catch {
            let msg = MoveMarkFlowMessage.proofUpdateFailed(error)
            errorMessage = msg
            MMHaptics.error()
            return msg
        }
    }

    /// Appends to an existing entry. Returns the photos that still need a retry (empty when all were
    /// saved) and a message for the sheet; the saved ones are never sent again.
    func appendPhotos(to entryId: UUID, photos: [MMPendingEvidence]) async -> (pending: [MMPendingEvidence], message: String?) {
        guard !photos.isEmpty else {
            let msg = "Choose at least one photo to add."
            errorMessage = msg
            MMHaptics.warning()
            return (photos, msg)
        }

        guard let property = propertyStore.currentProperty else {
            let msg = MoveMarkFlowMessage.noActiveProperty
            errorMessage = msg
            MMHaptics.error()
            return (photos, msg)
        }

        guard let userId = sessionManager.userId else {
            let msg = MoveMarkFlowMessage.signInRequired
            errorMessage = msg
            MMHaptics.error()
            return (photos, msg)
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
        guard result.isComplete else {
            MMHaptics.warning()
            return (result.pending, MMEvidenceSaveStatus.partial(saved: result.saved.count, requested: result.requestedCount))
        }
        errorMessage = nil
        var msg = "Photos added to entry."
        if outcome.hydrationRefreshFailed { msg += MoveMarkFlowMessage.proofHydrationHint }
        successMessage = msg
        MMHaptics.success()
        return ([], nil)
    }
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
