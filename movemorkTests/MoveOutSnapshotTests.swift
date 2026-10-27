//
//  MoveOutSnapshotTests.swift
//  movemorkTests
//
//  @file Goldens for Move-out: the room-by-room comparison in every state (new issue, changed, missing,
//        unchanged, no baseline), the empty screen without move-in proof, all rooms complete, and the report's
//        exporting / queued / error states — on the Pro phone, the small phone and AX3, plus a tall full page.
//        Also pins the comparison state rule (MoveOutComparison.make).
//  @domain move-out
//  @see [[MMSystem+MoveOut.swift]]
//
//  Re-record after an approved change: delete the PNG under __Snapshots__ and run twice.
//

import XCTest
import SwiftUI
import SnapshotTesting
@testable import MoveMark

@MainActor
final class MoveOutSnapshotTests: XCTestCase {
    private static let moveInDay = Date(timeIntervalSince1970: 1_761_510_540)      // Oct 26, 2025
    private static let moveOutDay = Date(timeIntervalSince1970: 1_777_550_400)     // Apr 30, 2026
    private static let propertyID = UUID(uuidString: "6F1E2C3D-0000-4000-8000-0000000000B1")!
    private static let userID = UUID(uuidString: "6F1E2C3D-0000-4000-8000-0000000000B2")!

    // MARK: Fixtures

