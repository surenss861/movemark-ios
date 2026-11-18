//
//  PendingEvidenceSyncTests.swift
//  movemorkTests
//
//  Kill-safety of the evidence pipeline: the real PendingEvidenceStore + PendingEvidenceSync against a
//  fake server (entries, evidence_files rows, upload tickets, stored objects) that can go offline or
//  "kill the app" at any step. A kill is faithful: the step may or may not have taken effect on the
//  server, the app never sees the answer, and nothing in memory survives — the next "launch" is a new
//  store and a new sync over the same folder, talking to the same server.
//
//  Every test ends with the server's invariants: each photo stored exactly once, none missing, no entry
//  without photos, no object no row references, no upload ticket left open.
//

import Foundation
import Testing
@testable import MoveMark

// MARK: - Fake server

@MainActor
final class FakeSyncServer: PendingEvidenceBackend {
    enum Stage: Equatable { case ensureEntry, entryCheck, deleteEntry, ticket, put, finalize, insert, abandon }

    struct Ticket { var sha: String; var state = "issued"; var keys: [String] }

    private(set) var entries: Set<UUID> = []
    private(set) var rows: [UUID: (entry: UUID, ticket: String)] = [:]
    private(set) var tickets: [String: Ticket] = [:]
    private(set) var objects: Set<String> = []
    private(set) var ticketRequests = 0
    var offline = false

    private var kill: (stage: Stage, skip: Int, applied: Bool)?
    private var hung: [CheckedContinuation<Void, Never>] = []
    var killed: Bool { !hung.isEmpty }

    /// The app dies at the `skip`+1-th `stage` call: after the server applied it (`applied`), or before.
    func killApp(at stage: Stage, skip: Int = 0, applied: Bool) {
        kill = (stage, skip, applied)
    }

    struct Offline: Error {}
    struct Rejected: Error {}

    private func step<T>(_ stage: Stage, _ apply: () throws -> T) async throws -> T {
        if let k = kill, k.stage == stage {
            if k.skip > 0 {
                kill?.skip -= 1
            } else {
                kill = nil
                if k.applied { _ = try? apply() }
                await withCheckedContinuation { hung.append($0) }   // never resumed: the app is gone
            }
        }
        if offline { throw Offline() }
        return try apply()
    }

    /// Waits until the running sync has hit its kill point.
    func waitForKill(sourceLocation: SourceLocation = #_sourceLocation) async {
        for _ in 0..<5000 where !killed { try? await Task.sleep(for: .milliseconds(1)) }
        #expect(killed, "the app never reached its kill point", sourceLocation: sourceLocation)
    }

    func seedEntry(_ id: UUID) { entries.insert(id) }

    // PendingEvidenceBackend

    func ensureEntry(id: UUID, key: PendingEvidenceKey, title: String, draft: PendingEvidenceDraft) async throws -> Bool {
        try await step(.ensureEntry) { entries.insert(id) }
        return false
    }

    func entryPhotoIds(entryId: UUID) async throws -> Set<UUID>? {
        try await step(.entryCheck) {
            entries.contains(entryId) ? Set(rows.filter { $0.value.entry == entryId }.keys) : nil
        }
    }

    func deleteEntry(id: UUID) async throws {
        try await step(.deleteEntry) {
            for (rowId, row) in rows where row.entry == id {
                objects.subtract(tickets[row.ticket]?.keys ?? [])
                rows[rowId] = nil
            }
            entries.remove(id)
        }
    }

