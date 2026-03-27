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
                    ? "Move-out proof saved to your vault."
                    : "Proof saved to your vault."

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
        let raw = error.localizedDescription.lowercased()
        if raw.contains("not authenticated") || raw.contains("jwt") || raw.contains("session") {
            return "Session expired. Please sign in again."
        }
        if raw.contains("inspection") || raw.contains("type_check") || raw.contains("constraint") {
            return "Couldn’t save proof right now. Try again."
        }
        if raw.contains("bucket") || raw.contains("storage") || raw.contains("not found") {
            return "Upload storage is unavailable right now. Try again soon."
        }
        if raw.contains("network") || raw.contains("offline") || raw.contains("internet") {
            return "No connection. Check your internet and try again."
        }
        return "Couldn’t save proof. Try again."
    }
}
