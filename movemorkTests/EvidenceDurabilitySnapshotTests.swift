//
//  EvidenceDurabilitySnapshotTests.swift
//  movemorkTests
//
//  @file The honest-status surfaces of evidence durability: the room's one status line (saved on this
//        iPhone · uploading · failed) under the new entry's header, with the save bar; and the Proof root's
//        quiet "N photos not uploaded yet" row over the header.
//

import XCTest
import SwiftUI
import SnapshotTesting
@testable import MoveMark

@MainActor
final class EvidenceDurabilitySnapshotTests: XCTestCase {

    private static func photo(_ name: String) -> UIImage {
        let url = Bundle(for: EvidenceDurabilitySnapshotTests.self).url(forResource: name, withExtension: "jpg")!
        return UIImage(contentsOfFile: url.path)!
    }

    private static var photos: [UIImage] { ["snap-living", "snap-kitchen", "snap-bedroom"].map(photo) }

    /// The room's new entry as the screen lays it out: header + status line, pending photos, save bar.
    private func roomNewEntry(_ state: MMEvidenceSyncState) -> some View {
        let uploading: Bool = { if case .uploading = state { return true } else { return false } }()
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                EvidenceNewEntryHeader(moveOutMode: false, photoCount: 3, syncState: state, onRetry: {})
                ProofPhotoGridView(images: Self.photos, isUploading: uploading, onRemove: uploading ? nil : { _ in })
                if state == .failed {
                    MMEvidenceNotice(message: "Couldn’t save this proof. Check your connection and try again.",
                                     actionTitle: MMCopy.tryAgain, action: {})
                }
            }
            .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
            .padding(.vertical, 18)
        }
        .background(MMInk.sheet.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            EvidenceCaptureBottomSaveBar(photoCount: 3, tagCount: 0, condition: .good, isUploading: uploading,
                                         didJustSave: false, moveOutMode: false, onSave: {})
        }
        .environment(\.mmEvidenceOnLight, true)
        .environment(\.colorScheme, .light)
    }

    func testRoomStatusSavedOnThisIPhone() {
        assertScreen(roomNewEntry(.savedLocally), devices: ScreenSnapshot.allDevices, inNavigation: false)
    }

    func testRoomStatusUploading() {
        assertScreen(roomNewEntry(.uploading(count: 3)), devices: ScreenSnapshot.allDevices, inNavigation: false)
    }

    func testRoomStatusFailed() {
        assertScreen(roomNewEntry(.failed), devices: ScreenSnapshot.allDevices, inNavigation: false)
    }

    // MARK: Proof root

    private var proofModel: ProofHomeModel {
        ProofHomeModel(
            propertyName: "88 Harbour St", addressLine: "Unit 2304",
            documented: 2, totalRooms: 6,
            nextRoomName: "Kitchen", primaryTitle: "Capture Kitchen",
            photos: 9, records: 1, issues: 0,
            recent: [
                .init(id: UUID(), roomName: "Living Room", photoCount: 4, photoPath: "fixture/snap-living.jpg"),
                .init(id: UUID(), roomName: "Bedroom", photoCount: 5, photoPath: "fixture/snap-bedroom.jpg"),
            ],
            upcoming: [.init(id: UUID(), roomName: "Kitchen"), .init(id: UUID(), roomName: "Bathroom")],
            actions: [.init(id: "maintenance", kind: .maintenance, title: "Maintenance issue",
                            subtitle: "Report existing issues", icon: "wrench.adjustable")],
            otherRentals: []
        )
    }

    private func proofRoot(count: Int, failed: Bool = false) -> some View {
        ProofHomeView(model: proofModel, resolvePhotoURL: { _ in nil })
            .mmPendingUploads(count: count, failed: failed, onOpen: {})
            .safeAreaInset(edge: .bottom, spacing: 0) { MMRootDock(selectedTab: .constant(.vaults)) }
            .environment(\.mmEvidenceImageOverride, { path in
                Self.photo((path as NSString).deletingPathExtension.components(separatedBy: "/").last ?? path)
            })
    }

    func testProofRootPendingRow() {
        assertScreen(proofRoot(count: 3), devices: ScreenSnapshot.allDevices, inNavigation: false)
    }

    func testProofRootPendingRowFailed() {
        assertScreen(proofRoot(count: 1, failed: true), inNavigation: false)
    }
}
