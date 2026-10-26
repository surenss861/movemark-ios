//
//  PropertyScreenSnapshotTests.swift
//  movemorkTests
//
//  @file Goldens for the rental and its rooms: the rental detail (populated, empty, loading, every notice,
//        the "Opening…" overlay, expanded records and details), Edit rental, the listing-proof photo sheet,
//        the Proof Sprint room list (populated, all documented, empty) and Add room. Pro phone, small phone
//        and AX3; the `tall` canvas shows a whole long screen in one image.
//  @domain design-system
//  @see [[ScreenSnapshotTests.swift]]
//
//  Re-record after an approved change: delete the PNG under __Snapshots__ and run twice.
//

import XCTest
import SwiftUI
import SnapshotTesting
@testable import MoveMark

@MainActor
final class PropertyScreenSnapshotTests: XCTestCase {
    /// The Pro phone's width at full content height, for screens longer than one viewport.
    private static let tall = ViewImageConfig(
        safeArea: ScreenSnapshot.pro.safeArea,
        size: CGSize(width: 402, height: 2300),
        traits: ScreenSnapshot.pro.traits
    )
    private static let tallDevice: [(String, ViewImageConfig)] = [("tall", tall)]

    // MARK: Fixtures

    private static let day = Date(timeIntervalSince1970: 1_760_900_000)   // Oct 19 2025, fixed for goldens

    private static func entry(_ title: String, photos: Int, issues: [String] = [], daysAgo: Double = 0) -> EvidenceRecord {
        EvidenceRecord(title: title, notes: "", issueTags: issues, condition: .good,
                       createdAt: day.addingTimeInterval(-daysAgo * 86_400), photoCount: photos, stage: .moveIn)
    }

    private static func room(_ name: String, _ entries: [EvidenceRecord] = [], id: Int) -> RoomRecord {
        RoomRecord(id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", id))!, name: name,
                   evidence: entries, moveOutEvidence: [])
    }

    private static func rental(rooms: [RoomRecord], documents: [String] = []) -> PropertyRecord {
        PropertyRecord(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            title: "88 Harbour St", addressLine1: "88 Harbour St", addressLine2: "Unit 1204",
            city: "Toronto", provinceState: "ON", postalCode: "M5J 2N8",
            landlordName: "Harbour Property Mgmt", landlordEmail: "leasing@example.com",
            moveInDate: day, leaseStartDate: day, leaseEndDate: day.addingTimeInterval(365 * 86_400),
            depositAmount: "1500", rentAmount: "2400", country: "CA",
            rooms: rooms, vaultDocuments: documents
        )
    }

    private static var populatedRooms: [RoomRecord] {
        [
            room("Kitchen", [entry("Counters", photos: 3, issues: ["Scratch"], daysAgo: 1)], id: 1),
            room("Living room", [entry("North wall", photos: 2, daysAgo: 2)], id: 2),
            room("Bedroom", id: 3),
            room("Bathroom", id: 4),
            room("Balcony", id: 5),
        ]
    }

    private static func vaultModel(_ property: PropertyRecord, configure: (inout PropertyVaultModel) -> Void = { _ in })
        -> PropertyVaultModel {
        let rooms = property.rooms
        let documented = rooms.filter { MMRoomProofMetrics.isDocumented($0) }.count
        let next = rooms.first { !MMRoomProofMetrics.isDocumented($0) }
        let order: [VaultDocumentType] = [.lease, .depositReceipt, .listingScreenshot, .cleaningReceipt, .utilityProof,
                                          .moveOutInvoice, .other]
        let records = order.map { type in
            let present = property.vaultDocuments.contains(type.rawValue)
            return PropertyVaultModel.Record(type: type, isPresent: present,
                                             subtitle: present ? "Attached" : "Not added yet")
        }
        var model = PropertyVaultModel(
            title: "88 Harbour St",
            location: "Toronto, ON",
            documented: documented,
            total: rooms.count,
            photos: rooms.reduce(0) { $0 + $1.moveInPhotoTotal },
            progress: rooms.isEmpty ? 0 : Double(documented) / Double(rooms.count),
            nextLine: next.map { "Next: \($0.name)" } ?? "Add rooms, then capture photos for each one.",
            primaryTitle: next.map { "Capture \($0.name)" } ?? "Add room",
            primaryIcon: next == nil ? nil : "camera.fill",
            trail: MMProofTimelineBuilder.vaultTrail(property: property, nextRoom: next, isExportReady: documented > 0),
            rooms: rooms.map { PropertyVaultModel.Room(room: $0, isNext: $0.id == next?.id) },
            records: records,
            uploadedCount: records.filter(\.isPresent).count,
            tools: PropertyVaultModel.Tool.all(openIssues: 1, completedRooms: documented, readinessScore: 45,
                                               exportsSubtitle: documented > 0 ? "Make and share reports"
                                                   : "Add proof before making a report"),
            tenancy: PropertyVaultModel.Detail.tenancy(for: property),
            contact: PropertyVaultModel.Detail.contact(for: property)
        )
        configure(&model)
        return model
    }