    private static func photo(_ name: String) -> UIImage? {
        guard let url = Bundle(for: MoveOutSnapshotTests.self).url(forResource: name, withExtension: "jpg") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    private static func photos(_ name: String, _ count: Int, seed: Int) -> [EvidencePhoto] {
        (0..<count).map { i in
            EvidencePhoto(id: UUID(uuidString: String(format: "6F1E2C3D-0000-4000-8000-%012d", seed * 100 + i))!,
                          filePath: "fixture/\(name).jpg")
        }
    }

    private static func entry(_ title: String, notes: String = "", tags: [String] = [], _ condition: RoomRecord.ConditionRating,
                              stage: EvidenceRecord.Stage, photo: String?, count: Int, seed: Int) -> EvidenceRecord {
        EvidenceRecord(title: title, notes: notes, issueTags: tags, condition: condition,
                       createdAt: stage == .moveOut ? moveOutDay : moveInDay, photoCount: count,
                       photos: photo.map { photos($0, min(count, 2), seed: seed) } ?? [], stage: stage)
    }

    private static func room(_ n: Int, _ name: String, moveIn: [EvidenceRecord] = [], moveOut: [EvidenceRecord] = []) -> RoomRecord {
        RoomRecord(id: UUID(uuidString: String(format: "6F1E2C3D-0000-4000-8001-%012d", n))!, name: name,
                   evidence: moveIn, moveOutEvidence: moveOut)
    }

    /// New issue, changed, missing (×2), unchanged (×2) and one room without a move-in baseline.
    private static var allStateRooms: [RoomRecord] {
        [
            room(1, "Living Room",
                 moveIn: [entry("Walls", notes: "Walls clean, no marks", .good, stage: .moveIn, photo: "snap-living", count: 6, seed: 1)],
                 moveOut: [entry("Walls", notes: "Scuffing beside the window", .fair, stage: .moveOut, photo: "snap-living", count: 4, seed: 2)]),
            room(2, "Bedroom",
                 moveIn: [entry("Floor", notes: "Carpet even, no stains", .good, stage: .moveIn, photo: "snap-bedroom", count: 3, seed: 3)]),
            room(3, "Kitchen",
                 moveIn: [entry("Counters", notes: "Counters and cabinet doors intact", tags: ["Scratch"], .good,
                                stage: .moveIn, photo: "snap-kitchen", count: 5, seed: 4)],
                 moveOut: [entry("Counters", notes: "Ring mark near the sink", tags: ["Scratch", "Stain"], .good,
                                 stage: .moveOut, photo: "snap-kitchen", count: 3, seed: 5)]),
            room(4, "Bathroom",
                 moveIn: [entry("Bathroom", .excellent, stage: .moveIn, photo: "snap-hero", count: 2, seed: 6)],
                 moveOut: [entry("Bathroom", .excellent, stage: .moveOut, photo: "snap-hero", count: 2, seed: 7)]),
            room(5, "Hallway",
                 moveIn: [entry("Hallway", .good, stage: .moveIn, photo: "snap-living", count: 1, seed: 8)],
                 moveOut: [entry("Hallway", .good, stage: .moveOut, photo: "snap-living", count: 1, seed: 9)]),
            room(6, "Office",
                 moveIn: [entry("Desk wall", notes: "Two picture hooks left by the last tenant", .fair,
                                stage: .moveIn, photo: "snap-hero", count: 2, seed: 10)]),
        ]
    }

    private static var completeRooms: [RoomRecord] {
        allStateRooms.enumerated().map { i, r in
            guard r.moveOutEvidence.isEmpty else { return r }
            var copy = r
            let src = r.evidence.first!
            copy.moveOutEvidence = [entry(src.title, src.condition, stage: .moveOut,
                                          photo: src.photos.first.map { ($0.filePath as NSString).lastPathComponent.replacingOccurrences(of: ".jpg", with: "") },
                                          count: 2, seed: 20 + i)]
            return copy
        }
    }

    private static var noBaselineRooms: [RoomRecord] {
        [room(1, "Living Room"), room(2, "Kitchen"), room(3, "Bedroom")]
    }

    private var checklist: MoveOutChecklistRow {
        MoveOutChecklistRow(id: UUID(), propertyId: Self.propertyID, userId: Self.userID, cabinetsClear: true,
                            appliancesClean: true, keysReturned: false, utilitiesCancelled: false,
                            cleaningReceiptUploaded: false, forwardingAddressNoted: true)
    }

    private func store(_ rooms: [RoomRecord]) -> PropertyStore {
        let store = PropertyStore()
        store.currentProperty = PropertyRecord(id: Self.propertyID, title: "88 Harbour St", addressLine1: "88 Harbour St",
                                               moveInDate: Self.moveInDay, leaseEndDate: Self.moveOutDay, rooms: rooms)
        return store
    }

    private func screen(_ rooms: [RoomRecord], checklist: MoveOutChecklistRow? = nil, exporting: Bool = false,
                        error: String? = nil, queued: String? = nil) -> some View {
        MoveOutFoundationView(path: .constant([]), initialChecklist: checklist, initiallyExporting: exporting,
                              initialError: error, initialQueuedNotice: queued)
            .environment(store(rooms))
            .environment(\.mmEvidenceImageOverride, { path in
                Self.photo((path as NSString).deletingPathExtension.components(separatedBy: "/").last ?? path)
            })
    }

    // MARK: Screens

    func testMoveOutAllStates() {
        assertScreen(screen(Self.allStateRooms, checklist: checklist), devices: ScreenSnapshot.allDevices)
    }

    func testMoveOutAllStatesFullPage() {
        let tall = ViewImageConfig(safeArea: ScreenSnapshot.pro.safeArea, size: CGSize(width: 402, height: 3400),
                                   traits: ScreenSnapshot.pro.traits)
        assertSnapshot(of: ScreenSnapshot.host(screen(Self.allStateRooms, checklist: checklist)),
                       as: ScreenSnapshot.strategy(tall), named: "tall")
    }

    func testMoveOutNoMoveInProof() {
        assertScreen(screen(Self.noBaselineRooms), devices: ScreenSnapshot.allDevices)
    }

    func testMoveOutNoRooms() {
        assertScreen(screen([]))
    }

    func testMoveOutComplete() {
        assertScreen(screen(Self.completeRooms, checklist: checklist), devices: ScreenSnapshot.allDevices)
    }

    func testMoveOutCompleteFullPage() {
        let tall = ViewImageConfig(safeArea: ScreenSnapshot.pro.safeArea, size: CGSize(width: 402, height: 2600),
                                   traits: ScreenSnapshot.pro.traits)
        assertSnapshot(of: ScreenSnapshot.host(screen(Self.completeRooms, checklist: checklist)),
                       as: ScreenSnapshot.strategy(tall), named: "tall")
    }

    /// Back from capturing the last two rooms: they now read as compared, and the report is the next step.
    func testMoveOutJustCompared() {
        let ids: Set<UUID> = [Self.allStateRooms[1].id, Self.allStateRooms[5].id]
        assertScreen(MoveOutFoundationView(path: .constant([]), initialChecklist: checklist, initialJustCompared: ids)
            .environment(store(Self.completeRooms))
            .environment(\.mmEvidenceImageOverride, { path in
                Self.photo((path as NSString).deletingPathExtension.components(separatedBy: "/").last ?? path)
            }))
    }

    /// An unchanged room expanded to its full pair.
    func testUnchangedRowExpanded() {
        let row = MoveOutCompactRow(comparison: MoveOutComparison.make(room: Self.allStateRooms[3]), resolve: { _ in nil },
                                    initiallyExpanded: true)
            .background(MMInk.card)
            .padding(20)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(MMInk.sheet)
            .environment(\.mmEvidenceImageOverride, { path in
                Self.photo((path as NSString).deletingPathExtension.components(separatedBy: "/").last ?? path)
            })
        let config = ViewImageConfig(safeArea: .zero, size: CGSize(width: 402, height: 400), traits: ScreenSnapshot.pro.traits)
        assertSnapshot(of: UIHostingController(rootView: row), as: ScreenSnapshot.strategy(config), named: "pro")
    }

    /// The report states sit at the end of the page, so these render the full page.
    private var reportPage: ViewImageConfig {
        ViewImageConfig(safeArea: ScreenSnapshot.pro.safeArea, size: CGSize(width: 402, height: 2600), traits: ScreenSnapshot.pro.traits)
    }

    func testMoveOutExporting() {
        assertSnapshot(of: ScreenSnapshot.host(screen(Self.completeRooms, checklist: checklist, exporting: true)),
                       as: ScreenSnapshot.strategy(reportPage), named: "tall")
    }

    func testMoveOutQueued() {
        assertSnapshot(of: ScreenSnapshot.host(screen(Self.completeRooms, checklist: checklist,
                                                      queued: "Report queued — it will appear in Reports when ready")),
                       as: ScreenSnapshot.strategy(reportPage), named: "tall")
    }

    func testMoveOutError() {
        assertScreen(screen(Self.completeRooms, checklist: checklist, error: "Couldn't queue move-out report. Try again."),
                     devices: [("pro", ScreenSnapshot.pro), ("small", ScreenSnapshot.small)])
    }

    // MARK: State rule

    func testComparisonStateRule() {
        let states = Dictionary(uniqueKeysWithValues: Self.allStateRooms.map { ($0.name, MoveOutComparison.make(room: $0).state) })
        XCTAssertEqual(states["Living Room"], .changed)      // Good → Fair, no new tag
        XCTAssertEqual(states["Kitchen"], .newIssue)         // "Stain" not in move-in tags; "Scratch" was
        XCTAssertEqual(states["Bedroom"], .missing)
        XCTAssertEqual(states["Bathroom"], .unchanged)
        XCTAssertEqual(MoveOutComparison.make(room: Self.allStateRooms[2]).newTags, ["Stain"])

        // Move-out photos without any move-in photo: no change is claimed.
        let noBaseline = Self.room(9, "Entry", moveOut: [Self.entry("Entry", tags: ["Scuff"], .fair, stage: .moveOut,
                                                                     photo: "snap-hero", count: 1, seed: 90)])
        XCTAssertEqual(MoveOutComparison.make(room: noBaseline).state, .noBaseline)

        // A move-out entry without photos is still missing proof.
        let noPhotos = Self.room(10, "Closet",
                                 moveIn: [Self.entry("Closet", .good, stage: .moveIn, photo: "snap-hero", count: 1, seed: 91)],
                                 moveOut: [Self.entry("Closet", tags: ["Dent"], .poor, stage: .moveOut, photo: nil, count: 0, seed: 92)])
        XCTAssertEqual(MoveOutComparison.make(room: noPhotos).state, .missing)

        // Better condition at move-out and tag case differences are not a change.
        let better = Self.room(11, "Den",
                               moveIn: [Self.entry("Den", tags: ["Scratch "], .fair, stage: .moveIn, photo: "snap-hero", count: 1, seed: 93)],
                               moveOut: [Self.entry("Den", tags: ["scratch"], .good, stage: .moveOut, photo: "snap-hero", count: 1, seed: 94)])
        XCTAssertEqual(MoveOutComparison.make(room: better).state, .unchanged)
    }
}
