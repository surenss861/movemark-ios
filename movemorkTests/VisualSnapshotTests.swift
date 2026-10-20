//
//  VisualSnapshotTests.swift
//  movemorkTests
//
//  @file Golden screenshots for redesigned screens: once a screen is approved, its snapshot is the
//        visual source of truth and any drift in spacing, type or geometry fails here
//  @domain design-system
//  @status wip
//  @see [[VISUAL_STANDARD]] — rollout and approval rules
//  @see [[ProofHomeView.swift]]
//
//  Re-record after an approved change: delete the PNG under __Snapshots__ and run once.
//
//  STATUS: Proof snapshots are CANDIDATES recorded from the reference-reproduction pass
//  (2026-10-20). They become approved goldens only when the user signs off the Proof screen.
//

import XCTest
import SwiftUI
import SnapshotTesting
@testable import MoveMark

@MainActor
final class VisualSnapshotTests: XCTestCase {

    // MARK: Devices

    /// 6.3" iPhone Pro (402 × 874 pt, Dynamic Island).
    private static let pro = ViewImageConfig(
        safeArea: UIEdgeInsets(top: 62, left: 0, bottom: 34, right: 0),
        size: CGSize(width: 402, height: 874),
        traits: UITraitCollection(traitsFrom: [.init(displayScale: 3), .init(userInterfaceStyle: .light)])
    )

