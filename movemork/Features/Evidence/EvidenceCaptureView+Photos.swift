//
//  EvidenceCaptureView+Photos.swift
//  movemork
//
//  Photo picker loading (picked files become source evidence via ``MMEvidencePicker``) and the room's
//  durable pending set: every photo shot or picked is written to ``PendingEvidenceStore`` at once and
//  restored when the room opens again (after leaving, a crash, or iOS stopping the app).
//

import SwiftUI
import PhotosUI

extension EvidenceCaptureView {
    /// Removes one pending photo before saving. A library photo is deselected in the picker too (which
    /// reloads the library part); a camera shot or a restored photo is dropped directly.
    func removePendingPhoto(at index: Int) {
        guard loadedSources.indices.contains(index), loadedImages.indices.contains(index) else { return }
        let id = loadedSources[index].id
        if let pickerIndex = pickerItemIDs.firstIndex(of: id),
           pickerItemIDs.count == selectedItems.count, selectedItems.indices.contains(pickerIndex) {
            selectedItems.remove(at: pickerIndex)   // the reload drops it from the store
            return
        }
        pickerItemIDs.removeAll { $0 == id }
        loadedSources.remove(at: index)
        loadedImages.remove(at: index)
        forgetPending([id])
        if loadedSources.isEmpty { uploadFailed = false }
    }

    func loadSelectedItems(_ items: [PhotosPickerItem]) {
        Task { @MainActor in
            let selection = await MMEvidencePicker.load(items)
            // The picker's selection is the library part of the pending set; camera shots and restored
            // photos stay. A photo still selected keeps its id (and its file on this iPhone).
            let previousPicker = loadedSources.filter { pickerItemIDs.contains($0.id) }
            var reusable = Dictionary(previousPicker.map { ($0.source.sha256Hex, $0) }, uniquingKeysWith: { first, _ in first })
            let picked = selection.sources.map { source in
                reusable.removeValue(forKey: source.sha256Hex) ?? MMPendingEvidence(source: source)
            }
            let fixed = zip(loadedSources, loadedImages).filter { !pickerItemIDs.contains($0.0.id) }
            let pickedIDs = Set(picked.map(\.id))
            let previousIDs = Set(previousPicker.map(\.id))

            loadedSources = fixed.map(\.0) + picked
            loadedImages = fixed.map(\.1) + selection.previews
            pickerItemIDs = picked.map(\.id)

            persistPending(picked.filter { !previousIDs.contains($0.id) })
            forgetPending(previousPicker.map(\.id).filter { !pickedIDs.contains($0) })
            if loadedSources.isEmpty { uploadFailed = false }
            if let message = selection.rejectionMessage {
                errorMessage = message
                errorSource = .none   // nothing to retry: the user picks again
            }
        }
    }

    // MARK: Durable pending set

    /// Writes new pending photos (original bytes) and the current draft to this iPhone.
    func persistPending(_ items: [MMPendingEvidence]) {
        guard let key = pendingKey, !items.isEmpty else { return }
        let inputs = items.map { PendingEvidenceInput(id: $0.id, source: $0.source) }
        let roomName = roomName
        let draft = currentDraft
        pendingCenter.perform(key.userId) { store in
            do {
                try await store.add(inputs, to: key, roomName: roomName, draft: draft)
            } catch {
                #if DEBUG
                print("MoveMark: pending evidence write failed:", error.localizedDescription)
                #endif
            }
        }
    }

    /// Drops photos from this iPhone's pending set (removed by the renter, or confirmed saved).
    func forgetPending(_ ids: [UUID]) {
        guard let key = pendingKey, !ids.isEmpty else { return }
        pendingCenter.perform(key.userId) { await $0.remove(ids, from: key) }
    }

    func persistDraft(_ draft: PendingEvidenceDraft) {
        guard let key = pendingKey, !loadedSources.isEmpty, !isUploading else { return }
        pendingCenter.perform(key.userId) { await $0.updateDraft(draft, for: key) }
    }

    /// The renter chose Discard: nothing of this room's unsaved photos stays on the phone.
    func discardPendingCaptures() {
        guard let key = pendingKey else { return }
        pendingCenter.perform(key.userId) { await $0.clearRoom(key) }
    }

