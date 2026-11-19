//
//  PendingEvidenceStore.swift
//  movemork
//
//  MoveMark — evidence photos that exist only on this iPhone so far. Every photo shot or picked for a
//  room is written here at once (its original bytes, untouched) so a crash, a kill by iOS or a lost
//  upload never loses it. An item leaves only once the server has confirmed its `evidence_files` row
//  (or the renter explicitly discards it, or signs out after a warning, or deletes the account).
//
//  Layout (Application Support, file protection "complete until first user authentication", included
//  in device backups):
//
//      PendingEvidence/v1/<userId>/<propertyId>/<roomId>-<move-in|move-out>/
//          manifest.json           what is pending, its status, the entry draft
//          <itemId>.<ext>          the source file exactly as the camera / Photos supplied it
//
//  A photo file is written before the manifest names it, and the manifest drops an item before its
//  file is deleted, so the manifest never points at a missing file (orphans are swept on restore).
//
//  Photos added to an existing entry (the Add photos sheet) have their own folder,
//  `<roomId>-<phase>-add-<entryId>`, keyed to that entry.
//
//  What reaches the server is recorded before it is sent, so a kill at any point leaves something the
//  next launch can settle (see ``PendingEvidenceSync``): the entry id is chosen here and written before
//  the entry is created, and each upload's ticket is written before its bytes are sent. A room whose
//  photos are all gone but that may still have server-side leftovers (an entry that might be empty,
//  uploads to release) keeps its manifest, with no items, until ``PendingEvidenceSync/reconcile(_:)``
//  has settled them.
//

import Foundation
import UIKit

/// One room's pending set: per user, per rental, per room, per phase.
nonisolated struct PendingEvidenceKey: Hashable, Sendable, Codable {
    enum Stage: String, Hashable, Sendable, Codable {
        case moveIn = "move-in"
        case moveOut = "move-out"
    }

    let userId: UUID
    let propertyId: UUID
    let roomId: UUID
    let stage: Stage
    /// Photos for an entry that already exists (the Add photos sheet); nil for the room's new entry.
    var appendTo: UUID? = nil

    /// The room's new-entry set this key belongs to.
    var base: PendingEvidenceKey { PendingEvidenceKey(userId: userId, propertyId: propertyId, roomId: roomId, stage: stage) }
}

/// The new-entry fields typed before saving; restored with the photos.
nonisolated struct PendingEvidenceDraft: Codable, Sendable, Equatable {
    var title: String = ""
    var notes: String = ""
    var tags: [String] = []
    /// `RoomRecord.ConditionRating` raw value.
    var condition: String = "Good"
}

/// An upload whose fate was unknown when the save ended (see ``MMPendingEvidence/unresolved``); kept so it
/// is settled before the photo is uploaded again, even after a relaunch.
nonisolated struct PendingEvidenceUpload: Codable, Sendable, Equatable {
    var ticketId: String
    var bucket: String
    var path: String
    var thumbnailPath: String?
    var sourcePath: String?
    var capturedAt: Date?
}

nonisolated struct PendingEvidenceItem: Codable, Sendable, Equatable, Identifiable {
    enum Status: String, Codable, Sendable {
        /// On this iPhone, not sent yet.
        case pending
        /// A save was sending it. Found in this state at launch, the app was stopped mid-save.
        case uploading
        /// The last attempt didn't confirm it; it needs a retry.
        case failed
    }

    /// Also the `evidence_files` row id used for every attempt at this photo.
    let id: UUID
    /// The source file's name inside the room folder.
    let fileName: String
    let mimeType: String
    let fileExtension: String
    let byteCount: Int
    let sha256Hex: String
    /// The file's own (EXIF) capture time, when it declares one.
    let capturedAt: Date?
    /// When it joined the pending set on this iPhone.
    let addedAt: Date
    let captureSource: MMEvidenceCaptureSource
    var status: Status
    var unresolved: PendingEvidenceUpload?
}

