//
//  EvidenceCaptureView+Save.swift
//  movemork
//
//  Save, delete, edit, append photos.
//

import SwiftUI
import UIKit

extension EvidenceCaptureView {
    /// Saves the room's pending photos (the form's, or a partial save's retry) through
    /// ``PendingEvidenceSync``: the photos are already on this iPhone; they leave it only once confirmed.
    func saveEvidence() {
        // Notices raised here are save errors (`errorSource = .save`): their "Try again" runs this again.
        guard propertyStore.currentProperty != nil else {
            errorMessage = MoveMarkFlowMessage.noActiveProperty
            errorSource = .save
            return
        }

        guard let userId = sessionManager.userId, let key = pendingKey else {
            errorMessage = MoveMarkFlowMessage.signInRequired
            errorSource = .save
            return
        }
        guard !isUploading, !isCheckingSaved else { return }

        if loadedImages.isEmpty, pendingRetry == nil {
            errorMessage = "Add at least one photo before saving."
            errorSource = .none
            MMHaptics.warning()
            return
        }

        errorMessage = nil
        successMessage = nil
        isUploading = true
        let retry = pendingRetry
        uploadingCount = loadedSources.count + (retry?.pending.count ?? 0)

        // Previews follow the photos into a retry.
        var previews = retry?.previews ?? [:]
        for (item, image) in zip(loadedSources, loadedImages) { previews[item.id] = image }
        let draft = currentDraft
        let isFormSave = retry == nil
        let issueCount = isFormSave ? selectedTags.count : (retry?.issueCount ?? 0)
        let evidence = EvidenceRecord(
            title: draft.title.isEmpty ? roomName : draft.title,
            notes: draft.notes,
            issueTags: draft.tags,
            condition: draft.conditionRating,
            photoCount: loadedImages.count,
            photos: [],
            stage: moveOutMode ? .moveOut : .moveIn
        )
        let center = pendingCenter
        // Lets a short save finish if the renter leaves the app; if iOS stops it anyway, the photos are
        // still on this iPhone (marked uploading → failed at the next launch) and retryable.
        let background = EvidenceBackgroundTask(name: "Save room evidence")

        Task { @MainActor in
            defer {
                isUploading = false
                background.end()
            }
            if isFormSave {
                await center.perform(key.userId) { await $0.updateDraft(draft, for: key) }.value
            }
            let hadZeroMoveOutEvidenceBefore = moveOutMode && room?.moveOutEvidence.isEmpty == true
            let result = await center.send(key)
            let outcome = await propertyStore.applyEvidenceSync(result, key: key, evidence: evidence, userId: userId)
            let confirmed = result.saved.count + result.alreadySaved
            if confirmed > 0 { propertyStore.invalidateVaultSummaries() }

            if confirmed > 0 {
                if moveOutMode {
                    if hadZeroMoveOutEvidenceBefore {
                        propertyStore.pendingVaultFeedback = .moveOutRoomCompleted(roomName: roomName)
                    }
                } else if wasDocumentedOnLoad == false, isRoomCurrentlyDocumented {
                    propertyStore.pendingVaultFeedback = .roomCompleted(roomName: roomName)
                    wasDocumentedOnLoad = true
                }
                MoveMarkAnalytics.track(.photoAdded, properties: ["count": "\(confirmed)", "move_out": moveOutMode ? "1" : "0"])
                if isFormSave, !draft.tags.isEmpty {
                    MoveMarkAnalytics.track(.issueTagged, properties: ["count": "\(draft.tags.count)"])
                }
                if isFormSave, !draft.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    MoveMarkAnalytics.track(.noteAdded)
                }
            }

            // Nothing was saved and no entry holds anything of it: the photos stay in the form as they were.
            let nothingLinked = result.savedTotal == 0 && result.pending.allSatisfy { $0.unresolved == nil }
            if nothingLinked, !result.pending.isEmpty {
                pendingRetry = nil
                loadedSources = result.pending.map { MMPendingEvidence(source: $0.source, id: $0.id) }
                loadedImages = result.pending.compactMap { previews[$0.id] }
                pickerItemIDs = pickerItemIDs.filter { id in loadedSources.contains { $0.id == id } }
                uploadFailed = true
                let error: Error = {
                    if case .unreachable(let underlying) = result.failure { return underlying }
                    if result.insertFailures > 0 { return moveOutMode ? ProofSaveZeroLinksError.moveOutDatabase : .moveInDatabase }
                    return moveOutMode ? ProofSaveZeroLinksError.moveOutStorage : .moveInStorage
                }()
                errorMessage = MoveMarkFlowMessage.proofSaveFailed(error)
                errorSource = .save
                MMHaptics.error()
                return
            }

            // The entry exists now: the form is done with either way. Photos that didn't make it move into
            // the retry state (and out of the picker selection, so they can't be re-added twice).
            title = ""
            notes = ""
            selectedTags = []
            selectedCondition = .good
            selectedItems = []
            pickerItemIDs = []
            loadedImages = []
            loadedSources = []
            uploadFailed = false
            errorMessage = nil

            guard result.isComplete else {
                pendingRetry = EvidenceRetryState(
                    entryId: result.entryId ?? retry?.entryId ?? UUID(),
                    pending: result.pending,
                    previews: previews,
                    savedCount: result.savedTotal,
                    requestedCount: result.requestedTotal,
                    issueCount: issueCount,
                    outcomeHints: retry?.outcomeHints ?? outcome
                )
                if !result.saved.isEmpty {
                    presentReceipt(photoCount: result.savedTotal, pendingCount: result.pending.count,
                                   issueCount: issueCount, photo: result.saved.first)
                }
                MMHaptics.warning()
                return
            }
            pendingRetry = nil
            var merged = outcome
            if let retry { merged.tagInsertFailed = retry.outcomeHints.tagInsertFailed || outcome.tagInsertFailed }
            presentSaveSuccess(photoCount: result.savedTotal, issueCount: issueCount, outcome: merged)
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

    /// Sends an entry's Add photos set (already on this iPhone). Returns the photos that still need a
    /// retry (empty when all were saved) and a message for the sheet; saved ones are never sent again.
    func appendPhotos(to entryId: UUID) async -> (pending: [MMPendingEvidence], message: String?) {
        guard let userId = sessionManager.userId, let key = appendKey(entryId) else {
            MMHaptics.error()
            return ([], MoveMarkFlowMessage.signInRequired)
        }
        let result = await pendingCenter.send(key)
        let outcome = await propertyStore.applyEvidenceSync(result, key: key, evidence: nil, userId: userId)
        if result.saved.count + result.alreadySaved > 0 { propertyStore.invalidateVaultSummaries() }
        if case .entryMissing = result.failure {
            // The entry was deleted meanwhile: the photos are now this room's new entry, nothing is lost.
            MMHaptics.warning()
            restoredKey = nil
            await restorePendingCaptures()
            return ([], nil)
        }
        guard result.isComplete else {
            MMHaptics.warning()
            if case .unreachable(let error) = result.failure {
                return (result.pending, MoveMarkFlowMessage.proofSaveFailed(error))
            }
            return (result.pending, MMEvidenceSaveStatus.partial(saved: result.savedTotal, requested: result.requestedTotal))
        }
        let added = result.saved.count + result.alreadySaved
        showToast(.success, added == 1 ? "1 photo added" : "\(added) photos added", hint: outcome.hydrationRefreshFailed)
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