    /// Brings back what an earlier visit left on this iPhone. A plain pending set returns to the form; a
    /// partial save returns as its retry, checked against the server first so a photo whose row already
    /// exists is never sent again.
    func restorePendingCaptures() async {
        guard let key = pendingKey, restoredKey != key else { return }
        restoredKey = key
        guard loadedSources.isEmpty, pendingRetry == nil, !isUploading else { return }
        await pendingCenter.flush()
        guard let restored = await pendingCenter.store.restore(key), !restored.items.isEmpty else {
            await pendingCenter.refresh(userId: key.userId)
            return
        }
        // Anything still marked uploading was cut off by the app stopping: it is failed now.
        let interrupted = restored.manifest.items.contains { $0.status != .pending }
        await pendingCenter.perform(key.userId) { await $0.settleInterrupted(key) }.value

        let photos = restored.items.map {
            MMPendingEvidence(source: $0.source, id: $0.item.id, unresolved: $0.item.unresolved?.moveMarkUpload)
        }
        let previews = restored.items.map(\.preview)
        let draft = restored.manifest.draft

        if let entryId = restored.manifest.entryId {
            pendingRetry = EvidenceRetryState(
                entryId: entryId,
                pending: photos,
                previews: Dictionary(uniqueKeysWithValues: zip(photos.map(\.id), previews)),
                savedCount: restored.manifest.savedCount,
                requestedCount: max(restored.manifest.requestedCount, restored.manifest.savedCount + photos.count),
                issueCount: draft.tags.count,
                outcomeHints: PropertyMutationOutcome(hydrationRefreshFailed: false),
                needsServerCheck: true
            )
            _ = await reconcileRestoredRetry()
        } else {
            loadedSources = photos
            loadedImages = previews
            pickerItemIDs = []
            title = draft.title
            notes = draft.notes
            selectedTags = Set(draft.tags)
            selectedCondition = draft.conditionRating
            uploadFailed = interrupted
        }
    }

    /// For a restored partial save: asks the server which photos already have rows under its entry.
    /// Confirmed photos leave the store; if the entry is gone, the photos return to the form as a new entry.
    /// - Returns: false when the retry state was replaced by the form (the caller saves instead).
    @discardableResult
    func reconcileRestoredRetry() async -> Bool {
        guard var retry = pendingRetry, retry.needsServerCheck, let key = pendingKey, !isCheckingSaved else { return true }
        isCheckingSaved = true
        defer { isCheckingSaved = false }
        let check = await propertyStore.checkEntryPhotos(
            entryId: retry.entryId, roomId: roomID, isMoveOut: moveOutMode,
            photoIds: Set(retry.pending.map(\.id)), userId: key.userId
        )
        switch check {
        case .unknown:
            return true   // offline: the retry goes ahead; stable row ids rule out duplicates
        case .present(let saved):
            retry.needsServerCheck = false
            if !saved.isEmpty {
                retry.pending.removeAll { saved.contains($0.id) }
                retry.savedCount += saved.count
                forgetPending(Array(saved))
                propertyStore.invalidateVaultSummaries()
            }
            if retry.pending.isEmpty {
                pendingRetry = nil
                showSyncToast(savedCount: retry.savedCount)
            } else {
                pendingRetry = retry
                let (savedCount, requested) = (retry.savedCount, retry.requestedCount)
                pendingCenter.perform(key.userId) {
                    await $0.setEntry(retry.entryId, savedCount: savedCount, requestedCount: requested, in: key)
                }
            }
            return true
        case .entryMissing:
            // Nothing of that save survives on the server: the photos are a new entry again.
            let previews = retry.pendingPreviews
            pendingRetry = nil
            loadedSources = retry.pending.map { MMPendingEvidence(source: $0.source, id: $0.id) }
            loadedImages = previews
            pickerItemIDs = []
            uploadFailed = true
            pendingCenter.perform(key.userId) { await $0.setEntry(nil, savedCount: 0, requestedCount: 0, in: key) }
            return false
        }
    }
}