nonisolated struct PendingEvidenceManifest: Codable, Sendable, Equatable {
    static let currentVersion = 1

    var version: Int = currentVersion
    var key: PendingEvidenceKey
    var roomName: String
    var draft: PendingEvidenceDraft = PendingEvidenceDraft()
    /// Set once a save created the entry: the remaining photos join it (a partial save's retry).
    var entryId: UUID?
    /// Partial-save totals for the retry status line.
    var savedCount: Int = 0
    var requestedCount: Int = 0
    var items: [PendingEvidenceItem] = []
    var updatedAt: Date = Date()
    /// Uploads of photos the renter dropped while their outcome was unknown: released (abandoned) by the
    /// next reconcile so no object stays behind unreferenced.
    var cleanup: [PendingEvidenceUpload] = []

    var failedCount: Int { items.filter { $0.status != .pending }.count }

    /// No photos left, but the server may still hold something of this room to settle: queued uploads,
    /// or an entry created (or about to be) with no photo confirmed on it.
    var needsServerCleanup: Bool {
        items.isEmpty && (!cleanup.isEmpty || (key.appendTo == nil && entryId != nil && savedCount == 0))
    }

    init(key: PendingEvidenceKey, roomName: String) {
        self.key = key
        self.roomName = roomName
    }

    private enum CodingKeys: String, CodingKey {
        case version, key, roomName, draft, entryId, savedCount, requestedCount, items, updatedAt, cleanup
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(Int.self, forKey: .version)
        key = try c.decode(PendingEvidenceKey.self, forKey: .key)
        roomName = try c.decode(String.self, forKey: .roomName)
        draft = try c.decodeIfPresent(PendingEvidenceDraft.self, forKey: .draft) ?? PendingEvidenceDraft()
        entryId = try c.decodeIfPresent(UUID.self, forKey: .entryId)
        savedCount = try c.decodeIfPresent(Int.self, forKey: .savedCount) ?? 0
        requestedCount = try c.decodeIfPresent(Int.self, forKey: .requestedCount) ?? 0
        items = try c.decodeIfPresent([PendingEvidenceItem].self, forKey: .items) ?? []
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        cleanup = try c.decodeIfPresent([PendingEvidenceUpload].self, forKey: .cleanup) ?? []
    }
}

/// What the Proof root needs to point at a room with photos still on the phone.
nonisolated struct PendingEvidenceRoomSummary: Sendable, Equatable, Identifiable {
    let key: PendingEvidenceKey
    let roomName: String
    let count: Int
    let failedCount: Int
    let updatedAt: Date
    var id: PendingEvidenceKey { key }
}

/// A photo to add: its row id for every attempt, and its source evidence.
nonisolated struct PendingEvidenceInput: Sendable {
    let id: UUID
    let source: MMEvidenceSource
}

/// A restored item, ready for the form.
nonisolated struct PendingEvidenceRestoredItem: Sendable {
    let item: PendingEvidenceItem
    let source: MMEvidenceSource
    let preview: UIImage
}

nonisolated struct PendingEvidenceRestore: Sendable {
    let manifest: PendingEvidenceManifest
    let items: [PendingEvidenceRestoredItem]
}

