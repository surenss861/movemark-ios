//
//  PendingEvidenceCenter.swift
//  movemork
//
//  MoveMark — the main-actor face of ``PendingEvidenceStore``: screens call it, it forwards to the store
//  (off the main actor) and keeps an observable per-user summary for the Proof root's
//  "N photos not uploaded yet" row.
//

import Foundation
import Observation

@Observable
final class PendingEvidenceCenter {
    static let shared = PendingEvidenceCenter(store: .shared)

    @ObservationIgnored let store: PendingEvidenceStore

    /// Rooms of `summaryUserId` with photos still only on this iPhone, newest first.
    private(set) var summaries: [PendingEvidenceRoomSummary] = []
    private(set) var summaryUserId: UUID?

    init(store: PendingEvidenceStore) {
        self.store = store
    }

    func summaries(userId: UUID?, propertyId: UUID?) -> [PendingEvidenceRoomSummary] {
        guard let userId, userId == summaryUserId else { return [] }
        return summaries.filter { propertyId == nil || $0.key.propertyId == propertyId }
    }

    func refresh(userId: UUID?) async {
        guard let userId else {
            summaries = []
            summaryUserId = nil
            return
        }
        let fresh = await store.summaries(userId: userId)
        summaries = fresh
        summaryUserId = userId
    }

    // MARK: Writes, in order

    @ObservationIgnored private var tail: Task<Void, Never>?

    /// Runs `operation` on the store after every operation queued before it (capture writes, save status,
    /// removals stay in the order the screen issued them), then refreshes the summary. Await the returned
    /// task's value when the next step depends on the write having landed.
    @discardableResult
    func perform(_ userId: UUID?, _ operation: @escaping @Sendable (PendingEvidenceStore) async -> Void) -> Task<Void, Never> {
        let previous = tail
        let store = store
        let task = Task { @MainActor in
            await previous?.value
            await operation(store)
            await self.refresh(userId: userId)
        }
        tail = task
        return task
    }

    /// Waits for every queued write.
    func flush() async {
        await tail?.value
    }

    func pendingCount(userId: UUID) async -> Int {
        await flush()
        return await store.pendingCount(userId: userId)
    }

    func clearUser(_ userId: UUID) async {
        await perform(userId) { await $0.clearUser(userId) }.value
    }
}

extension PendingEvidenceUpload {
    init(_ upload: MoveMarkUpload) {
        self.init(ticketId: upload.ticketId, bucket: upload.bucket, path: upload.path, thumbnailPath: upload.thumbnailPath,
                  sourcePath: upload.sourcePath, capturedAt: upload.capturedAt)
    }

    var moveMarkUpload: MoveMarkUpload {
        MoveMarkUpload(ticketId: ticketId, bucket: bucket, path: path, thumbnailPath: thumbnailPath,
                       sourcePath: sourcePath, capturedAt: capturedAt)
    }
}

extension PendingEvidenceDraft {
    init(title: String, notes: String, tags: Set<String>, condition: RoomRecord.ConditionRating) {
        self.init(title: title, notes: notes, tags: tags.sorted(), condition: condition.rawValue)
    }

    var conditionRating: RoomRecord.ConditionRating { RoomRecord.ConditionRating(rawValue: condition) ?? .good }
}
