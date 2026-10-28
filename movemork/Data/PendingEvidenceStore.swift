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

    var failedCount: Int { items.filter { $0.status != .pending }.count }
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
        userFolder(key.userId)
            .appendingPathComponent(key.propertyId.uuidString.lowercased(), isDirectory: true)
            .appendingPathComponent("\(key.roomId.uuidString.lowercased())-\(key.stage.rawValue)", isDirectory: true)
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
            guard let data = try? Data(contentsOf: fileURL(key, item)),
                  let source = try? MMEvidenceImport.source(from: data, captureSource: item.captureSource),
                  source.sha256Hex == item.sha256Hex,
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
            removeFolder(key)
            return nil
        }
        return PendingEvidenceRestore(manifest: manifest, items: restored)
    }

    /// Every room of `userId` with photos still on this iPhone, newest first.
    func summaries(userId: UUID) -> [PendingEvidenceRoomSummary] {
        let userDir = userFolder(userId)
        guard let properties = try? fileManager.contentsOfDirectory(at: userDir, includingPropertiesForKeys: nil) else { return [] }
        var out: [PendingEvidenceRoomSummary] = []
        for property in properties {
            guard let rooms = try? fileManager.contentsOfDirectory(at: property, includingPropertiesForKeys: nil) else { continue }
            for room in rooms {
                let url = room.appendingPathComponent(Self.manifestName)
                guard let data = try? Data(contentsOf: url),
                      let manifest = try? Self.decoder.decode(PendingEvidenceManifest.self, from: data),
                      manifest.key.userId == userId, !manifest.items.isEmpty
                else { continue }
                out.append(PendingEvidenceRoomSummary(key: manifest.key, roomName: manifest.roomName,
                                                      count: manifest.items.count, failedCount: manifest.failedCount,
                                                      updatedAt: manifest.updatedAt))
            }
        }
        return out.sorted { $0.updatedAt > $1.updatedAt }
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

    /// Drops photos from the room: the server confirmed their rows, or the renter removed them.
    func remove(_ ids: some Sequence<UUID>, from key: PendingEvidenceKey) {
        guard var manifest = manifest(for: key) else { return }
        let drop = Set(ids)
        let removed = manifest.items.filter { drop.contains($0.id) }
        guard !removed.isEmpty else { return }
        manifest.items.removeAll { drop.contains($0.id) }
        if manifest.items.isEmpty {
            removeFolder(key)
            return
        }
        try? write(manifest)
        for item in removed { try? fileManager.removeItem(at: fileURL(key, item)) }
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

    /// These photos weren't confirmed. `unresolved` keeps uploads whose fate is unknown so they are
    /// settled before a re-upload.
    func markFailed(_ ids: some Sequence<UUID>, unresolved: [UUID: PendingEvidenceUpload] = [:], in key: PendingEvidenceKey) {
        guard var manifest = manifest(for: key) else { return }
        let set = Set(ids)
        for index in manifest.items.indices where set.contains(manifest.items[index].id) {
            manifest.items[index].status = .failed
            manifest.items[index].unresolved = unresolved[manifest.items[index].id]
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

    /// The renter discarded the room's unsaved photos.
    func clearRoom(_ key: PendingEvidenceKey) {
        removeFolder(key)
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