    func upload(_ source: MMEvidenceSource, key: PendingEvidenceKey,
                onTicket: @escaping (MoveMarkUpload) async -> Void) async throws -> MoveMarkUpload {
        let id = try await step(.ticket) { () -> String in
            ticketRequests += 1
            let id = UUID().uuidString.lowercased()
            tickets[id] = Ticket(sha: source.sha256Hex, keys: ["\(id)_source", "\(id).jpg", "\(id)_thumb.jpg"])
            return id
        }
        let issued = MoveMarkUpload(ticketId: id, bucket: "inspection-media", path: "\(id).jpg", thumbnailPath: nil)
        await onTicket(issued)
        do {
            try await step(.put) {
                guard tickets[id]?.state == "issued" else { throw Rejected() }
                objects.formUnion(tickets[id]!.keys)
            }
            try await step(.finalize) {
                guard tickets[id]?.state == "issued", objects.isSuperset(of: tickets[id]!.keys) else { throw Rejected() }
                tickets[id]!.state = "finalized"
            }
        } catch {
            // What MoveMarkStorageService does: release the half-finished upload, report it if that failed too.
            let released = await abandon(issued)
            throw MoveMarkUploadFailure(underlying: error, unreleased: released == .failed ? issued : nil)
        }
        return MoveMarkUpload(ticketId: id, bucket: "inspection-media", path: "\(id).jpg", thumbnailPath: "\(id)_thumb.jpg",
                              sourcePath: "\(id)_source")
    }

    func insertPhoto(rowId: UUID, entryId: UUID, key: PendingEvidenceKey, upload: MoveMarkUpload) async throws -> String? {
        try await step(.insert) {
            guard entries.contains(entryId), rows[rowId] == nil, tickets[upload.ticketId]?.state == "finalized"
            else { throw Rejected() }
            rows[rowId] = (entryId, upload.ticketId)
            tickets[upload.ticketId]!.state = "consumed"
        }
        return "2026-11-14T21:12:03.123456+00:00"   // PostgREST's representation of created_at
    }

    func abandon(_ upload: MoveMarkUpload) async -> MoveMarkAbandonResult {
        do {
            return try await step(.abandon) { () -> MoveMarkAbandonResult in
                guard var ticket = tickets[upload.ticketId] else { throw Rejected() }
                if rows.values.contains(where: { $0.ticket == upload.ticketId }) { return .kept }
                objects.subtract(ticket.keys)
                ticket.state = "abandoned"
                tickets[upload.ticketId] = ticket
                return .deleted
            }
        } catch {
            return .failed
        }
    }

    // Invariants

    func rows(in entry: UUID) -> Int { rows.values.filter { $0.entry == entry }.count }
    func storedCount(sha: String) -> Int { rows.values.filter { tickets[$0.ticket]?.sha == sha }.count }
    var emptyEntries: [UUID] { entries.filter { id in !rows.values.contains { $0.entry == id } } }
    var orphanObjects: Set<String> {
        objects.subtracting(rows.values.flatMap { tickets[$0.ticket]?.keys ?? [] })
    }
    var openTickets: [String] { tickets.filter { ["issued", "finalized"].contains($0.value.state) }.map(\.key) }
}

// MARK: - Tests

@MainActor
struct PendingEvidenceSyncTests {
    private let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("PendingEvidenceSync-\(UUID().uuidString)", isDirectory: true)
    private let server = FakeSyncServer()
    private let key = PendingEvidenceKey(userId: UUID(), propertyId: UUID(), roomId: UUID(), stage: .moveIn)

    private func cleanup() { try? FileManager.default.removeItem(at: root) }

    /// A fresh launch: nothing from before but the files on disk.
    private func launch() -> (store: PendingEvidenceStore, sync: PendingEvidenceSync) {
        let store = PendingEvidenceStore(root: root)
        return (store, PendingEvidenceSync(store: store, backend: server))
    }

    /// Distinct photos (distinct bytes, so distinct SHA-256).
    private func photos(_ n: Int, seed: Int = 0) throws -> [PendingEvidenceInput] {
        try (0..<n).map { i in
            let data = EvidenceFixture.make(40 + seed * 37 + i, 30 + i)
            return PendingEvidenceInput(id: UUID(), source: try MMEvidenceImport.source(from: data, captureSource: .camera))
        }
    }

    /// One write per shot, as the camera does.
    private func capture(_ inputs: [PendingEvidenceInput], into store: PendingEvidenceStore, key: PendingEvidenceKey? = nil) async throws {
        for input in inputs { try await store.add([input], to: key ?? self.key, roomName: "Kitchen") }
    }