/// Serialises every read-modify-write of the manifests and keeps file I/O off the main actor.
actor PendingEvidenceStore {
    static let shared = PendingEvidenceStore(root: PendingEvidenceStore.defaultRoot)

    static var defaultRoot: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("PendingEvidence/v1", isDirectory: true)
    }

    nonisolated let root: URL
    private let fileManager = FileManager.default
    private static let manifestName = "manifest.json"

    init(root: URL) {
        self.root = root
    }

    // MARK: Paths

    nonisolated func userFolder(_ userId: UUID) -> URL {
        root.appendingPathComponent(userId.uuidString.lowercased(), isDirectory: true)
    }

    nonisolated func roomFolder(_ key: PendingEvidenceKey) -> URL {
        var name = "\(key.roomId.uuidString.lowercased())-\(key.stage.rawValue)"
        if let entry = key.appendTo { name += "-add-\(entry.uuidString.lowercased())" }
        return userFolder(key.userId)
            .appendingPathComponent(key.propertyId.uuidString.lowercased(), isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
    }

    nonisolated func fileURL(_ key: PendingEvidenceKey, _ item: PendingEvidenceItem) -> URL {
        roomFolder(key).appendingPathComponent(item.fileName, isDirectory: false)
    }

    private func manifestURL(_ key: PendingEvidenceKey) -> URL {
        roomFolder(key).appendingPathComponent(Self.manifestName, isDirectory: false)
    }

    // MARK: Reads

    func manifest(for key: PendingEvidenceKey) -> PendingEvidenceManifest? {
        guard let data = try? Data(contentsOf: manifestURL(key)),
              let manifest = try? Self.decoder.decode(PendingEvidenceManifest.self, from: data),
              manifest.version <= PendingEvidenceManifest.currentVersion
        else { return nil }
        return manifest
    }

    /// The room's pending photos with their source bytes and previews. Items whose file is missing or no
    /// longer matches its recorded hash are dropped from the manifest (never shown as if intact); files
    /// the manifest doesn't name are swept.
    func restore(_ key: PendingEvidenceKey) -> PendingEvidenceRestore? {
        guard var manifest = manifest(for: key) else { return nil }
        var restored: [PendingEvidenceRestoredItem] = []
        var kept: [PendingEvidenceItem] = []
        for item in manifest.items {
            guard let source = source(for: item, in: key),
                  let preview = MMEvidenceImport.preview(from: source)
            else { continue }
            kept.append(item)
            restored.append(PendingEvidenceRestoredItem(item: item, source: source, preview: preview))
        }
        if kept.count != manifest.items.count {
            manifest.items = kept
            try? write(manifest)
        }
        sweepOrphans(key, manifest: manifest)
        guard !manifest.items.isEmpty else {
            if !manifest.needsServerCleanup { removeFolder(key) }
            return nil
        }
        return PendingEvidenceRestore(manifest: manifest, items: restored)
    }

    /// The item's source evidence from its file, or nil when the file is missing or no longer matches its hash.
    func source(for item: PendingEvidenceItem, in key: PendingEvidenceKey) -> MMEvidenceSource? {
        guard let data = try? Data(contentsOf: fileURL(key, item)),
              let source = try? MMEvidenceImport.source(from: data, captureSource: item.captureSource),
              source.sha256Hex == item.sha256Hex
        else { return nil }
        return source
    }

    /// Every manifest of `userId` on this iPhone, including rooms waiting only for server cleanup.
    func manifests(userId: UUID) -> [PendingEvidenceManifest] {
        let userDir = userFolder(userId)
        guard let properties = try? fileManager.contentsOfDirectory(at: userDir, includingPropertiesForKeys: nil) else { return [] }
        var out: [PendingEvidenceManifest] = []
        for property in properties {
            guard let rooms = try? fileManager.contentsOfDirectory(at: property, includingPropertiesForKeys: nil) else { continue }
            for room in rooms {
                let url = room.appendingPathComponent(Self.manifestName)
                guard let data = try? Data(contentsOf: url),
                      let manifest = try? Self.decoder.decode(PendingEvidenceManifest.self, from: data),
                      manifest.key.userId == userId
                else { continue }
                out.append(manifest)
            }
        }
        return out
    }

    /// Every room of `userId` with photos still on this iPhone, newest first.
    func summaries(userId: UUID) -> [PendingEvidenceRoomSummary] {
        manifests(userId: userId)
            .filter { !$0.items.isEmpty }
            .map { PendingEvidenceRoomSummary(key: $0.key, roomName: $0.roomName, count: $0.items.count,
                                              failedCount: $0.failedCount, updatedAt: $0.updatedAt) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func pendingCount(userId: UUID) -> Int {
        summaries(userId: userId).reduce(0) { $0 + $1.count }
    }

    // MARK: Writes

    /// Writes each photo's original bytes, then records it. Photos already in the room (same id) are skipped.
    func add(_ inputs: [PendingEvidenceInput], to key: PendingEvidenceKey, roomName: String,
             draft: PendingEvidenceDraft? = nil, now: Date = Date()) throws {
        guard !inputs.isEmpty else { return }
        var manifest = manifest(for: key) ?? PendingEvidenceManifest(key: key, roomName: roomName)
        manifest.roomName = roomName
        if let draft { manifest.draft = draft }
        try ensureFolder(key)
        let known = Set(manifest.items.map(\.id))
        for input in inputs where !known.contains(input.id) {
            let source = input.source
            let item = PendingEvidenceItem(
                id: input.id,
                fileName: "\(input.id.uuidString.lowercased()).\(source.fileExtension)",
                mimeType: source.mimeType,
                fileExtension: source.fileExtension,
                byteCount: source.data.count,
                sha256Hex: source.sha256Hex,
                capturedAt: source.capturedAt,
                addedAt: now,
                captureSource: source.captureSource,
                status: .pending
            )
            try source.data.write(to: fileURL(key, item), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            manifest.items.append(item)
        }
        try write(manifest)
    }

    /// The renter removed these photos before they were saved. An upload of theirs whose outcome is
    /// unknown is queued for release (it may hold objects, or even a row, on the server).
    func remove(_ ids: some Sequence<UUID>, from key: PendingEvidenceKey) {
        drop(Set(ids), from: key, confirmed: false)
    }

    /// The server confirmed these photos' rows: they leave this iPhone and count as saved.
    func confirm(_ ids: some Sequence<UUID>, in key: PendingEvidenceKey) {
        drop(Set(ids), from: key, confirmed: true)
    }

    private func drop(_ ids: Set<UUID>, from key: PendingEvidenceKey, confirmed: Bool) {
        guard var manifest = manifest(for: key) else { return }
        let removed = manifest.items.filter { ids.contains($0.id) }
        guard !removed.isEmpty else { return }
        manifest.items.removeAll { ids.contains($0.id) }
        if confirmed {
            manifest.savedCount += removed.count
        } else {
            manifest.cleanup += removed.compactMap(\.unresolved)
        }
        if manifest.items.isEmpty, !manifest.needsServerCleanup {
            removeFolder(key)
            return
        }
        try? write(manifest)
        for item in removed { try? fileManager.removeItem(at: fileURL(key, item)) }
    }

    /// Records the upload a photo is in the middle of (written before its bytes are sent, and again with
    /// the finalized paths), or clears it once settled.
    func setUnresolved(_ upload: PendingEvidenceUpload?, for id: UUID, in key: PendingEvidenceKey) {
        guard var manifest = manifest(for: key),
              let index = manifest.items.firstIndex(where: { $0.id == id }),
              manifest.items[index].unresolved != upload
        else { return }
        manifest.items[index].unresolved = upload
        try? write(manifest)
    }

    /// The entry this room's photos go to: the Add photos target, the one an earlier attempt chose, or a
    /// new id — written to disk here, before the entry is created, so a kill right after the create
    /// still leaves its id behind.
    func beginEntry(_ key: PendingEvidenceKey) throws -> UUID? {
        guard var manifest = manifest(for: key) else { return nil }
        if let id = manifest.entryId { return id }
        let id = key.appendTo ?? UUID()
        manifest.entryId = id
        try write(manifest)
        return id
    }

    /// A queued upload was released (or turned out to be referenced by a row).
    func dropCleanup(_ upload: PendingEvidenceUpload, in key: PendingEvidenceKey) {
        guard var manifest = manifest(for: key), manifest.cleanup.contains(upload) else { return }
        manifest.cleanup.removeAll { $0 == upload }
        finishOrWrite(manifest)
    }

    /// The room's entry was checked (deleted when it was empty, or found to hold photos): nothing about it
    /// is left to settle.
    func entrySettled(_ key: PendingEvidenceKey, savedOnServer: Int) {
        guard var manifest = manifest(for: key) else { return }
        manifest.savedCount = max(manifest.savedCount, savedOnServer)
        if manifest.items.isEmpty, manifest.savedCount == 0 { manifest.entryId = nil }
        finishOrWrite(manifest)
    }

    /// The entry an Add photos set was meant for is gone: its photos become the room's new-entry set, so
    /// nothing is lost. Files are moved, never re-encoded.
    func rehomeToNewEntry(_ key: PendingEvidenceKey) throws {
        guard key.appendTo != nil, let manifest = manifest(for: key) else { return }
        let target = key.base
        var destination = self.manifest(for: target) ?? PendingEvidenceManifest(key: target, roomName: manifest.roomName)
        try ensureFolder(target)
        let known = Set(destination.items.map(\.id))
        for var item in manifest.items where !known.contains(item.id) {
            let from = fileURL(key, item), to = fileURL(target, item)
            if !fileManager.fileExists(atPath: to.path) { try fileManager.moveItem(at: from, to: to) }
            item.status = .failed
            item.unresolved = nil   // released below, with the rest of this set's uploads
            destination.items.append(item)
        }
        destination.cleanup += manifest.cleanup + manifest.items.compactMap(\.unresolved)
        try write(destination)
        removeFolder(key)
    }

    func updateDraft(_ draft: PendingEvidenceDraft, for key: PendingEvidenceKey) {
        guard var manifest = manifest(for: key), manifest.draft != draft else { return }
        manifest.draft = draft
        try? write(manifest)
    }

    /// A save is starting for these photos.
    func markUploading(_ ids: some Sequence<UUID>, in key: PendingEvidenceKey, draft: PendingEvidenceDraft? = nil) {
        guard var manifest = manifest(for: key) else { return }
        let set = Set(ids)
        for index in manifest.items.indices where set.contains(manifest.items[index].id) {
            manifest.items[index].status = .uploading
        }
        manifest.requestedCount = max(manifest.requestedCount, manifest.savedCount + manifest.items.count)
        if let draft { manifest.draft = draft }
        try? write(manifest)
    }

    /// The save created its entry: from here on, a retry appends to it (even after a relaunch).
    func setEntry(_ entryId: UUID?, savedCount: Int? = nil, requestedCount: Int? = nil, in key: PendingEvidenceKey) {
        guard var manifest = manifest(for: key) else { return }
        manifest.entryId = entryId
        if let savedCount { manifest.savedCount = savedCount }
        if let requestedCount { manifest.requestedCount = requestedCount }
        try? write(manifest)
    }

    /// These photos weren't confirmed. `unresolved` records uploads whose fate is unknown so they are
    /// settled before a re-upload; an upload already recorded for a photo is kept (cleared only by
    /// ``setUnresolved(_:for:in:)`` once settled).
    func markFailed(_ ids: some Sequence<UUID>, unresolved: [UUID: PendingEvidenceUpload] = [:], in key: PendingEvidenceKey) {
        guard var manifest = manifest(for: key) else { return }
        let set = Set(ids)
        for index in manifest.items.indices where set.contains(manifest.items[index].id) {
            manifest.items[index].status = .failed
            if let upload = unresolved[manifest.items[index].id] { manifest.items[index].unresolved = upload }
        }
        try? write(manifest)
    }

    /// Photos the app was sending when it stopped (found `uploading` at launch) become `failed`.
    func settleInterrupted(_ key: PendingEvidenceKey) {
        guard var manifest = manifest(for: key), manifest.items.contains(where: { $0.status == .uploading }) else { return }
        for index in manifest.items.indices where manifest.items[index].status == .uploading {
            manifest.items[index].status = .failed
        }
        try? write(manifest)
    }

    /// The renter discarded the room's unsaved photos. What may remain on the server (an empty entry,
    /// unknown uploads) stays recorded until reconciled.
    func clearRoom(_ key: PendingEvidenceKey) {
        guard let manifest = manifest(for: key) else { return removeFolder(key) }
        drop(Set(manifest.items.map(\.id)), from: key, confirmed: false)
    }

    /// Sign-out (after its warning) and account deletion: everything this user had pending on this iPhone.
    func clearUser(_ userId: UUID) {
        try? fileManager.removeItem(at: userFolder(userId))
    }

    // MARK: Helpers

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private func finishOrWrite(_ manifest: PendingEvidenceManifest) {
        if manifest.items.isEmpty, !manifest.needsServerCleanup {
            removeFolder(manifest.key)
        } else {
            try? write(manifest)
        }
    }

    private func write(_ manifest: PendingEvidenceManifest) throws {
        var manifest = manifest
        manifest.updatedAt = Date()
        try ensureFolder(manifest.key)
        let data = try Self.encoder.encode(manifest)
        try data.write(to: manifestURL(manifest.key), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    private func ensureFolder(_ key: PendingEvidenceKey) throws {
        let protection: [FileAttributeKey: Any] = [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        if !fileManager.fileExists(atPath: root.path) {
            try fileManager.createDirectory(at: root, withIntermediateDirectories: true, attributes: protection)
        }
        try fileManager.createDirectory(at: roomFolder(key), withIntermediateDirectories: true, attributes: protection)
    }

    private func removeFolder(_ key: PendingEvidenceKey) {
        let folder = roomFolder(key)
        try? fileManager.removeItem(at: folder)
        // Leave no empty property / user folders behind.
        let property = folder.deletingLastPathComponent()
        if (try? fileManager.contentsOfDirectory(atPath: property.path))?.isEmpty == true {
            try? fileManager.removeItem(at: property)
            let user = property.deletingLastPathComponent()
            if (try? fileManager.contentsOfDirectory(atPath: user.path))?.isEmpty == true {
                try? fileManager.removeItem(at: user)
            }
        }
    }

    private func sweepOrphans(_ key: PendingEvidenceKey, manifest: PendingEvidenceManifest) {
        let named = Set(manifest.items.map(\.fileName) + [Self.manifestName])
        guard let files = try? fileManager.contentsOfDirectory(atPath: roomFolder(key).path) else { return }
        for file in files where !named.contains(file) && !file.hasPrefix(".") {
            try? fileManager.removeItem(at: roomFolder(key).appendingPathComponent(file))
        }
    }
}
