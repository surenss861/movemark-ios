//
//  RentalRecordSnapshotTests.swift
//  movemorkTests
//
//  @file Goldens for the rental record and everything around it, at day 1 (no rooms), day 3 (half
//        documented) and month 6 (every room, records, maintenance cases, move-out): the rental detail in
//        every state (records added / needed, maintenance open / none, move-out present / absent, loading,
//        refresh error, upload and preview notices, "Opening…"), the room list (populated, all documented,
//        empty), Add a room, Edit rental, Add your rental and Listing proof. Pro phone, small phone and AX3;
//        the `tall` canvases show a whole long screen in one image. Supersedes PropertyScreenSnapshotTests.
//  @domain property
//  @see [[ScreenSnapshotTests.swift]] [[PropertyVaultContent.swift]]
//
//  Re-record after an approved change: delete the PNG under __Snapshots__ and run twice.
//

import XCTest
import SwiftUI
import SnapshotTesting
@testable import MoveMark

@MainActor
final class RentalRecordSnapshotTests: XCTestCase {
    // MARK: Canvases

    private static func tall(_ height: CGFloat, ax: Bool = false) -> ViewImageConfig {
        ViewImageConfig(
            safeArea: ScreenSnapshot.pro.safeArea,
            size: CGSize(width: 402, height: height),
            traits: ax ? ScreenSnapshot.proAX.traits : ScreenSnapshot.pro.traits
        )
    }
    private static let tall: [(String, ViewImageConfig)] = [("tall", tall(1800))]
    private static let tallAX: [(String, ViewImageConfig)] = [("tall-ax3", tall(3000, ax: true))]
    private static let smallTall: [(String, ViewImageConfig)] = [("small-tall", ViewImageConfig(
        safeArea: ScreenSnapshot.small.safeArea, size: CGSize(width: 375, height: 2100), traits: ScreenSnapshot.small.traits))]

    // MARK: Fixtures

    private static let day = Date(timeIntervalSince1970: 1_760_900_000)   // Oct 19 2025, fixed for goldens

