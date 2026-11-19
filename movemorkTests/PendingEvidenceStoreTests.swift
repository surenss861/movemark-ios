//
//  PendingEvidenceStoreTests.swift
//  movemorkTests
//
//  The durability contract for photos not uploaded yet: written at once with their original bytes,
//  restored by a new store instance (a relaunch), removed only on confirmation (or discard / sign-out),
//  failed status and unresolved uploads kept across a relaunch, and one user never sees another's.
//

import CryptoKit
import Foundation
import Testing
import UIKit
@testable import MoveMark

@MainActor
struct PendingEvidenceStoreTests {
    private let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("PendingEvidenceTests-\(UUID().uuidString)", isDirectory: true)
    private let userA = UUID()
    private let userB = UUID()
    private let property = UUID()
    private let room = UUID()

    private func key(_ user: UUID, stage: PendingEvidenceKey.Stage = .moveIn, room: UUID? = nil) -> PendingEvidenceKey {
        PendingEvidenceKey(userId: user, propertyId: property, roomId: room ?? self.room, stage: stage)
    }

    private func input(_ w: Int = 64, _ h: Int = 48, date: String = "2026:10:01 09:15:00") throws -> PendingEvidenceInput {
        let data = EvidenceFixture.make(w, h, date: date)
        return PendingEvidenceInput(id: UUID(), source: try MMEvidenceImport.source(from: data, captureSource: .camera))
    }

    private func cleanup() { try? FileManager.default.removeItem(at: root) }

    @Test func writesOriginalBytesAndManifestImmediately() async throws {
        defer { cleanup() }
        let store = PendingEvidenceStore(root: root)
        let photo = try input()
        let draft = PendingEvidenceDraft(title: "North wall", notes: "Scuff by the door", tags: ["Scratch"], condition: "Fair")
        try await store.add([photo], to: key(userA), roomName: "Kitchen", draft: draft)

        let manifest = try #require(await store.manifest(for: key(userA)))
        #expect(manifest.items.count == 1)
        #expect(manifest.roomName == "Kitchen")
        #expect(manifest.draft == draft)
        let item = try #require(manifest.items.first)
        #expect(item.id == photo.id)
        #expect(item.status == .pending)
        #expect(item.mimeType == "image/jpeg")
        #expect(item.captureSource == .camera)
        #expect(item.sha256Hex == photo.source.sha256Hex)

        // Exactly the bytes the camera / picker supplied: never re-encoded.
        let onDisk = try Data(contentsOf: store.fileURL(key(userA), item))
        #expect(onDisk == photo.source.data)

        // Per user / property / room-phase folder, under the store root.
        let folder = store.roomFolder(key(userA)).path
        #expect(folder.hasPrefix(root.path))
        #expect(folder.contains(userA.uuidString.lowercased()))
        #expect(folder.hasSuffix("\(room.uuidString.lowercased())-move-in"))
    }

    @Test func filesUseCompleteUntilFirstUserAuthenticationProtection() async throws {
        defer { cleanup() }
        let store = PendingEvidenceStore(root: root)
        let photo = try input()
        try await store.add([photo], to: key(userA), roomName: "Kitchen")
        let item = try #require(await store.manifest(for: key(userA))?.items.first)
        let attrs = try FileManager.default.attributesOfItem(atPath: store.fileURL(key(userA), item).path)
        // The simulator doesn't enforce data protection, but the attribute is what a device enforces.
        if let protection = attrs[.protectionKey] as? FileProtectionType {
            #expect(protection == .completeUntilFirstUserAuthentication)
        }
    }