    /// Starts a sync that the server will cut off; returns once the app is "dead".
    private func syncUntilKilled(_ sync: PendingEvidenceSync, key: PendingEvidenceKey? = nil) async {
        let key = key ?? self.key
        _ = Task { _ = await sync.sync(key) }   // never finishes: abandoned like the killed process
        await server.waitForKill()
    }

    private func expectServerClean(expected: [PendingEvidenceInput], entry: UUID?, sourceLocation: SourceLocation = #_sourceLocation) {
        for photo in expected {
            #expect(server.storedCount(sha: photo.source.sha256Hex) == 1, "stored exactly once", sourceLocation: sourceLocation)
        }
        if let entry { #expect(server.rows(in: entry) == expected.count, "rows on the entry", sourceLocation: sourceLocation) }
        #expect(server.rows.count == expected.count, "no extra rows", sourceLocation: sourceLocation)
        #expect(Set(server.rows.keys) == Set(expected.map(\.id)), "row ids are the ids chosen at capture", sourceLocation: sourceLocation)
        #expect(server.emptyEntries.isEmpty, "orphan entries", sourceLocation: sourceLocation)
        #expect(server.orphanObjects.isEmpty, "unreferenced objects", sourceLocation: sourceLocation)
        #expect(server.openTickets.isEmpty, "open tickets", sourceLocation: sourceLocation)
    }

    /// Saved locally is never confirmed by the server: a photo still queued on this iPhone gets no server
    /// timestamp, stays pending, and the receipt's time comes only from photos the server confirmed. With no
    /// confirmed photo in the run, the receipt has no server time and labels its time as this device's.
    @Test func queuedPhotoGetsNoServerTimestampUntilConfirmed() async throws {
        defer { cleanup() }
        let app = launch()
        let shots = try photos(2)
        try await capture(shots, into: app.store)
        // The first photo uploads and is confirmed; the second's upload fails, so it stays on this iPhone.
        let partial = await PendingEvidenceSync(store: app.store, backend: FailingTicketServer(base: server, allowing: 1)).sync(key)
        #expect(partial.saved.count == 1 && partial.pending.count == 1 && partial.savedTotal == 1)
        #expect(partial.saved.allSatisfy { $0.serverCreatedAt != nil })            // confirmed → server time
        #expect(partial.pending.map(\.id) == [shots[1].id])                         // queued → pending only
        #expect(!partial.saved.contains { $0.id == shots[1].id })
        #expect(SavedRoomReceipt.serverSavedAt(of: partial.saved) != nil)
        #expect(await app.store.manifest(for: key)?.items.map(\.id) == [shots[1].id])  // still on this iPhone

        // Nothing confirmed at all (offline): no server time exists for the receipt.
        server.offline = true
        let offline = await app.sync.sync(key)
        #expect(offline.saved.isEmpty && offline.pending.count == 1)
        #expect(SavedRoomReceipt.serverSavedAt(of: offline.saved) == nil)
        // Photos without a server created_at (e.g. found from an earlier attempt) never yield a server time.
        #expect(SavedRoomReceipt.serverSavedAt(of: [EvidencePhoto(id: UUID(), filePath: "a.jpg")]) == nil)

        // Back online: the retry confirms it, and only then does it carry the server's time.
        server.offline = false
        let retry = await app.sync.sync(key)
        #expect(retry.isComplete && retry.saved.map(\.id) == [shots[1].id])
        #expect(retry.saved.allSatisfy { $0.serverCreatedAt != nil })
    }

    /// The receipt's Saved time reads PostgREST's created_at (microseconds, +00:00) as a full timestamp.
    @MainActor @Test func serverCreatedAtParsesAsTheReceiptTime() {
        let parsed = MMCaseDate.parse("2026-11-14T21:12:03.123456+00:00")
        #expect(parsed?.hasTime == true)
        let utc = Calendar(identifier: .gregorian)
        let parts = parsed.map { utc.dateComponents(in: TimeZone(identifier: "UTC")!, from: $0.date) }
        #expect(parts?.hour == 21 && parts?.minute == 12 && parts?.second == 3)
    }

    // MARK: The standard

    /// 10 photos captured → kill (mid-save) → reopen → offline → add more → kill again → reopen → reconnect:
    /// exactly 15 photos on the server, no duplicates, none missing, no orphan entry, nothing left behind.
    @Test func tenPhotosKillOfflineAddMoreKillReconnect() async throws {
        defer { cleanup() }
        let first = try photos(10), more = try photos(5, seed: 1)

        // 1. Ten shots, then Save. The app is killed just after the server committed photo 4's row.
        do {
            let app = launch()
            try await capture(first, into: app.store)
            server.killApp(at: .insert, skip: 3, applied: true)
            await syncUntilKilled(app.sync)
        }
        #expect(server.entries.count == 1 && server.rows.count == 4)

        // 2. Reopen: the room settles against the server — the 4 saved photos leave the phone.
        do {
            let app = launch()
            // Photos 1–3 were confirmed before the kill; photo 4's row committed unseen and is found now.
            #expect(await app.sync.reconcile(key) == .checked(alreadySaved: 1, remaining: 6))
            let restored = try #require(await app.store.restore(key))
            #expect(restored.items.map(\.item.id) == first[4...].map(\.id))
            #expect(restored.manifest.savedCount == 4)

            // 3. Offline: five more shots join the room; a save attempt sends nothing and loses nothing.
            server.offline = true
            try await capture(more, into: app.store)
            let offlineTry = await app.sync.sync(key)
            #expect(offlineTry.saved.isEmpty && offlineTry.pending.count == 11)
            guard case .unreachable = offlineTry.failure else { Issue.record("expected unreachable"); return }

            // 4. Killed again, mid-attempt, still offline.
            server.killApp(at: .entryCheck, applied: false)
            await syncUntilKilled(app.sync)
        }
        #expect(server.rows.count == 4)

        // 5. Reopen, reconnect, save.
        let app = launch()
        #expect(await app.store.summaries(userId: key.userId).first?.count == 11)
        server.offline = false
        _ = await app.sync.reconcile(key)
        let done = await app.sync.sync(key)
        #expect(done.isComplete)
        #expect(done.savedTotal == 15 && done.saved.count == 11)
        // Each photo this run inserted carries the server's created_at (the receipt's Saved time).
        #expect(done.saved.allSatisfy { $0.serverCreatedAt != nil })
        #expect(await app.store.manifest(for: key) == nil)              // nothing left on the phone
        #expect(await app.store.summaries(userId: key.userId).isEmpty)
        expectServerClean(expected: first + more, entry: done.entryId)
        #expect(server.ticketRequests == 15)                            // no photo was ever uploaded twice
    }

    // MARK: 2b — entry created, app killed before anything else

    @Test func entryIdIsOnDiskBeforeTheEntryIsCreated() async throws {
        defer { cleanup() }
        let app = launch()
        try await capture(try photos(2), into: app.store)
        server.killApp(at: .ensureEntry, applied: true)
        await syncUntilKilled(app.sync)
        let created = try #require(server.entries.first)
        #expect(await launch().store.manifest(for: key)?.entryId == created)
    }

    @Test func killedAfterEntryCreateThenSavedCompletesThatSameEntry() async throws {
        defer { cleanup() }
        let shots = try photos(2)
        do {
            let app = launch()
            try await capture(shots, into: app.store)
            server.killApp(at: .ensureEntry, applied: true)
            await syncUntilKilled(app.sync)
        }
        let entry = try #require(server.entries.first)
        let result = await launch().sync.sync(key)
        #expect(result.isComplete && result.entryId == entry)
        #expect(server.entries == [entry])                     // the create was idempotent: one entry
        expectServerClean(expected: shots, entry: entry)
    }

    @Test func killedAfterEntryCreateThenDiscardedLeavesNoEmptyEntry() async throws {
        defer { cleanup() }
        do {
            let app = launch()
            try await capture(try photos(2), into: app.store)
            server.killApp(at: .ensureEntry, applied: true)
            await syncUntilKilled(app.sync)
        }
        #expect(server.emptyEntries.count == 1)
        let app = launch()
        await app.store.clearRoom(key)                         // the renter discards the photos
        #expect(await app.store.summaries(userId: key.userId).isEmpty)
        // Offline at first: the leftover entry is remembered, not forgotten.
        server.offline = true
        #expect(await app.sync.reconcile(key) == .unknown)
        server.offline = false
        await launch().sync.reconcileAll(userId: key.userId)   // the next launch settles it
        #expect(server.entries.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: app.store.roomFolder(key).path))
    }

    @Test func failedFirstSaveRemovesTheEmptyEntryAndRetryReusesItsId() async throws {
        defer { cleanup() }
        let app = launch()
        let shots = try photos(2)
        try await capture(shots, into: app.store)
        // Every upload fails at the ticket (a storage outage).
        let failing = FailingTicketServer(base: server)
        let firstTry = await PendingEvidenceSync(store: app.store, backend: failing).sync(key)
        #expect(firstTry.saved.isEmpty && firstTry.entryRemoved && firstTry.pending.count == 2)
        #expect(server.entries.isEmpty)
        let retry = await app.sync.sync(key)
        #expect(retry.isComplete && retry.entryId == firstTry.entryId)
        expectServerClean(expected: shots, entry: retry.entryId)
    }

    // MARK: 2c — upload tickets recorded before any byte is sent

    @Test(arguments: [FakeSyncServer.Stage.put, .finalize])
    func killedMidUploadIsReleasedThenUploadedOnce(stage: FakeSyncServer.Stage) async throws {
        defer { cleanup() }
        let shots = try photos(3)
        do {
            let app = launch()
            try await capture(shots, into: app.store)
            server.killApp(at: stage, skip: 1, applied: true)   // photo 2: objects stored, app dies
            await syncUntilKilled(app.sync)
        }
        #expect(!server.orphanObjects.isEmpty)                    // left behind by the kill …
        let app = launch()
        let recorded = try #require(await app.store.manifest(for: key)?.items.first?.unresolved)
        #expect(server.openTickets.contains(recorded.ticketId))  // … and known to the phone
        let result = await app.sync.sync(key)
        #expect(result.isComplete)
        expectServerClean(expected: shots, entry: result.entryId)
        #expect(server.ticketRequests == 4)                       // photo 2 re-uploaded once, after its release
    }

    @Test func killedAfterInsertCommittedIsNeverUploadedAgain() async throws {
        defer { cleanup() }
        let shots = try photos(2)
        do {
            let app = launch()
            try await capture(shots, into: app.store)
            server.killApp(at: .insert, applied: true)
            await syncUntilKilled(app.sync)
        }
        let result = await launch().sync.sync(key)
        #expect(result.isComplete && result.alreadySaved == 1 && result.saved.count == 1)
        expectServerClean(expected: shots, entry: result.entryId)
        #expect(server.ticketRequests == 2)
    }

    @Test func discardingAPhotoMidUploadReleasesItsObjects() async throws {
        defer { cleanup() }
        let shots = try photos(2)
        do {
            let app = launch()
            try await capture(shots, into: app.store)
            server.killApp(at: .finalize, applied: false)       // photo 1: objects stored, not finalized
            await syncUntilKilled(app.sync)
        }
        #expect(!server.orphanObjects.isEmpty)
        let app = launch()
        await app.store.clearRoom(key)
        _ = await app.sync.reconcile(key)
        #expect(server.orphanObjects.isEmpty && server.openTickets.isEmpty && server.entries.isEmpty)
        #expect(await app.store.manifest(for: key) == nil)
    }

    // MARK: 1 — Add photos sheet

    @Test func addPhotosSetSurvivesAKillAndReusesRowIds() async throws {
        defer { cleanup() }
        let entry = UUID()
        server.seedEntry(entry)
        var appendKey = key
        appendKey.appendTo = entry
        let shots = try photos(3)
        do {
            let app = launch()
            try await capture(shots, into: app.store, key: appendKey)
            server.killApp(at: .insert, skip: 1, applied: false)   // killed with the sheet open, mid-add
            await syncUntilKilled(app.sync, key: appendKey)
        }
        let app = launch()
        // What the room finds on reopen to bring the sheet back for its entry.
        let set = try #require(await app.store.summaries(userId: key.userId).first)
        #expect(set.key.appendTo == entry && set.key.base == key && set.count == 2)
        #expect(await app.store.restore(appendKey)?.items.map(\.item.id) == shots[1...].map(\.id))
        let result = await app.sync.sync(appendKey)
        #expect(result.isComplete && result.entryId == entry)
        #expect(await app.store.manifest(for: appendKey) == nil)
        expectServerClean(expected: shots, entry: entry)
    }

    @Test func addPhotosForADeletedEntryBecomeTheRoomsNewEntry() async throws {
        defer { cleanup() }
        var appendKey = key
        appendKey.appendTo = UUID()   // never existed on the server (deleted meanwhile)
        let shots = try photos(2)
        let app = launch()
        try await capture(shots, into: app.store, key: appendKey)
        let attempt = await app.sync.sync(appendKey)
        guard case .entryMissing = attempt.failure else { Issue.record("expected entryMissing"); return }
        #expect(await app.store.manifest(for: appendKey) == nil)
        #expect(await app.store.restore(key)?.items.map(\.item.id) == shots.map(\.id))   // nothing lost
        let saved = await app.sync.sync(key)
        #expect(saved.isComplete)
        expectServerClean(expected: shots, entry: saved.entryId)
    }

    // MARK: 2a — a photo is shown only once it is on disk

    @Test func admitReturnsOnlyOnceThePhotoIsOnDisk() async throws {
        defer { cleanup() }
        let center = PendingEvidenceCenter(store: PendingEvidenceStore(root: root), backend: server)
        let shot = try photos(1)[0]
        try await center.admit([shot], to: key, roomName: "Kitchen")
        let item = try #require(await center.store.manifest(for: key)?.items.first)
        #expect(try Data(contentsOf: center.store.fileURL(key, item)) == shot.source.data)
    }

    @Test func admitThrowsWhenThePhotoCannotBeWritten() async throws {
        defer { cleanup() }
        // The store's folder can't be created (a file is in its way): nothing may be reported as kept.
        try FileManager.default.createDirectory(at: root.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("x".utf8).write(to: root)
        let center = PendingEvidenceCenter(store: PendingEvidenceStore(root: root), backend: server)
        await #expect(throws: (any Error).self) {
            try await center.admit([try photos(1)[0]], to: key, roomName: "Kitchen")
        }
        #expect(await center.pendingCount(userId: key.userId) == 0)
    }
}

/// The real server, except ticket requests fail (a storage outage) — all of them, or every one after the
/// first `allowing` uploads (a save that drops mid-way).
@MainActor
private final class FailingTicketServer: PendingEvidenceBackend {
    let base: FakeSyncServer
    private var allowing: Int
    init(base: FakeSyncServer, allowing: Int = 0) { self.base = base; self.allowing = allowing }
    func ensureEntry(id: UUID, key: PendingEvidenceKey, title: String, draft: PendingEvidenceDraft) async throws -> Bool {
        try await base.ensureEntry(id: id, key: key, title: title, draft: draft)
    }
    func entryPhotoIds(entryId: UUID) async throws -> Set<UUID>? { try await base.entryPhotoIds(entryId: entryId) }
    func deleteEntry(id: UUID) async throws { try await base.deleteEntry(id: id) }
    func upload(_ source: MMEvidenceSource, key: PendingEvidenceKey,
                onTicket: @escaping (MoveMarkUpload) async -> Void) async throws -> MoveMarkUpload {
        guard allowing > 0 else { throw FakeSyncServer.Offline() }
        allowing -= 1
        return try await base.upload(source, key: key, onTicket: onTicket)
    }
    func insertPhoto(rowId: UUID, entryId: UUID, key: PendingEvidenceKey, upload: MoveMarkUpload) async throws -> String? {
        try await base.insertPhoto(rowId: rowId, entryId: entryId, key: key, upload: upload)
    }
    func abandon(_ upload: MoveMarkUpload) async -> MoveMarkAbandonResult { await base.abandon(upload) }
}
