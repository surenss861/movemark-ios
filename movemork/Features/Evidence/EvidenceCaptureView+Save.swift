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
            errorMessage = "No active property loaded."
            return
        }

        guard let userId = sessionManager.userId else {
            errorMessage = "You need to sign in again."
            return
        }

        guard !isUploading else { return }

        if loadedImages.isEmpty {
            errorMessage = "Add at least one photo."
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
                if moveOutMode {
                    try await propertyStore.addMoveOutEvidence(
                        to: roomID,
                        evidence: evidence,
                        photos: photoData,
                        propertyId: property.id,
                        userId: userId
                    )
                } else {
                    try await propertyStore.addEvidence(
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

                title = ""
                notes = ""
                selectedTags = []
                selectedCondition = .good
                selectedItems = []
                loadedImages = []
                successMessage = moveOutMode
                    ? "Move-out proof saved. Thumbnails may take a moment to appear."
                    : "Proof saved. Thumbnails may take a moment to appear."

                MMHaptics.success()

                withAnimation(MMMotion.fastFade) {
                    didJustSave = true
                }

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
                errorMessage = userFacingEvidenceError(from: error)
            }
        }
    }

    func deleteEntry(_ entryId: UUID) async {
        guard let property = propertyStore.currentProperty else {
            errorMessage = "No active property loaded."
            return
        }

        guard let userId = sessionManager.userId else {
            errorMessage = "You need to sign in again."
            return
        }

        do {
            try await propertyStore.deleteEvidence(
                entryId: entryId,
                propertyId: property.id,
                userId: userId
            )
            successMessage = "Entry removed."
            MMHaptics.success()
        } catch {
            errorMessage = userFacingEvidenceError(from: error)
        }
    }

    func saveEditedEvidence(
        entryId: UUID,
        title: String,
        notes: String,
        tags: [String],
        condition: RoomRecord.ConditionRating
    ) async {
        guard let property = propertyStore.currentProperty else {
            errorMessage = "No active property loaded."
            return
        }

        guard let userId = sessionManager.userId else {
            errorMessage = "You need to sign in again."
            return
        }

        do {
            try await propertyStore.updateEvidence(
                entryId: entryId,
                title: title,
                notes: notes,
                tags: tags,
                condition: condition,
                propertyId: property.id,
                userId: userId
            )
            successMessage = "Entry updated."
            MMHaptics.success()
        } catch {
            errorMessage = userFacingEvidenceError(from: error)
        }
    }

    func appendPhotos(to entryId: UUID, photoData: [Data]) async {
        guard !photoData.isEmpty else { return }

        guard let property = propertyStore.currentProperty else {
            errorMessage = "No active property loaded."
            return
        }

        guard let userId = sessionManager.userId else {
            errorMessage = "You need to sign in again."
            return
        }

        do {
            try await propertyStore.appendPhotosToEvidence(
                entryId: entryId,
                roomId: roomID,
                photos: photoData,
                propertyId: property.id,
                userId: userId,
                isMoveOut: moveOutMode
            )
            successMessage = "Photos added to entry."
            MMHaptics.success()
        } catch {
            errorMessage = userFacingEvidenceError(from: error)
        }
    }

    private func userFacingEvidenceError(from error: Error) -> String {
        UserFacingDatabaseError.message(from: error, fallback: "Couldn’t save proof. Try again.")
    }
}
