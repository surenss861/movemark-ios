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
            let pickedIDs = Set(picked.map(\.id))
            let previousIDs = Set(previousPicker.map(\.id))

            // Durable first: new picks are on this iPhone before they appear in the form.
            var rejection = selection.rejectionMessage
            var keep = Array(zip(picked, selection.previews))
            do {
                try await admit(picked.filter { !previousIDs.contains($0.id) })
            } catch {
                keep.removeAll { !previousIDs.contains($0.0.id) }
                rejection = Self.keepFailedMessage
            }
            let fixed = zip(loadedSources, loadedImages).filter { !pickerItemIDs.contains($0.0.id) }
            loadedSources = fixed.map(\.0) + keep.map(\.0)
            loadedImages = fixed.map(\.1) + keep.map(\.1)
            pickerItemIDs = keep.map(\.0.id)
            if keep.count != picked.count { selectedItems = [] }   // the picker can't show what wasn't kept

            forgetPending(previousPicker.map(\.id).filter { !pickedIDs.contains($0) })
            if loadedSources.isEmpty { uploadFailed = false }
            if let rejection {
                errorMessage = rejection
                errorSource = .none   // nothing to retry: the user picks again
            }
        }
    }

    static let keepFailedMessage = "Couldn’t keep that photo on this iPhone. Free up some space and try again."

    /// A camera shot: kept only once it is written to this iPhone.
    func admitCapture(_ capture: MMCameraCapture) async -> Bool {
        let item = MMPendingEvidence(source: capture.source)
        do {
            try await admit([item])
        } catch {
            return false
        }
        loadedSources.append(item)
        loadedImages.append(capture.preview)
        return true
    }

    // MARK: Durable pending set

    /// Writes new pending photos (original bytes) and the current draft to this iPhone; returns once they
    /// are on disk.
    func admit(_ items: [MMPendingEvidence]) async throws {
        guard !items.isEmpty else { return }
        guard let key = pendingKey else { throw CocoaError(.fileWriteUnknown) }
        let inputs = items.map { PendingEvidenceInput(id: $0.id, source: $0.source) }
        try await pendingCenter.admit(inputs, to: key, roomName: roomName, draft: currentDraft)
    }

    /// Drops photos the renter removed from this iPhone's pending set.
    func forgetPending(_ ids: [UUID]) {
        guard let key = pendingKey, !ids.isEmpty else { return }
        pendingCenter.perform(key.userId) { await $0.remove(ids, from: key) }
    }

    func persistDraft(_ draft: PendingEvidenceDraft) {
        guard let key = pendingKey, !loadedSources.isEmpty, !isUploading else { return }
        pendingCenter.perform(key.userId) { await $0.updateDraft(draft, for: key) }
    }

    /// The renter chose Discard: nothing of this room's unsaved photos stays on the phone (what an earlier
    /// attempt may have left on the server is settled by the next reconcile).
    func discardPendingCaptures() {
        guard let key = pendingKey else { return }
        pendingCenter.perform(key.userId) { await $0.clearRoom(key) }
        Task { _ = await pendingCenter.reconcile(key) }
    }

    /// Brings back what an earlier visit left on this iPhone, then checks it against the server: photos an
    /// interrupted save had in fact saved leave the phone, an Add photos set reopens its sheet.
    func restorePendingCaptures() async {
        guard let key = pendingKey, restoredKey != key else { return }
        restoredKey = key
        guard loadedSources.isEmpty, pendingRetry == nil, !isUploading else { return }
        await pendingCenter.flush()
        await showStored(key)
        await pendingCenter.refresh(userId: key.userId)
        reopenPendingAppend(key)

        guard !loadedSources.isEmpty || pendingRetry != nil else {
            _ = await pendingCenter.reconcile(key)   // leftovers only (an empty entry, uploads to release)
            return
        }
        isCheckingSaved = true
        let before = pendingRetry?.savedCount ?? 0
        let outcome = await pendingCenter.reconcile(key)
        isCheckingSaved = false
        guard case .checked(let alreadySaved, _) = outcome, alreadySaved > 0, !isUploading else { return }
        propertyStore.invalidateVaultSummaries()
        await showStored(key)
        if loadedSources.isEmpty, pendingRetry == nil {
            showSyncToast(savedCount: before + alreadySaved)
        }
    }

    /// Rebuilds the form or the retry from what is on this iPhone for `key`. Photos that some attempt
    /// already linked to an entry (some saved, or an upload still to settle) return as that entry's retry;
    /// otherwise they return to the form with their draft.
    func showStored(_ key: PendingEvidenceKey) async {
        guard let restored = await pendingCenter.store.restore(key), !restored.items.isEmpty else {
            loadedSources = []
            loadedImages = []
            pendingRetry = nil
            return
        }
        let manifest = restored.manifest
        let photos = restored.items.map {
            MMPendingEvidence(source: $0.source, id: $0.item.id, unresolved: $0.item.unresolved?.moveMarkUpload)
        }
        let previews = restored.items.map(\.preview)
        let draft = manifest.draft
        let interrupted = manifest.items.contains { $0.status != .pending }

        if let entryId = manifest.entryId, manifest.savedCount > 0 || photos.contains(where: { $0.unresolved != nil }) {
            loadedSources = []
            loadedImages = []
            pendingRetry = EvidenceRetryState(
                entryId: entryId,
                pending: photos,
                previews: Dictionary(uniqueKeysWithValues: zip(photos.map(\.id), previews)),
                savedCount: manifest.savedCount,
                requestedCount: max(manifest.requestedCount, manifest.savedCount + photos.count),
                issueCount: draft.tags.count,
                outcomeHints: PropertyMutationOutcome(hydrationRefreshFailed: false)
            )
        } else {
            pendingRetry = nil
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

    /// The app stopped with the Add photos sheet open: reopen it for its entry (it restores its photos).
    private func reopenPendingAppend(_ key: PendingEvidenceKey) {
        let appendSet = pendingCenter.summaries(userId: key.userId, propertyId: key.propertyId).first {
            $0.key.base == key && $0.key.appendTo != nil
        }
        guard appendPhotosEntry == nil, let entryId = appendSet?.key.appendTo,
              let entry = existingEntries.first(where: { $0.id == entryId })
        else { return }
        appendPhotosEntry = entry
    }

    /// This room's Add photos set for `entryId`.
    func appendKey(_ entryId: UUID) -> PendingEvidenceKey? {
        guard var key = pendingKey else { return nil }
        key.appendTo = entryId
        return key
    }
}