    @Test func eighteenPhotosSurviveARelaunch() async throws {
        defer { cleanup() }
        let photos = try (0..<18).map { _ in try input() }
        do {
            let store = PendingEvidenceStore(root: root)
            for photo in photos {   // one write per shot, as the camera does
                try await store.add([photo], to: key(userA), roomName: "Living Room",
                                    draft: PendingEvidenceDraft(title: "Walls", notes: "", tags: [], condition: "Good"))
            }
        }
        // A brand-new store over the same folder: what the app sees after iOS killed it.
        let relaunched = PendingEvidenceStore(root: root)
        let restored = try #require(await relaunched.restore(key(userA)))
        #expect(restored.items.count == 18)
        #expect(restored.items.map(\.item.id) == photos.map(\.id))                       // capture order kept
        #expect(restored.items.map(\.source.data) == photos.map(\.source.data))          // original bytes
        #expect(restored.items.allSatisfy { $0.preview.size.width > 0 })
        #expect(restored.manifest.draft.title == "Walls")
        #expect(await relaunched.summaries(userId: userA).first?.count == 18)
    }

    @Test func removesOnlyConfirmedPhotos() async throws {
        defer { cleanup() }
        let store = PendingEvidenceStore(root: root)
        let photos = try (0..<3).map { _ in try input() }
        try await store.add(photos, to: key(userA), roomName: "Bedroom")
        await store.markUploading(photos.map(\.id), in: key(userA))

        // The server confirmed rows for the first two only.
        await store.setEntry(UUID(), in: key(userA))
        await store.confirm([photos[0].id, photos[1].id], in: key(userA))
        await store.markFailed([photos[2].id], in: key(userA))

        let manifest = try #require(await store.manifest(for: key(userA)))
        #expect(manifest.items.map(\.id) == [photos[2].id])
        #expect(manifest.items.first?.status == .failed)
        #expect(manifest.savedCount == 2 && manifest.requestedCount == 3)
        let remaining = try FileManager.default.contentsOfDirectory(atPath: store.roomFolder(key(userA)).path)
        #expect(Set(remaining) == ["manifest.json", manifest.items[0].fileName])

        // The last one confirmed: nothing of the room is left on the phone.
        await store.confirm([photos[2].id], in: key(userA))
        #expect(await store.manifest(for: key(userA)) == nil)
        #expect(!FileManager.default.fileExists(atPath: store.roomFolder(key(userA)).path))
        #expect(await store.summaries(userId: userA).isEmpty)
    }

    @Test func failedStatusEntryAndUnresolvedUploadSurviveRelaunch() async throws {
        defer { cleanup() }
        let entry = UUID()
        let photo = try input()
        let upload = PendingEvidenceUpload(ticketId: "t-1", bucket: "inspection-media", path: "p/1.jpg",
                                           thumbnailPath: "p/1_t.jpg", sourcePath: "p/1.heic", capturedAt: nil)
        do {
            let store = PendingEvidenceStore(root: root)
            try await store.add([photo], to: key(userA), roomName: "Bath")
            await store.markUploading([photo.id], in: key(userA))
            await store.setEntry(entry, savedCount: 1, requestedCount: 2, in: key(userA))
            await store.markFailed([photo.id], unresolved: [photo.id: upload], in: key(userA))
        }
        let relaunched = PendingEvidenceStore(root: root)
        let restored = try #require(await relaunched.restore(key(userA)))
        #expect(restored.manifest.entryId == entry)
        #expect(restored.manifest.savedCount == 1)
        #expect(restored.items.first?.item.status == .failed)
        #expect(restored.items.first?.item.unresolved == upload)
        #expect(restored.items.first?.item.unresolved?.moveMarkUpload.ticketId == "t-1")
        #expect(await relaunched.summaries(userId: userA).first?.failedCount == 1)
    }

    @Test func uploadInterruptedByAKillBecomesFailed() async throws {
        defer { cleanup() }
        let photo = try input()
        do {
            let store = PendingEvidenceStore(root: root)
            try await store.add([photo], to: key(userA), roomName: "Hall")
            await store.markUploading([photo.id], in: key(userA))
            // …the app is killed mid-save: no result is ever recorded.
        }
        let relaunched = PendingEvidenceStore(root: root)
        #expect(await relaunched.manifest(for: key(userA))?.items.first?.status == .uploading)
        await relaunched.settleInterrupted(key(userA))
        #expect(await relaunched.manifest(for: key(userA))?.items.first?.status == .failed)
        #expect(await relaunched.restore(key(userA))?.items.count == 1)
    }

