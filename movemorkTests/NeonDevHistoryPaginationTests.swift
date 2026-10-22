//
//  NeonDevHistoryPaginationTests.swift
//  movemorkTests
//
//  Snapshot v2 + on-demand history (migration 0990) through the app's own stack against Neon `dev`: a room
//  with more entries than the snapshot loads, an entry with more photos than it loads, maintenance photo
//  counts and the vault summary. Proves the app shows true totals before anything older is loaded, and that
//  loading older entries / all photos brings in exactly the rest — nothing hidden, nothing duplicated.
//
//  Opt-in, like the lifecycle gate (creates and deletes the dev QA account; needs the dev API for deletion):
//    TEST_RUNNER_MM_E2E_DIR=<dir> xcodebuild test -only-testing:movemorkTests/NeonDevHistoryPaginationTests …
//

import Foundation
import PostgREST
import Testing
@testable import MoveMark

private let env = ProcessInfo.processInfo.environment

@Suite(.serialized, .enabled(if: env["MM_E2E_DIR"] != nil, "set TEST_RUNNER_MM_E2E_DIR to run against Neon dev"))
@MainActor
struct NeonDevHistoryPaginationTests {
    private let email = "qa-neon-a@movemark.test"
    private let properties = PropertyRepository()
    private let inspections = InspectionRepository()

    @Test func largeRoomLoadsNewestFirstThenEverythingOnDemand() async throws {
        let dataHost = try #require(MoveMarkBackendConfig.dataAPIURL?.host)
        #expect(dataHost.hasPrefix("ep-quiet-salad-b55aeba0.") && !dataHost.contains("ep-steep-wind"))

        let session = SessionManager()
        await NeonAuthClient.shared.endSessionLocally(notify: false)
        let password = "Qa-\(UUID().uuidString)"
        _ = try await session.signUp(email: email, password: password, confirmPassword: password)
        try await session.completeOnboarding(firstName: "QA A")
        let user = try #require(session.userId)
        let client = try ExportAPIClient(baseURLString: try #require(MoveMarkBackendConfig.apiBaseURLString))
        do {
            let property = try await properties.createProperty(PropertyRow(
                id: UUID(), userId: user, title: "QA ONLY — history pagination", addressLine1: "88 Harbour St",
                city: "Toronto", provinceState: "ON", postalCode: "M5J 2N8", country: "CA"))
            let room = try await properties.insertRoom(RoomRow(id: UUID(), propertyId: property.id, name: "Kitchen", sortOrder: 0))
            let inspection = try await inspections.upsertInspection(propertyId: property.id, userId: user, type: "move_in")
            let folder = "\(user.uuidString.lowercased())/\(property.id.uuidString.lowercased())/move-in/\(room.id.uuidString.lowercased())"

            // 45 entries (odd ones with notes); one photo each, and 20 on the newest entry.
            var items: [UUID] = []
            for k in 1...45 {
                items.append(try await inspections.insertInspectionItem(
                    inspectionId: inspection, roomId: room.id, notes: k % 2 == 1 ? "Entry \(k)\nnote \(k)" : "Entry \(k)", conditionRating: 4))
            }
            let newest = try #require(items.last)
            for (k, item) in items.enumerated() {
                for p in 0..<(item == newest ? 20 : 1) {
                    _ = try await inspections.insertEvidenceFile(propertyId: property.id, inspectionItemId: item, maintenanceIssueId: nil,
                                                                 filePath: "\(folder)/e\(k)-\(p).jpg", fileType: "image", capturedAt: Date())
                }
            }
            let issue = try await MaintenanceRepository().insertIssue(MaintenanceIssueRow(
                id: UUID(), propertyId: property.id, userId: user, title: "Leak", description: nil, category: nil, status: "open",
                dateDiscovered: nil, dateReported: nil, reportMethod: nil, landlordResponse: nil, followUpDate: nil, updatedAt: nil))
            for p in 0..<2 {
                _ = try await inspections.insertEvidenceFile(propertyId: property.id, inspectionItemId: nil, maintenanceIssueId: issue.id,
                                                             filePath: "\(user.uuidString.lowercased())/\(property.id.uuidString.lowercased())/\(issue.id.uuidString.lowercased())/m\(p).jpg",
                                                             fileType: "image", capturedAt: Date())
            }

            // Hydrate: newest 30 entries, true totals, true photo count on the newest entry with 12 photos loaded.
            let store = PropertyStore()
            await store.fetchAll(userId: user)
            var loaded = try #require(store.currentProperty?.rooms.first { $0.id == room.id })
            #expect(loaded.evidence.count == 30)
            #expect(loaded.moveInEntryTotal == 45 && loaded.moveInPhotoTotal == 64 && loaded.moveInTotals.notedEntries == 23)
            #expect(loaded.hasOlderEntries(moveOut: false))
            let newestEntry = try #require(loaded.evidence.first { $0.id == newest })
            #expect(newestEntry.photoCount == 20 && newestEntry.photos.count == 12)
            #expect(store.documentedRoomCount(for: try #require(store.currentProperty)) == 1)

            // Older entries, page by page: exactly the remaining 15, totals unchanged throughout.
            while try await store.loadOlderEntries(roomID: room.id, moveOut: false, pageSize: 7) {}
            loaded = try #require(store.currentProperty?.rooms.first { $0.id == room.id })
            #expect(Set(loaded.evidence.map(\.id)) == Set(items) && loaded.evidence.count == 45)
            #expect(loaded.moveInEntryTotal == 45 && loaded.moveInPhotoTotal == 64 && !loaded.hasOlderEntries(moveOut: false))

            // All photos of the newest entry: the 8 not loaded yet, in capture order, no duplicates.
            try await store.loadAllPhotos(entryId: newest, roomID: room.id, moveOut: false, pageSize: 5)
            let allPhotos = try #require(store.currentProperty?.rooms.first { $0.id == room.id }?.evidence.first { $0.id == newest }?.photos)
            #expect(allPhotos.count == 20 && Set(allPhotos.map(\.id)).count == 20)

            // Server-side aggregates.
            #expect(try await inspections.maintenancePhotoCounts(propertyId: property.id) == [issue.id: 2])
            let summaries: [VaultSummary] = try await dataAPI.rpc("get_vault_summaries", params: [String: String]()).execute().value
            #expect(summaries.map(\.propertyId) == [property.id])
            store.currentProperty = nil  // the vault path for a rental that isn't the active one
            let counts = await store.moveInProofCounts(for: property.id, userId: user)
            #expect(counts.documented == 1 && counts.total == 1)
        } catch {
            try? await client.deleteAccount()
            throw error
        }
        try await client.deleteAccount()
        await NeonAuthClient.shared.endSessionLocally(notify: false)
    }
}