    /// Smallest supported phone (iPhone SE, 375 × 667 pt).
    private static let small = ViewImageConfig(
        safeArea: UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0),
        size: CGSize(width: 375, height: 667),
        traits: UITraitCollection(traitsFrom: [.init(displayScale: 2), .init(userInterfaceStyle: .light)])
    )

    /// Pro size at AX3, the largest accessibility text size.
    private static let proAX = ViewImageConfig(
        safeArea: pro.safeArea,
        size: pro.size,
        traits: UITraitCollection(traitsFrom: [pro.traits, .init(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)])
    )

    private static let strategy: (ViewImageConfig) -> Snapshotting<UIViewController, UIImage> = {
        .image(on: $0, precision: 0.995, perceptualPrecision: 0.98)
    }

    // MARK: Fixtures

    private static func photo(_ name: String) -> UIImage? {
        guard let url = Bundle(for: VisualSnapshotTests.self).url(forResource: name, withExtension: "jpg") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    /// Evidence paths map to bundled photos so renders are synchronous and deterministic.
    private static let images: (String) -> UIImage? = { path in
        let name = (path as NSString).deletingPathExtension.components(separatedBy: "/").last ?? path
        return photo(name)
    }

    private func host<V: View>(_ view: V) -> UIViewController {
        UIHostingController(rootView: view.environment(\.mmEvidenceImageOverride, Self.images))
    }

    private func proofModel(_ state: String) -> ProofHomeModel {
        let actions: [ProofHomeModel.Action] = [
            .init(id: "lease", kind: .document(.lease), title: "Lease", subtitle: "Add your lease agreement", icon: "doc.text", needed: true),
            .init(id: "deposit", kind: .document(.depositReceipt), title: "Deposit receipt", subtitle: "Upload proof of deposit", icon: "receipt", needed: true),
            .init(id: "listing", kind: .document(.listingScreenshot), title: "Listing proof", subtitle: "Save original listing", icon: "photo", needed: true),
            .init(id: "maintenance", kind: .maintenance, title: "Maintenance issue", subtitle: "Report existing issues", icon: "wrench.adjustable"),
        ]
        var m = ProofHomeModel(
            propertyName: "88 Harbour St", addressLine: "Unit 2304",
            documented: 9, totalRooms: 10,
            heroPhotoPath: "fixture/snap-hero.jpg",
            nextRoomName: "Primary Bedroom", primaryTitle: "Capture Primary Bedroom",
            photos: 12, records: 3, issues: 1,
            recent: [
                .init(id: UUID(), roomName: "Living Room", photoCount: 4, photoPath: "fixture/snap-living.jpg"),
                .init(id: UUID(), roomName: "Kitchen", photoCount: 3, photoPath: "fixture/snap-kitchen.jpg"),
                .init(id: UUID(), roomName: "Bedroom", photoCount: 3, photoPath: "fixture/snap-bedroom.jpg"),
            ],
            actions: actions, otherRentals: []
        )
        switch state {
        case "complete":
            m.documented = 10; m.nextRoomName = nil; m.primaryTitle = "View move-in report"
            m.actions = [actions[3], .init(id: "report", kind: .report, title: "Move-in report", subtitle: "Ready to share", icon: "doc.richtext")]
        case "one-room":
            // One documented room: the row keeps its rhythm with honest capture slots.
            m.documented = 1; m.photos = 2; m.issues = 0
            m.nextRoomName = "Living Room"; m.primaryTitle = "Capture Living Room"
            m.recent = [.init(id: UUID(), roomName: "Kitchen", photoCount: 2, photoPath: "fixture/snap-kitchen.jpg")]
            m.upcoming = [.init(id: UUID(), roomName: "Living Room"), .init(id: UUID(), roomName: "Primary Bedroom")]
        case "no-photos":
            m.documented = 0; m.heroPhotoPath = nil; m.recent = []; m.photos = 0; m.issues = 0
            m.nextRoomName = "Kitchen"; m.primaryTitle = "Capture Kitchen"
        default: break
        }
        return m
    }

    private func proofScreen(_ state: String) -> some View {
        ProofHomeView(model: proofModel(state), resolvePhotoURL: { _ in nil })
            .safeAreaInset(edge: .bottom, spacing: 0) {
                MMProofTabBarV4(selectedTab: .constant(.vaults))
            }
    }

    // MARK: Proof

    func testProofPopulated() {
        assertSnapshot(of: host(proofScreen("populated")), as: Self.strategy(Self.pro), named: "pro")
        assertSnapshot(of: host(proofScreen("populated")), as: Self.strategy(Self.small), named: "small")
        assertSnapshot(of: host(proofScreen("populated")), as: Self.strategy(Self.proAX), named: "ax3")
    }

    func testProofComplete() {
        assertSnapshot(of: host(proofScreen("complete")), as: Self.strategy(Self.pro), named: "pro")
    }

    func testProofOneRoom() {
        assertSnapshot(of: host(proofScreen("one-room")), as: Self.strategy(Self.pro), named: "pro")
    }

    func testProofNoPhotos() {
        assertSnapshot(of: host(proofScreen("no-photos")), as: Self.strategy(Self.pro), named: "pro")
    }

    func testProofNoRental() {
        assertSnapshot(of: host(ProofHomeEmptyView(onStart: {}, onRetry: {})), as: Self.strategy(Self.pro), named: "pro")
    }

    // MARK: Room (current dark design — regression only until Room is rebuilt and approved)

    private func roomScreen(entries: [EvidenceRecord], name: String) -> some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    RoomEvidenceHero(
                        roomName: name, entries: entries, moveOutMode: false,
                        topInset: geo.safeAreaInsets.top, containerSize: geo.size,
                        resolvePhotoURL: { _ in nil }
                    )
                    if !entries.isEmpty {
                        RoomEvidenceBody(entries: entries, moveOutMode: false, isBusy: false,
                                         onEdit: { _ in }, onAddPhotos: { _ in }, onDelete: { _ in })
                            .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .background(MoveMarkTheme.Colors.appBackground)
        .environment(\.colorScheme, .dark)
    }

    func testRoomEmpty() {
        assertSnapshot(of: host(roomScreen(entries: [], name: "Balcony/Patio")), as: Self.strategy(Self.pro), named: "pro")
    }

    func testRoomPopulated() {
        let recorded = Date(timeIntervalSince1970: 1_760_900_000)
        let entry = EvidenceRecord(
            title: "North wall", notes: "Two scratches beside the window.", issueTags: ["Scratch"],
            condition: .fair, createdAt: recorded, photoCount: 3,
            photos: ["snap-living", "snap-kitchen", "snap-bedroom"].map { EvidencePhoto(id: UUID(), filePath: "fixture/\($0).jpg") },
            stage: .moveIn
        )
        assertSnapshot(of: host(roomScreen(entries: [entry], name: "Living Room")), as: Self.strategy(Self.pro), named: "pro")
    }
}