    @Test func usersAreIsolated() async throws {
        defer { cleanup() }
        let store = PendingEvidenceStore(root: root)
        try await store.add([try input()], to: key(userA), roomName: "Kitchen")
        try await store.add([try input(), try input()], to: key(userB), roomName: "Kitchen")

        #expect(await store.pendingCount(userId: userA) == 1)
        #expect(await store.pendingCount(userId: userB) == 2)
        #expect(await store.restore(key(userA))?.items.count == 1)

        // Clearing one user (sign-out after the warning, or account deletion) leaves the other untouched.
        await store.clearUser(userA)
        #expect(await store.pendingCount(userId: userA) == 0)
        #expect(await store.restore(key(userA)) == nil)
        #expect(await store.pendingCount(userId: userB) == 2)
    }

    @Test func phasesAndRoomsAreSeparate() async throws {
        defer { cleanup() }
        let store = PendingEvidenceStore(root: root)
        let otherRoom = UUID()
        try await store.add([try input()], to: key(userA, stage: .moveIn), roomName: "Kitchen")
        try await store.add([try input()], to: key(userA, stage: .moveOut), roomName: "Kitchen")
        try await store.add([try input()], to: key(userA, room: otherRoom), roomName: "Den")
        #expect(await store.summaries(userId: userA).count == 3)
        await store.clearRoom(key(userA, stage: .moveOut))
        let left = await store.summaries(userId: userA)
        #expect(left.count == 2)
        #expect(!left.contains { $0.key.stage == .moveOut })
    }

    @Test func addingTheSamePhotoTwiceKeepsOneCopy() async throws {
        defer { cleanup() }
        let store = PendingEvidenceStore(root: root)
        let photo = try input()
        try await store.add([photo], to: key(userA), roomName: "Kitchen")
        try await store.add([photo], to: key(userA), roomName: "Kitchen")
        #expect(await store.manifest(for: key(userA))?.items.count == 1)
    }

    @Test func aDamagedFileIsNeverRestoredAsIntact() async throws {
        defer { cleanup() }
        let store = PendingEvidenceStore(root: root)
        let good = try input(), damaged = try input(80, 60)
        try await store.add([good, damaged], to: key(userA), roomName: "Kitchen")
        let item = try #require(await store.manifest(for: key(userA))?.items.last)
        try Data("not a photo".utf8).write(to: store.fileURL(key(userA), item))

        let restored = try #require(await store.restore(key(userA)))
        #expect(restored.items.map(\.item.id) == [good.id])
        #expect(await store.manifest(for: key(userA))?.items.map(\.id) == [good.id])
    }

    @Test func draftUpdatesPersist() async throws {
        defer { cleanup() }
        let store = PendingEvidenceStore(root: root)
        try await store.add([try input()], to: key(userA), roomName: "Kitchen")
        let draft = PendingEvidenceDraft(title: "Oven", notes: "Burn mark", tags: ["Stain"], condition: "Poor")
        await store.updateDraft(draft, for: key(userA))
        let relaunched = PendingEvidenceStore(root: root)
        let restored = try #require(await relaunched.manifest(for: key(userA)))
        #expect(restored.draft == draft)
        #expect(restored.draft.conditionRating == .poor)
    }

    @Test func centerSummaryIsPerUser() async throws {
        defer { cleanup() }
        let center = PendingEvidenceCenter(store: PendingEvidenceStore(root: root))
        let photo = try input()
        let roomKey = key(userA)
        await center.perform(userA) { try? await $0.add([photo], to: roomKey, roomName: "Kitchen") }.value
        #expect(center.summaries(userId: userA, propertyId: property).first?.count == 1)
        #expect(center.summaries(userId: userB, propertyId: property).isEmpty)
        #expect(await center.pendingCount(userId: userA) == 1)
        await center.clearUser(userA)
        #expect(center.summaries(userId: userA, propertyId: nil).isEmpty)
    }
}