    private func vault(_ model: PropertyVaultModel, allRecords: Bool = false, details: Bool = false) -> some View {
        PropertyVaultContent(model: model, showAllRecords: .constant(allRecords), showDetails: .constant(details))
    }

    private static let populatedRental = rental(rooms: populatedRooms, documents: ["lease"])

    // MARK: Rental detail

    func testRentalPopulated() {
        assertScreen(vault(Self.vaultModel(Self.populatedRental)), devices: ScreenSnapshot.allDevices)
    }

    func testRentalPopulatedWhole() {
        assertScreen(vault(Self.vaultModel(Self.populatedRental) { $0.records[0].isHighlighted = true },
                           allRecords: true, details: true),
                     devices: Self.tallDevice)
    }

    func testRentalEmpty() {
        assertScreen(vault(Self.vaultModel(Self.rental(rooms: []))), devices: ScreenSnapshot.allDevices + Self.tallDevice)
    }

    func testRentalSummaryError() {
        assertScreen(vault(Self.vaultModel(Self.populatedRental) {
            $0.summaryError = MoveMarkFlowMessage.vaultSummaryRefreshFailed
        }), devices: [("small", ScreenSnapshot.small)])
    }

    func testRentalRecordNotices() {
        assertScreen(vault(Self.vaultModel(Self.populatedRental) {
            $0.summaryError = MoveMarkFlowMessage.vaultSummaryRefreshFailed   // hidden while an upload error shows
            $0.uploadError = "The upload didn't finish. Check your connection and try again."
            $0.previewError = MoveMarkFlowMessage.documentPreviewMissing
            $0.isUploading = true
        }), devices: Self.tallDevice)
    }

    func testRentalSoftNotice() {
        assertScreen(vault(Self.vaultModel(Self.populatedRental) {
            $0.softNotice = MoveMarkFlowMessage.documentVaultRefreshHint
        }), devices: Self.tallDevice)
    }

    func testRentalOpeningOverlay() {
        assertScreen(vault(Self.vaultModel(Self.populatedRental)).overlay { MMBusyOverlay(message: "Opening…") })
    }

    func testRentalLoading() {
        assertScreen(VaultDetailDestinationView(propertyId: UUID(), path: .constant([])),
                     devices: ScreenSnapshot.allDevices)
    }

    func testEditRental() {
        assertScreen(EditPropertyView(property: Self.populatedRental)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") {} } },
                     devices: ScreenSnapshot.allDevices)
    }

    func testListingProofPhotoSheet() {
        assertScreen(ReplacePhotoSheet(onDismiss: {}, selection: .constant(nil)), inNavigation: false)
    }

    // MARK: Rooms (Proof Sprint)

    private func roomList(_ property: PropertyRecord?) -> some View {
        let store = PropertyStore()
        store.currentProperty = property
        return RoomListView(path: .constant([])).environment(store)
    }

    func testRoomListPopulated() {
        assertScreen(roomList(Self.populatedRental), devices: ScreenSnapshot.allDevices + Self.tallDevice)
    }

    func testRoomListAllDocumented() {
        let rooms = [Self.room("Kitchen", [Self.entry("Counters", photos: 3)], id: 1),
                     Self.room("Bedroom", [Self.entry("Closet", photos: 2, issues: ["Dent", "Stain"])], id: 2)]
        assertScreen(roomList(Self.rental(rooms: rooms, documents: ["lease", "deposit_receipt"])))
    }

    func testRoomListEmpty() {
        assertScreen(roomList(Self.rental(rooms: [])), devices: ScreenSnapshot.allDevices)
    }

    func testAddRoom() {
        assertScreen(AddRoomSheetView(onDismiss: {}), devices: ScreenSnapshot.allDevices, inNavigation: false)
    }

    func testAddRoomError() {
        assertScreen(AddRoomSheetView(onDismiss: {}, roomName: "Office",
                                      errorMessage: "Couldn't add the room. Check your connection and try again."),
                     inNavigation: false)
    }
}