    private static func photo(_ name: String) -> UIImage? {
        guard let url = Bundle(for: RentalRecordSnapshotTests.self).url(forResource: name, withExtension: "jpg") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    private static func entry(photos: Int, issues: [String] = [], stage: EvidenceRecord.Stage = .moveIn) -> EvidenceRecord {
        EvidenceRecord(title: "Walls", notes: "", issueTags: issues, condition: .good, createdAt: day,
                       photoCount: photos, stage: stage)
    }

    private static func room(_ name: String, photos: Int = 0, issues: [String] = [], moveOut: Int = 0, id: Int) -> RoomRecord {
        RoomRecord(id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", id))!, name: name,
                   evidence: photos > 0 ? [entry(photos: photos, issues: issues)] : [],
                   moveOutEvidence: moveOut > 0 ? [entry(photos: moveOut, stage: .moveOut)] : [])
    }

    private static func rental(rooms: [RoomRecord], documents: [String] = []) -> PropertyRecord {
        PropertyRecord(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            title: "88 Harbour St", addressLine1: "88 Harbour St", addressLine2: "2304",
            city: "Toronto", provinceState: "ON", postalCode: "M5J 2N8",
            landlordName: "Harbour Property Mgmt", landlordEmail: "leasing@example.com",
            moveInDate: day, leaseStartDate: day, leaseEndDate: day.addingTimeInterval(365 * 86_400),
            depositAmount: "1500", rentAmount: "2400", country: "CA",
            rooms: rooms, vaultDocuments: documents
        )
    }

    /// Day 3: 8 of 10 rooms documented, the lease on file.
    private static var partialRooms: [RoomRecord] {
        [
            room("Kitchen", photos: 6, issues: ["Scratch"], id: 1),
            room("Living Room", photos: 4, id: 2),
            room("Primary Bedroom", photos: 5, id: 3),
            room("Second Bedroom", photos: 3, id: 4),
            room("Bathroom", photos: 4, issues: ["Chip", "Stain"], id: 5),
            room("Balcony", id: 6),
            room("Ensuite", photos: 3, id: 7),
            room("Hallway", photos: 2, id: 8),
            room("Closet", photos: 2, id: 9),
            room("Laundry", id: 10),
        ]
    }

    /// Month 6: every room documented, move-out begun in two.
    private static var completeRooms: [RoomRecord] {
        [
            room("Kitchen", photos: 6, issues: ["Scratch"], moveOut: 5, id: 1),
            room("Living Room", photos: 4, moveOut: 4, id: 2),
            room("Primary Bedroom", photos: 5, id: 3),
            room("Bathroom", photos: 4, issues: ["Chip"], id: 4),
            room("Balcony", photos: 2, id: 5),
            room("Hallway", photos: 2, id: 6),
        ]
    }

    private static let order: [VaultDocumentType] = [.lease, .depositReceipt, .listingScreenshot, .cleaningReceipt,
                                                     .utilityProof, .moveOutInvoice, .other]

    private static let files: [VaultDocumentType: (String, String)] = [
        .lease: ("Oct 17, 2025", "88-Harbour-St-residential-tenancy-agreement-2025.pdf"),
        .depositReceipt: ("Oct 18, 2025", "deposit-etransfer.pdf"),
        .listingScreenshot: ("Oct 12, 2025", "Image"),
        .cleaningReceipt: ("Apr 2, 2026", "spotless-clean-receipt.pdf"),
    ]

    private static func model(_ property: PropertyRecord, configure: (inout PropertyVaultModel) -> Void = { _ in })
        -> PropertyVaultModel {
        var model = PropertyVaultModel(
            title: PropertyVaultModel.displayTitle(for: property),
            addressLine: PropertyVaultModel.addressLine(for: property),
            moveInLine: PropertyVaultModel.moveInLine(for: property, now: day.addingTimeInterval(86_400)),
            rooms: property.rooms.map { MMRentalRoom($0) },
            nextRoomID: property.rooms.first { !MMRoomProofMetrics.isDocumented($0) }?.id,
            records: order.map { type in
                let present = property.vaultDocuments.contains(type.rawValue)
                return .init(type: type, isPresent: present, addedOn: present ? files[type]?.0 : nil,
                             file: present ? files[type]?.1 : nil)
            },
            details: PropertyVaultModel.Detail.primary(for: property),
            moreDetails: PropertyVaultModel.Detail.more(for: property)
        )
        configure(&model)
        return model
    }

    private func vault(_ model: PropertyVaultModel, allRecords: Bool = false, details: Bool = false) -> some View {
        PropertyVaultContent(model: model, showAllRecords: .constant(allRecords), showDetails: .constant(details))
    }

    private static let day1 = rental(rooms: [])
    private static let day3 = rental(rooms: partialRooms, documents: ["lease"])
    private static let month6 = rental(rooms: completeRooms,
                                       documents: ["lease", "deposit_receipt", "listing_screenshot", "cleaning_receipt"])

    // MARK: Rental detail

    /// Day 1: a new rental — no rooms yet, every record needed, no cases.
    func testRentalDay1() {
        assertScreen(vault(Self.model(Self.day1)), devices: ScreenSnapshot.allDevices + Self.tall)
    }

    /// Day 3: 8 of 10 rooms, the lease added, one open maintenance case of two.
    func testRentalDay3() {
        assertScreen(vault(Self.model(Self.day3) { $0.maintenance = .init(open: 1, total: 2) }),
                     devices: ScreenSnapshot.allDevices + Self.tall + Self.smallTall + Self.tallAX)
    }

    /// Month 6: every room, all three records plus a receipt, three resolved cases, move-out under way.
    func testRentalMonth6() {
        assertScreen(vault(Self.model(Self.month6) {
            $0.maintenance = .init(open: 0, total: 3)
            $0.moveOut = .init(documented: 2, total: 6)
        }), devices: ScreenSnapshot.allDevices + Self.tall + Self.tallAX)
    }

    /// The lease is ending and no move-out proof exists yet: move-out appears as related proof.
    func testRentalMoveOutLeaseEnding() {
        assertScreen(vault(Self.model(Self.month6) {
            $0.moveOut = .init(documented: 0, total: 6, daysUntilLeaseEnd: 21)
        }), devices: Self.tall)
    }

    /// Other records and the deposit / rent / landlord details expanded; a record just added highlighted.
    func testRentalExpanded() {
        assertScreen(vault(Self.model(Self.day3) { $0.records[0].isHighlighted = true }, allRecords: true, details: true),
                     devices: Self.tall)
    }

    func testRentalSummaryError() {
        assertScreen(vault(Self.model(Self.day3) { $0.summaryError = MoveMarkFlowMessage.vaultSummaryRefreshFailed }),
                     devices: [("pro", ScreenSnapshot.pro), ("small", ScreenSnapshot.small)])
    }

    func testRentalUploadNotices() {
        assertScreen(vault(Self.model(Self.day3) {
            $0.summaryError = MoveMarkFlowMessage.vaultSummaryRefreshFailed   // hidden while an upload error shows
            $0.uploadError = "Couldn’t upload the file. Check your connection and try again."
            $0.previewError = MoveMarkFlowMessage.documentPreviewMissing
            $0.isUploading = true
        }), devices: Self.tall)
    }

    func testRentalSoftNotice() {
        assertScreen(vault(Self.model(Self.day3) { $0.softNotice = MoveMarkFlowMessage.documentVaultRefreshHint }),
                     devices: Self.tall)
    }

    func testRentalOpeningOverlay() {
        assertScreen(vault(Self.model(Self.day3)).overlay { MMBusyOverlay(message: "Opening…") })
    }

    func testRentalLoading() {
        assertScreen(VaultDetailDestinationView(propertyId: UUID(), path: .constant([])),
                     devices: ScreenSnapshot.allDevices)
    }

    // MARK: Room list

    private func roomList(_ property: PropertyRecord?) -> some View {
        let store = PropertyStore()
        store.currentProperty = property
        return RoomListView(path: .constant([])).environment(store)
    }

    func testRoomListPopulated() {
        assertScreen(roomList(Self.day3), devices: ScreenSnapshot.allDevices + Self.tall + Self.tallAX)
    }

    func testRoomListAllDocumented() {
        assertScreen(roomList(Self.month6), devices: [("pro", ScreenSnapshot.pro), ("ax3", ScreenSnapshot.proAX)] + Self.tall)
    }

    func testRoomListEmpty() {
        assertScreen(roomList(Self.day1), devices: ScreenSnapshot.allDevices)
    }

    // MARK: Sheets and forms

    func testAddRoom() {
        let store = PropertyStore()
        store.currentProperty = Self.rental(rooms: [Self.room("Kitchen", id: 1), Self.room("Bathroom", id: 2)])
        assertScreen(AddRoomSheetView(onDismiss: {}).environment(store), devices: ScreenSnapshot.allDevices, inNavigation: false)
    }

    func testAddRoomError() {
        assertScreen(AddRoomSheetView(onDismiss: {}, roomName: "Office",
                                      errorMessage: "Couldn’t add the room. Check your connection and try again."),
                     inNavigation: false)
    }

    func testEditRental() {
        assertScreen(EditPropertyView(property: Self.day3)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") {} } },
                     devices: ScreenSnapshot.allDevices + Self.tall)
    }

    func testAddRental() {
        assertScreen(NewPropertyView(today: Self.day).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") {} } },
                     devices: ScreenSnapshot.allDevices + Self.tall)
    }

    func testListingProofEmpty() {
        assertScreen(ReplacePhotoSheet(onDismiss: {}, selection: .constant(nil)),
                     devices: ScreenSnapshot.allDevices, inNavigation: false)
    }

    func testListingProofSaved() {
        let current = ReplacePhotoSheet.Current(path: "fixture/listing.jpg",
                                                addedOn: Self.day.addingTimeInterval(-7 * 86_400),
                                                resolve: { _ in nil })
        assertScreen(ReplacePhotoSheet(onDismiss: {}, selection: .constant(nil), current: current)
            .environment(\.mmEvidenceImageOverride, { _ in Self.photo("snap-living") }),
                     devices: ScreenSnapshot.allDevices, inNavigation: false)
    }
}
