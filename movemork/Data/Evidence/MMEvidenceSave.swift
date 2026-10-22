//
//  MMEvidenceSave.swift
//  movemork
//
//  MoveMark — saving a batch of evidence photos, one at a time, with an honest result. A photo
//  counts as saved only once its row is committed; anything else is returned as pending so the
//  caller retries exactly those photos and never re-uploads one that already made it.
//
//  Duplicates are ruled out in two ways: each pending photo keeps one row id for every attempt
//  (a second insert of it can only conflict), and an upload whose fate is unknown — its row insert
//  and its abandon both failed — is settled by abandoning it again before anything is re-uploaded
//  (`kept` means the row exists: the photo is saved).
//

import Foundation

/// A photo that isn't confirmed saved yet.
struct MMPendingEvidence: Sendable, Identifiable {
    /// The `evidence_files` row id used for every attempt at this photo.
    let id: UUID
    let source: MMEvidenceSource
    /// An earlier upload of this photo that is still outstanding (its abandon didn't get through).
    /// Settled before the photo is uploaded again.
    var unresolved: MoveMarkUpload?

    init(source: MMEvidenceSource, id: UUID = UUID(), unresolved: MoveMarkUpload? = nil) {
        self.id = id
        self.source = source
        self.unresolved = unresolved
    }
}

struct MMEvidenceSaveResult: Sendable {
    /// Photos whose rows are committed, in request order.
    var saved: [EvidencePhoto] = []
    /// Photos to retry, in request order. Retry these only.
    var pending: [MMPendingEvidence] = []
    /// Of the failures, how many got as far as a verified upload but not a row (database/Data API side).
    var insertFailures = 0

    var requestedCount: Int { saved.count + pending.count }
    var isComplete: Bool { pending.isEmpty }
}

/// Runs the upload → row insert sequence per photo. `upload` covers ticket, source/derivative/thumbnail
/// PUTs and finalize (the storage service releases its own half-finished tickets); `insert` writes the
/// row with the given id; `abandon` releases an upload whose row wasn't confirmed.
/// The steps are `@concurrent`: an explicit calling convention, so steps written in targets with other
/// default isolation (tests) are called correctly.
struct MMEvidenceSaver: Sendable {
    var upload: @concurrent @Sendable (MMEvidenceSource) async throws -> MoveMarkUpload
    var insert: @concurrent @Sendable (_ rowId: UUID, _ upload: MoveMarkUpload) async throws -> Void
    var abandon: @concurrent @Sendable (MoveMarkUpload) async -> MoveMarkAbandonResult

    func save(_ items: [MMPendingEvidence]) async -> MMEvidenceSaveResult {
        var result = MMEvidenceSaveResult()
        for var item in items {
            if let earlier = item.unresolved {
                switch await abandon(earlier) {
                case .kept:  // its row committed last time; only the response was lost
                    result.saved.append(Self.photo(item.id, earlier))
                    continue
                case .deleted:
                    item.unresolved = nil
                case .failed:  // still unknown: uploading again could duplicate it
                    result.pending.append(item)
                    continue
                }
            }

            let upload: MoveMarkUpload
            do {
                upload = try await self.upload(item.source)
            } catch {
                item.unresolved = (error as? MoveMarkUploadFailure)?.unreleased
                result.pending.append(item)
                continue
            }

            do {
                try await insert(item.id, upload)
                result.saved.append(Self.photo(item.id, upload))
            } catch {
                result.insertFailures += 1
                switch await abandon(upload) {
                case .kept:
                    result.saved.append(Self.photo(item.id, upload))
                case .deleted:
                    result.pending.append(item)
                case .failed:
                    item.unresolved = upload
                    result.pending.append(item)
                }
            }
        }
        return result
    }

    private static func photo(_ id: UUID, _ upload: MoveMarkUpload) -> EvidencePhoto {
        EvidencePhoto(id: id, filePath: upload.path, thumbnailPath: upload.thumbnailPath)
    }
}

/// User-facing summary of a save. Full success is only ever reported when every requested photo is saved.
enum MMEvidenceSaveStatus {
    /// "1 of 2 photos saved. 1 photo needs retry." — `saved` and `requested` are totals for the entry's batch.
    static func partial(saved: Int, requested: Int) -> String {
        let failed = requested - saved
        let head = saved == 0
            ? "No photos were saved."
            : "\(saved) of \(requested) photos saved."
        return "\(head) \(failed) \(failed == 1 ? "photo needs" : "photos need") retry."
    }
}
