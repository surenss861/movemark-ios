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

        let photoData = loadedImages.compactMap { $0.jpegData(compressionQuality: 0.82) }

        Task { @MainActor in
            defer { isUploading = false }

            do {
                let outcome: PropertyMutationOutcome
                if moveOutMode {
                    let hadZeroMoveOutEvidenceBefore = (room?.moveOutEvidence.isEmpty == true)
                    outcome = try await propertyStore.addMoveOutEvidence(
                        to: roomID,
                        evidence: evidence,
                        photos: photoData,
                        propertyId: property.id,
                        userId: userId
                    )
                    if hadZeroMoveOutEvidenceBefore {
                        propertyStore.pendingVaultFeedback = .moveOutRoomCompleted(roomName: roomName)
                    }
                } else {
                    outcome = try await propertyStore.addEvidence(
                        to: roomID,
                        evidence: evidence,
                        photos: photoData,
                        propertyId: property.id,
                        userId: userId
                    )

                    let isNowDocumented = isRoomCurrentlyDocumented
                    if wasDocumentedOnLoad == false && isNowDocumented == true {
                        propertyStore.pendingVaultFeedback = .roomCompleted(roomName: roomName)
                        wasDocumentedOnLoad = true
                    }
                }

                errorMessage = nil

                MoveMarkAnalytics.track(
                    .photoAdded,
                    properties: [
                        "count": "\(photoData.count)",
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

                if let onFirstProofSaved, let property = propertyStore.currentProperty {
                    let issueCount = evidence.issueTags.count
                    onFirstProofSaved(
                        FirstRunSavedSummary(
                            propertyId: property.id,
                            roomName: roomName,
                            photoCount: photoData.count,
                            issueCount: issueCount,
                            savedAt: Date()
                        )
                    )
                    MMHaptics.success()
                    return
                }

                title = ""
                notes = ""
                selectedTags = []
                selectedCondition = .good
                selectedItems = []
                loadedImages = []
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
            } catch {
                #if DEBUG
                print("ROOM SAVE FAILED:", error.localizedDescription)
                #endif
                errorMessage = MoveMarkFlowMessage.proofSaveFailed(error)
                MMHaptics.error()
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

    /// - Returns: `nil` if photos were appended; otherwise a user-facing message (also assigned to `errorMessage` for the capture screen).
    @discardableResult
    func appendPhotos(to entryId: UUID, photoData: [Data]) async -> String? {
        guard !photoData.isEmpty else {
            let msg = "Choose at least one photo to add."
            errorMessage = msg
            MMHaptics.warning()
            return msg
        }

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
            let outcome = try await propertyStore.appendPhotosToEvidence(
                entryId: entryId,
                roomId: roomID,
                photos: photoData,
                propertyId: property.id,
                userId: userId,
                isMoveOut: moveOutMode
            )
            errorMessage = nil
            var msg = "Photos added to entry."
            if outcome.hydrationRefreshFailed { msg += MoveMarkFlowMessage.proofHydrationHint }
            successMessage = msg
            MMHaptics.success()
            return nil
        } catch {
            let msg = MoveMarkFlowMessage.proofAppendPhotosFailed(error)
            errorMessage = msg
            MMHaptics.error()
            return msg
        }
    }
}
